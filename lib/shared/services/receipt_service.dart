import 'dart:io';
import 'dart:typed_data';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/formatters.dart';
import '../../data/models/print_settings_model.dart';
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

  /// Jumlah karakter huruf normal yang muat dalam satu baris.
  ///
  /// 384 dot / 12 dot per karakter = 32 karakter (58 mm), 576 / 12 = 48
  /// karakter (80 mm). Angka inilah yang dipakai **semua** perhitungan kolom
  /// di struk. Sebelumnya kolom dihitung oleh `generator.row()` yang memakai
  /// pembagian 12 bagian tanpa tahu ukuran huruf, sehingga baris TOTAL berhuruf
  /// dua kali lipat kelebihan lebar dan printer memotong ekornya —
  /// "Rp 30.000" tercetak "Rp 30.0".
  static int karakterPerBaris(int paperWidth) => paperWidth == 80 ? 48 : 32;

  /// Susun dua kolom dalam satu baris selebar [lebar] karakter.
  ///
  /// Teks kiri dipangkas kalau tidak muat, tetapi teks kanan **tidak pernah**
  /// dipotong: nominal uang yang terpotong lebih berbahaya daripada nama barang
  /// yang terpotong. Pemanggil yang butuh jaminan penuh memakai
  /// [barisDuaKolom], yang memindahkan nominal ke barisnya sendiri kalau
  /// keduanya tidak muat.
  static String duaKolom(String kiri, String kanan, int lebar) {
    if (kanan.isEmpty) return kiri;
    final ruang = lebar - kanan.length;
    if (ruang <= 1) return kanan;
    var teksKiri = kiri;
    if (teksKiri.length > ruang - 1) {
      teksKiri = teksKiri.substring(0, ruang - 1);
    }
    final spasi = lebar - teksKiri.length - kanan.length;
    if (spasi < 1) return '$teksKiri $kanan';
    return '$teksKiri${' ' * spasi}$kanan';
  }

  /// Satu baris dua kolom, atau dua baris kalau memang tidak muat.
  ///
  /// Dipakai untuk baris barang dan baris TOTAL: kalau "2 pcs x Rp 1.250.000"
  /// dan "Rp 2.500.000" tidak bisa duduk bersama dalam 32 karakter, nominal
  /// dipindah ke baris berikutnya rata kanan — bukan dipotong.
  static List<String> barisDuaKolom(String kiri, String kanan, int lebar) {
    if (kanan.isEmpty) return [kiri];
    if (kiri.length + kanan.length + 1 <= lebar) {
      return [duaKolom(kiri, kanan, lebar)];
    }
    return [kiri, duaKolom('', kanan, lebar)];
  }

  /// Ucapan penutup bawaan, dipakai selama pemilik toko belum mengubahnya.
  ///
  /// Disimpan sebagai konstanta supaya teks ini hidup di **satu** tempat.
  /// Sebelumnya ia tertulis dua kali — sekali untuk printer termal, sekali
  /// untuk struk teks — dan itu berarti mengubahnya harus diingat di dua
  /// tempat. Sekarang keduanya memanggil [footerStruk].
  static const String footerBawaan = 'Terima kasih atas kunjungan Anda!';

  /// Ucapan penutup yang benar-benar dicetak.
  ///
  /// `null` dan spasi saja sama-sama berarti "belum diatur", jadi keduanya
  /// jatuh ke teks bawaan. Ini juga penjaga terakhir kalau ada baris lama di
  /// database yang nilainya string kosong: struk tidak akan pernah mencetak
  /// satu baris kosong di tempat ucapan seharusnya.
  static String footerStruk(String? footer) {
    final teks = (footer ?? '').trim();
    return teks.isEmpty ? footerBawaan : teks;
  }

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
    String? receiptFooter,
    int paperWidth = 58,
    bool cetakLogo = true,
    bool cetakQris = true,
    GayaTotal gayaTotal = GayaTotal.besar,
    int barisKosong = 3,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final lebarDot = _lebarKertas(paperWidth);
    final lebar = karakterPerBaris(paperWidth);
    final garis = '-' * lebar;
    final generator = Generator(paper, profile);
    List<int> bytes = [];

    // Logo usaha — paling atas, di tengah. Bisa dimatikan lewat Pengaturan
    // Cetak kalau printernya lambat atau gambarnya sering gagal.
    if (cetakLogo) {
      bytes += await _gambar(generator, logoPath, lebarDot, 240);
    }

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
      garis,
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'STRUK PENJUALAN',
      styles: const PosStyles(bold: true, align: PosAlign.center),
    );
    bytes += generator.text(
      garis,
      styles: const PosStyles(align: PosAlign.center),
    );

    // Transaction meta.
    //
    // Nomor, tanggal, dan jam dicetak di baris terpisah. Sebelumnya ketiganya
    // dipaksa satu baris lewat `generator.row()` dengan kolom 8/12 dan 4/12:
    // kolom kanan hanya kebagian 10 karakter di kertas 58 mm, jadi
    // "02 Nov 2026, 13:59" terpotong menjadi tanggalnya saja dan jamnya hilang.
    bytes += generator.text('No: ${sale.invoiceNumber}');
    bytes += generator.text('Tanggal: ${Formatters.date(sale.createdAt)}');
    bytes += generator.text('Jam: ${Formatters.time(sale.createdAt)}');

    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      bytes += generator.text('Pelanggan: ${sale.customerName}');
    }
    bytes += generator.text(
      garis,
      styles: const PosStyles(align: PosAlign.center),
    );

    // Items
    for (final item in items) {
      bytes += generator.text(item.productName);
      // Rincian kuantitas di kiri, nominal di kanan. Kalau keduanya tidak muat
      // satu baris, nominal pindah ke baris berikutnya — tidak pernah dipotong.
      for (final baris in barisDuaKolom(
        '${Formatters.jumlah(item.quantity)} ${item.unit} x '
        '${Formatters.rupiah(item.sellPrice)}',
        Formatters.rupiah(item.subtotal),
        lebar,
      )) {
        bytes += generator.text(baris);
      }
      // Baris potongan hanya muncul kalau kasir memang memberi potongan untuk
      // barang ini — kalau tidak, struk biasa tidak bertambah panjang.
      if (item.discount > 0) {
        for (final baris in barisDuaKolom(
          '  Potongan',
          '-${Formatters.rupiah(item.discount)}',
          lebar,
        )) {
          bytes += generator.text(baris);
        }
      }
    }

    bytes += generator.text(
      garis,
      styles: const PosStyles(align: PosAlign.center),
    );

    // Potongan nota, di luar potongan per baris yang sudah dicetak di atas.
    if (sale.discount > 0) {
      for (final baris in barisDuaKolom(
        'Potongan nota',
        '-${Formatters.rupiah(sale.discount)}',
        lebar,
      )) {
        bytes += generator.text(baris);
      }
    }

    // Totals.
    //
    // Dua gaya, dipilih di Pengaturan Cetak. Gaya "angka besar" menaruh label
    // dan nominal di baris terpisah: huruf dua kali lipat hanya menyisakan 16
    // karakter per baris di kertas 58 mm, dan pasangan "TOTAL" + nominal
    // langsung kelebihan lebar. Itulah sebab "Rp 30.000" dulu terpotong.
    if (gayaTotal == GayaTotal.besar) {
      bytes += generator.text('TOTAL', styles: const PosStyles(bold: true));
      bytes += generator.text(
        Formatters.rupiah(sale.totalAmount),
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    } else {
      for (final baris in barisDuaKolom(
        'TOTAL',
        Formatters.rupiah(sale.totalAmount),
        lebar,
      )) {
        bytes += generator.text(baris, styles: const PosStyles(bold: true));
      }
    }
    bytes += generator.text('Tunai: ${Formatters.rupiah(sale.paidAmount)}');
    bytes += generator.text('Kembali: ${Formatters.rupiah(sale.changeAmount)}');
    bytes += generator.text('Bayar: ${sale.paymentMethod.toUpperCase()}');
    bytes += generator.text('Item: ${Formatters.jumlah(sale.totalItems)}');

    // Sisa piutang — supaya pelanggan tahu masih ada tanggungan.
    if (sale.isDebt && sale.unpaidAmount > 0) {
      bytes += generator.text(
        'BELUM DIBAYAR: ${Formatters.rupiah(sale.unpaidAmount)}',
        styles: const PosStyles(bold: true),
      );
    }

    bytes += generator.text(
      garis,
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
      lebarKertas: lebarDot,
      garis: garis,
      cetakQris: cetakQris,
    );

    // Footer — ucapan pemilik toko kalau sudah diatur di Info Toko, teks
    // bawaan kalau belum. Kedua jalur cetak memakai footerStruk() yang sama
    // supaya struk termal dan struk teks tidak pernah berbeda ucapan.
    bytes += generator.text(
      footerStruk(receiptFooter),
      styles: const PosStyles(align: PosAlign.center),
    );
    bytes += generator.text(
      'Powered by TokoKu',
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(barisKosong < 0 ? 0 : barisKosong);
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
    required String garis,
    required bool cetakQris,
  }) async {
    final metode = sale.paymentMethod.toLowerCase();
    List<int> bytes = [];

    if (metode == 'qris' &&
        cetakQris &&
        qrisPath != null &&
        qrisPath.isNotEmpty) {
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
        garis,
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
        garis,
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

  /// Baca gambar, kecilkan agar muat di kertas, lalu jadikan **hitam putih**.
  ///
  /// Dua hal terjadi di sini dan keduanya wajib:
  ///
  ///  1. **Latar transparan diratakan ke putih.** PNG logo hampir selalu punya
  ///     latar transparan, dan piksel transparan itu bernilai RGB 0,0,0. Tanpa
  ///     diratakan, seluruh kotak latar tercetak sebagai blok hitam pekat.
  ///  2. **Warna diubah ke abu-abu lalu diambangkan.** Printer termal hanya
  ///     punya satu warna tinta; logo berwarna yang dikirim apa adanya
  ///     menghasilkan abu-abu acak yang tercetak belang-belang. Setelah
  ///     diambangkan, setiap piksel hanya hitam atau putih — hasilnya bersih
  ///     dan tidak bergantung pada merek printer.
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

    final gambar = (lebar == asli.width && tinggi == asli.height)
        ? asli
        : img.copyResize(asli, width: lebar, height: tinggi);

    _jadikanHitamPutih(gambar);
    return gambar;
  }

  /// Ambang gelap/terang (0–255).
  ///
  /// 150, bukan 128: warna yang tidak pekat — biru muda, kuning, oranye —
  /// punya nilai kecerahan di atas 128 dan akan hilang sama sekali kalau
  /// ambangnya terlalu rendah. Akibatnya logo "hilang separuh" saat dicetak.
  static const int _ambangGelap = 150;

  /// Ratakan latar transparan ke putih, lalu ambangkan ke hitam/putih.
  ///
  /// Memakai `getPixel`/`setPixelRgba` milik paket `image` 3.x. Ketiganya
  /// bekerja pada satu angka warna terpaket (0xAABBGGRR), bukan objek piksel —
  /// `Pixel` hanya ada di `image` 4.x, dan `setPixelRgb` memang tidak ada di
  /// versi yang dipakai proyek ini.
  static void _jadikanHitamPutih(img.Image gambar) {
    // JPEG dan sebagian PNG tidak menyimpan alfa sama sekali. Membacanya tetap
    // mengembalikan angka (biasanya 0), dan kalau dipercaya begitu saja seluruh
    // gambar akan dianggap transparan lalu tercetak putih kosong.
    final adaAlfa = gambar.channels == img.Channels.rgba;

    for (var y = 0; y < gambar.height; y++) {
      for (var x = 0; x < gambar.width; x++) {
        final warna = gambar.getPixel(x, y);
        var merah = img.getRed(warna).toDouble();
        var hijau = img.getGreen(warna).toDouble();
        var biru = img.getBlue(warna).toDouble();

        if (adaAlfa) {
          final alfa = img.getAlpha(warna) / 255;
          merah = merah * alfa + 255 * (1 - alfa);
          hijau = hijau * alfa + 255 * (1 - alfa);
          biru = biru * alfa + 255 * (1 - alfa);
        }

        final terang = 0.299 * merah + 0.587 * hijau + 0.114 * biru;
        final nilai = terang >= _ambangGelap ? 255 : 0;
        gambar.setPixelRgba(x, y, nilai, nilai, nilai);
      }
    }
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
    String? receiptFooter,
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
          '  ${Formatters.jumlah(item.quantity)} ${item.unit} x '
          '${Formatters.rupiah(item.sellPrice)} = ${Formatters.rupiah(item.subtotal)}');
      if (item.discount > 0) {
        buffer.writeln('  Potongan        : -${Formatters.rupiah(item.discount)}');
      }
    }
    buffer.write(line);
    if (sale.discount > 0) {
      buffer.writeln('Potongan nota: -${Formatters.rupiah(sale.discount)}');
    }
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
    buffer.writeln(footerStruk(receiptFooter));
    buffer.writeln('Powered by TokoKu');

    return buffer.toString();
  }
}
