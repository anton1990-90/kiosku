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
/// kapan barang tertentu keluar, plus status pembayarannya supaya jelas
/// transaksi itu dibayar tunai atau jadi piutang.
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

  /// Transaksi ini dicatat sebagai piutang, artinya tidak dibayar penuh
  /// saat transaksi dibuat.
  final bool isDebt;

  /// Sisa piutang yang **masih** belum dibayar sampai sekarang. Diambil dari
  /// catatan hutang, jadi ikut berubah begitu pelanggan mencicil.
  final int unpaidAmount;

  /// Nilai transaksi dan jumlah yang dibayar saat transaksi dibuat.
  final int totalAmount;
  final int paidAmount;

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
    this.isDebt = false,
    this.unpaidAmount = 0,
    this.totalAmount = 0,
    this.paidAmount = 0,
  });

  int get profit => (sellPrice - costPrice) * quantity;

  /// Status pembayaran transaksi, siap ditampilkan ke pengguna.
  ///   Cash          — dibayar penuh saat transaksi
  ///   Piutang       — masih ada sisa yang belum dibayar
  ///   Piutang lunas — dulu piutang, sekarang sudah dibayar lunas
  String get paymentStatusLabel {
    if (!isDebt) return 'Cash';
    return unpaidAmount > 0 ? 'Piutang' : 'Piutang lunas';
  }

  /// Versi pendek untuk kolom tabel PDF yang sempit.
  String get paymentStatusShort {
    if (!isDebt) return 'Cash';
    return unpaidAmount > 0 ? 'Piutang' : 'Lunas';
  }

  /// Masih ada uang yang belum diterima dari transaksi ini.
  bool get isPiutang => isDebt && unpaidAmount > 0;

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
      isDebt: ((map['is_debt'] as int?) ?? 0) == 1,
      unpaidAmount: (map['sisa'] as int?) ?? 0,
      totalAmount: (map['total_amount'] as int?) ?? 0,
      paidAmount: (map['paid_amount'] as int?) ?? 0,
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
