import 'package:esc_pos_utils/esc_pos_utils.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';

/// Receipt service — generates ESC/POS thermal receipt bytes.
/// Supports 58mm and 80mm printers.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  /// Generate the receipt bytes for a thermal printer.
  Future<List<int>> generateReceipt({
    required SaleModel sale,
    required List<SaleItemModel> items,
    required String storeName,
    String? storeAddress,
    int paperWidth = 58,
  }) async {
    final profile = await CapabilityProfile.load();
    final paper = paperWidth == 80 ? PaperSize.mm80 : PaperSize.mm58;
    final generator = Generator(paper, profile);
    List<int> bytes = [];

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

    bytes += generator.text(
      '--------------------------------',
      styles: const PosStyles(align: PosAlign.center),
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

  /// Plain-text receipt for sharing/saving (fallback when no printer).
  String generateTextReceipt({
    required SaleModel sale,
    required List<SaleItemModel> items,
    required String storeName,
    String? storeAddress,
  }) {
    final buffer = StringBuffer();
    final line = '--------------------------------\n';

    buffer.writeln(storeName);
    if (storeAddress != null && storeAddress.isNotEmpty) {
      buffer.writeln(storeAddress);
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
    buffer.write(line);
    buffer.writeln('Terima kasih atas kunjungan Anda!');
    buffer.writeln('Powered by TokoKu');

    return buffer.toString();
  }
}
