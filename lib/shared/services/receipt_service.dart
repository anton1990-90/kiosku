import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/formatters.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';

/// Receipt service — generates ESC/POS thermal receipt bytes.
/// Supports 58mm and 80mm printers.
///
/// Logo usaha, gambar QRIS, dan data rekening ikut dicetak kalau sudah diisi
/// di menu Profil › Info toko. Gambar dicetak sebagai bit-image raster
/// (`GS v 0`) karena `esc_pos_utils` tidak mengecilkan gambar sendiri — lebar
/// dan tingginya diatur dulu di sini supaya muat di kertas.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  /// Lebar kertas dalam titik (dot): 58mm = 384, 80mm = 576.
  static int _lebarKertas(int paperWidth) => paperWidth == 80 ? 576 : 384;

  /// Generate the receipt bytes for a thermal printer.
  Future<List<int>> generateReceipt({
    required SaleModel sale,
    required List<SaleItemModel> items,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
    String? qrisPath,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    int paperWidth = 58,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final lebar = _lebarKertas(paperWidth);
    final generator = Generator(paper, profile);
    List<int> bytes = [];

    // Logo usaha — paling atas, di tengah.
    bytes += await _gambar(generator, logoPath, lebar, 240);

    // Header — store name
    bytes += generator.text(
      storeName,
      styles: const PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    if (storeAddress != null && storeAddress.isNotEmpty) {
      bytes += generator.text(
        storeAddress,
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      bytes += generator.text(
        'Telp: $storePhone',
        styles: const PosStyles(align: PosAlign.center),
      );
    }
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'STRUK PENJUALAN',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Transaction meta
    bytes += generator.row([
      PosColumn(text: 'No: ${sale.invoiceNumber}', width: 8),
      PosColumn(
        text: Formatters.dateTime(sale.createdAt),
        width: 4,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      bytes += generator.text('Pelanggan: ${sale.customerName}');
    }
    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Items
    for (final item in items) {
      bytes += generator.text(item.productName);
      bytes += generator.row([
        PosColumn(
          text: '${item.quantity} x ${Formatters.rupiah(item.sellPrice)}',
          width: 7,
        ),
        PosColumn(
          text: Formatters.rupiah(item.subtotal),
          width: 5,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Totals
    bytes += generator.row([
      PosColumn(
        text: 'TOTAL',
        width: 6,
        styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
      ),
      PosColumn(
        text: Formatters.rupiah(sale.totalAmount),
        width: 6,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      ),
    ]);
    bytes += generator.text('Tunai: ${Formatters.rupiah(sale.paidAmount)}');
    bytes += generator.text('Kembali: ${Formatters.rupiah(sale.changeAmount)}');
    bytes += generator.text('Bayar: ${sale.paymentMethod.toUpperCase()}');
    bytes += generator.text('Item: ${sale.totalItems}');

    // Sisa piutang — supaya pelanggan tahu masih ada tanggungan.
    if (sale.isDebt && sale.unpaidAmount > 0) {
      bytes += generator.text(
        'BELUM DIBAYAR: ${Formatters.rupiah(sale.unpaidAmount)}',
        styles: const PosStyles(bold: true),
      );
    }

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
    );

    // Cara bayar non-tunai — gambar QRIS atau data rekening toko.
    bytes += await _infoPembayaran(
      generator,
      sale: sale,
      qrisPath: qrisPath,
      bankName: bankName,
      bankAccountNumber: bankAccountNumber,
      bankAccountName: bankAccountName,
      lebarKertas: lebar,
    );

    // Footer
    bytes += generator.text(
      'Terima kasih atas kunjungan Anda!',
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Powered by TokoKu',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  /// Bagian "cara bayar" untuk QRIS / transfer bank.
  ///
  /// Hanya dicetak kalau metodenya memang non-tunai dan datanya sudah diisi,
  /// supaya struk tunai biasa tidak jadi panjang tanpa alasan.
  static Future<List<int>> _infoPembayaran(
    Generator generator, {
    required SaleModel sale,
    required String? qrisPath,
    required String? bankName,
    required String? bankAccountNumber,
    required String? bankAccountName,
    required int lebarKertas,
  }) async {
    final metode = sale.paymentMethod.toLowerCase();
    List<int> bytes = [];

    if (metode == 'qris' && qrisPath != null && qrisPath.isNotEmpty) {
      bytes += generator.text(
        'PEMBAYARAN QRIS',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      );
      // Tinggi dibatasi supaya tidak menghabiskan kertas kalau gambarnya
      // berupa poster yang tinggi.
      bytes += await _gambar(generator, qrisPath, lebarKertas, 300);
      bytes += generator.text(
        'Scan QRIS di atas untuk membayar',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    final nomorRek = (bankAccountNumber ?? '').trim();
    if (metode == 'transfer' && nomorRek.isNotEmpty) {
      bytes += generator.text(
        'TRANSFER BANK',
        styles: const PosStyles(bold: true, align: PosAlign.center),
      );
      if ((bankName ?? '').trim().isNotEmpty) {
        bytes += generator.text('Bank    : ${bankName!.trim()}');
      }
      bytes += generator.text('No. rek : $nomorRek');
      if ((bankAccountName ?? '').trim().isNotEmpty) {
        bytes += generator.text('a.n.    : ${bankAccountName!.trim()}');
      }
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    return bytes;
  }

  /// Cetak satu berkas gambar sebagai bit-image raster.
  ///
  /// Mengembalikan daftar kosong kalau path kosong, berkasnya hilang, atau
  /// gambarnya gagal dibaca — struk tetap tercetak tanpa gambar.
  static Future<List<int>> _gambar(
    Generator generator,
    String? path,
    int maxWidth,
    int maxHeight,
  ) async {
    if (path == null || path.isEmpty) return const [];

    try {
      final file = File(path);
      if (!await file.exists()) return const [];

      final bytes = await file.readAsBytes();
      final gambar = _siapkanGambar(bytes, maxWidth, maxHeight);
      if (gambar == null) return const [];

      return generator.imageRaster(gambar);
    } catch (_) {
      return const [];
    }
  }

  /// Baca gambar lalu kecilkan agar muat di kertas, tanpa mengubah
  /// perbandingan sisi.
  static img.Image? _siapkanGambar(
    Uint8List data,
    int maxWidth,
    int maxHeight,
  ) {
    final asli = img.decodeImage(data);
    if (asli == null) return null;
    if (asli.width <= 0 || asli.height <= 0) return null;

    var lebar = asli.width;
    var tinggi = asli.height;

    if (lebar > maxWidth) {
      tinggi = (tinggi * maxWidth / lebar).round();
      lebar = maxWidth;
    }
    if (tinggi > maxHeight) {
      lebar = (lebar * maxHeight / tinggi).round();
      tinggi = maxHeight;
    }
    if (lebar < 1) lebar = 1;
    if (tinggi < 1) tinggi = 1;

    if (lebar == asli.width && tinggi == asli.height) return asli;
    return img.copyResize(asli, width: lebar, height: tinggi);
  }

  /// Plain-text receipt for sharing/saving (fallback when no printer).
  String generateTextReceipt({
    required SaleModel sale,
    required List<SaleItemModel> items,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) {
    final buffer = StringBuffer();
    final line = '--------------------------------\n';

    buffer.writeln(storeName);
    if (storeAddress != null && storeAddress.isNotEmpty) {
      buffer.writeln(storeAddress);
    }
    if (storePhone != null && storePhone.isNotEmpty) {
      buffer.writeln('Telp: $storePhone');
    }
    buffer.write(line);
    buffer.writeln('STRUK PENJUALAN');
    buffer.write(line);
    buffer.writeln('No: ${sale.invoiceNumber}');
    buffer.writeln('Tanggal: ${Formatters.dateTime(sale.createdAt)}');
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      buffer.writeln('Pelanggan: ${sale.customerName}');
    }
    buffer.write(line);
    for (final item in items) {
      buffer.writeln(item.productName);
      buffer.writeln(
          '  ${item.quantity} x ${Formatters.rupiah(item.sellPrice)} = ${Formatters.rupiah(item.subtotal)}');
    }
    buffer.write(line);
    buffer.writeln('TOTAL      : ${Formatters.rupiah(sale.totalAmount)}');
    buffer.writeln('Tunai      : ${Formatters.rupiah(sale.paidAmount)}');
    buffer.writeln('Kembali    : ${Formatters.rupiah(sale.changeAmount)}');
    buffer.writeln('Bayar      : ${sale.paymentMethod.toUpperCase()}');
    if (sale.isDebt && sale.unpaidAmount > 0) {
      buffer.writeln('BELUM DIBAYAR: ${Formatters.rupiah(sale.unpaidAmount)}');
    }

    final metode = sale.paymentMethod.toLowerCase();
    final nomorRek = (bankAccountNumber ?? '').trim();
    if (metode == 'qris') {
      buffer.write(line);
      buffer.writeln('PEMBAYARAN QRIS');
      buffer.writeln('Scan gambar QRIS di layar kasir.');
    } else if (metode == 'transfer' && nomorRek.isNotEmpty) {
      buffer.write(line);
      buffer.writeln('TRANSFER BANK');
      if ((bankName ?? '').trim().isNotEmpty) {
        buffer.writeln('Bank    : ${bankName!.trim()}');
      }
      buffer.writeln('No. rek : $nomorRek');
      if ((bankAccountName ?? '').trim().isNotEmpty) {
        buffer.writeln('a.n.    : ${bankAccountName!.trim()}');
      }
    }

    buffer.write(line);
    buffer.writeln('Terima kasih atas kunjungan Anda!');
    buffer.writeln('Powered by TokoKu');

    return buffer.toString();
  }
}
