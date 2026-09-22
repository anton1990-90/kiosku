/// Ringkasan angka untuk satu periode laporan.
class ReportSummary {
  final int totalSales;
  final int totalProfit;
  final int transactions;
  final int itemsSold;

  const ReportSummary({
    this.totalSales = 0,
    this.totalProfit = 0,
    this.transactions = 0,
    this.itemsSold = 0,
  });

  /// Rata-rata nilai per transaksi.
  int get averagePerTransaction =>
      transactions == 0 ? 0 : (totalSales / transactions).round();

  bool get isEmpty => transactions == 0;
}

/// Satu baris detail produk yang terjual — dipakai di laporan harian.
/// Berisi tanggal & waktu transaksi supaya pemilik toko bisa melacak
/// kapan barang tertentu keluar.
class ReportItemDetail {
  final String productName;
  final int quantity;
  final int costPrice;
  final int sellPrice;
  final int subtotal;
  final DateTime soldAt;
  final String invoiceNumber;
  final String? customerName;
  final String paymentMethod;

  const ReportItemDetail({
    required this.productName,
    required this.quantity,
    required this.costPrice,
    required this.sellPrice,
    required this.subtotal,
    required this.soldAt,
    required this.invoiceNumber,
    this.customerName,
    required this.paymentMethod,
  });

  int get profit => (sellPrice - costPrice) * quantity;

  factory ReportItemDetail.fromMap(Map<String, dynamic> map) {
    return ReportItemDetail(
      productName: map['product_name'] as String,
      quantity: map['quantity'] as int,
      costPrice: map['cost_price'] as int,
      sellPrice: map['sell_price'] as int,
      subtotal: map['subtotal'] as int,
      soldAt: DateTime.parse(map['created_at'] as String),
      invoiceNumber: map['invoice_number'] as String,
      customerName: map['customer_name'] as String?,
      paymentMethod: (map['payment_method'] as String?) ?? 'tunai',
    );
  }
}

/// Produk terlaris dalam satu periode.
class TopProduct {
  final String productName;
  final int quantity;
  final int revenue;
  final int profit;

  const TopProduct({
    required this.productName,
    required this.quantity,
    required this.revenue,
    required this.profit,
  });
}
