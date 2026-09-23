/// Status transaksi penjualan.
///
/// Transaksi yang dibatalkan tidak dihapus, hanya berubah statusnya. Seluruh
/// laporan menyaringnya lewat view `sales_aktif` (lihat `DatabaseHelper`), jadi
/// nilai ini hanya perlu diperiksa di tempat yang memang harus membedakan —
/// mis. sebelum mencetak ulang struk.
class SaleStatus {
  static const selesai = 'selesai';
  static const batal = 'batal';

  static const semua = [selesai, batal];
}

/// Sale (transaction) model — a complete POS transaction.
class SaleModel {
  final int? id;
  final String invoiceNumber;
  final int userId;
  final String? customerName;
  final int totalAmount;
  final int totalProfit;
  final int totalItems;
  final String paymentMethod; // 'tunai', 'qris', 'ewallet'
  final int paidAmount;
  final int changeAmount;
  final bool isDebt; // true kalau sebagian/seluruhnya belum dibayar
  final int? debtId; // id catatan piutang yang dibuat dari transaksi ini
  /// Potongan untuk seluruh nota, di luar potongan per baris. Dalam rupiah.
  final int discount;
  /// 'selesai' atau 'batal'.
  final String status;
  final DateTime createdAt;

  SaleModel({
    this.id,
    required this.invoiceNumber,
    required this.userId,
    this.customerName,
    required this.totalAmount,
    required this.totalProfit,
    required this.totalItems,
    required this.paymentMethod,
    required this.paidAmount,
    required this.changeAmount,
    this.isDebt = false,
    this.debtId,
    this.discount = 0,
    this.status = SaleStatus.selesai,
    required this.createdAt,
  });

  /// Transaksi ini sudah dibatalkan.
  bool get dibatalkan => status == SaleStatus.batal;

  /// Harga barang sebelum potongan nota dikurangi.
  ///
  /// Dipakai struk untuk menampilkan baris "Potongan" hanya kalau memang ada,
  /// dan untuk menghitung ulang harga barang di nota lama yang potongannya
  /// belum tersimpan.
  int get grossAmount => totalAmount + discount;

  /// Sisa yang belum dibayar pelanggan.
  int get unpaidAmount {
    final sisa = totalAmount - paidAmount;
    return sisa < 0 ? 0 : sisa;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_number': invoiceNumber,
      'user_id': userId,
      'customer_name': customerName,
      'total_amount': totalAmount,
      'total_profit': totalProfit,
      'total_items': totalItems,
      'payment_method': paymentMethod,
      'paid_amount': paidAmount,
      'change_amount': changeAmount,
      'is_debt': isDebt ? 1 : 0,
      'debt_id': debtId,
      'discount': discount,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'] as int?,
      invoiceNumber: map['invoice_number'] as String,
      userId: map['user_id'] as int,
      customerName: map['customer_name'] as String?,
      totalAmount: map['total_amount'] as int,
      totalProfit: map['total_profit'] as int,
      totalItems: map['total_items'] as int,
      paymentMethod: map['payment_method'] as String,
      paidAmount: map['paid_amount'] as int,
      changeAmount: map['change_amount'] as int,
      isDebt: ((map['is_debt'] as int?) ?? 0) == 1,
      debtId: map['debt_id'] as int?,
      // Nota yang tercatat sebelum versi 6 belum punya kolom ini.
      discount: (map['discount'] as int?) ?? 0,
      // Nota sebelum versi 7 belum punya kolom status — semuanya 'selesai'.
      status: (map['status'] as String?) ?? SaleStatus.selesai,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
