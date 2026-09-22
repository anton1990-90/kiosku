/// Arah mutasi kas.
class CashType {
  static const masuk = 'in';
  static const keluar = 'out';

  static String label(String type) => type == masuk ? 'Uang masuk' : 'Uang keluar';
}

/// Kategori mutasi kas — dipakai untuk mengelompokkan riwayat dan
/// menyusun laporan arus kas.
class CashCategory {
  static const penjualan = 'penjualan';
  static const modal = 'modal';
  static const prive = 'prive';
  static const beban = 'beban';
  static const restok = 'restok';
  static const terimaPiutang = 'terima_piutang';
  static const bayarHutang = 'bayar_hutang';
  static const lainnya = 'lainnya';

  static const semua = [
    penjualan,
    modal,
    prive,
    beban,
    restok,
    terimaPiutang,
    bayarHutang,
    lainnya,
  ];

  /// Label Indonesia untuk ditampilkan.
  static String label(String category) {
    switch (category) {
      case penjualan:
        return 'Penjualan';
      case modal:
        return 'Modal pemilik';
      case prive:
        return 'Prive';
      case beban:
        return 'Beban usaha';
      case restok:
        return 'Belanja stok';
      case terimaPiutang:
        return 'Terima piutang';
      case bayarHutang:
        return 'Bayar hutang';
      default:
        return 'Lain-lain';
    }
  }
}

/// Satu mutasi kas.
class CashTransaction {
  final int? id;
  final String type; // CashType.masuk / CashType.keluar
  final int amount;
  final String category; // CashCategory.*
  final String? note;
  final String? refType; // sale | debt | debt_payment | restock | expense | manual
  final int? refId;
  final DateTime date;
  final DateTime createdAt;

  CashTransaction({
    this.id,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    this.refType,
    this.refId,
    required this.date,
    required this.createdAt,
  });

  bool get isMasuk => type == CashType.masuk;

  /// Nilai bertanda: positif untuk uang masuk, negatif untuk uang keluar.
  int get signedAmount => isMasuk ? amount : -amount;

  String get categoryLabel => CashCategory.label(category);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'type': type,
      'amount': amount,
      'category': category,
      'note': note,
      'ref_type': refType,
      'ref_id': refId,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory CashTransaction.fromMap(Map<String, dynamic> map) {
    return CashTransaction(
      id: map['id'] as int?,
      type: (map['type'] as String?) ?? CashType.masuk,
      amount: (map['amount'] as int?) ?? 0,
      category: (map['category'] as String?) ?? CashCategory.lainnya,
      note: map['note'] as String?,
      refType: map['ref_type'] as String?,
      refId: map['ref_id'] as int?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Ringkasan kas untuk satu rentang waktu.
class CashSummary {
  final int masuk;
  final int keluar;

  const CashSummary({this.masuk = 0, this.keluar = 0});

  int get selisih => masuk - keluar;
}

/// Beban operasional — dipakai di laporan laba rugi.
class ExpenseModel {
  final int? id;
  final String category;
  final int amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  ExpenseModel({
    this.id,
    required this.category,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'category': category,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map) {
    return ExpenseModel(
      id: map['id'] as int?,
      category: (map['category'] as String?) ?? 'Lain-lain',
      amount: (map['amount'] as int?) ?? 0,
      note: map['note'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Prive — pengambilan uang toko oleh pemilik.
///
/// Prive bukan beban usaha, jadi tidak mengurangi laba. Prive mengurangi
/// ekuitas pemilik dan dicatat di laporan perubahan ekuitas.
class PriveModel {
  final int? id;
  final int amount;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  PriveModel({
    this.id,
    required this.amount,
    this.note,
    required this.date,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'amount': amount,
      'note': note,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PriveModel.fromMap(Map<String, dynamic> map) {
    return PriveModel(
      id: map['id'] as int?,
      amount: (map['amount'] as int?) ?? 0,
      note: map['note'] as String?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Riwayat pergerakan stok satu produk.
class StockMovement {
  final int? id;
  final int productId;
  final String productName;
  final String type; // in | out | adjust
  final int quantity;
  final int totalCost;
  final String? note;
  final String? refType;
  final int? refId;
  final DateTime date;
  final DateTime createdAt;

  StockMovement({
    this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.totalCost = 0,
    this.note,
    this.refType,
    this.refId,
    required this.date,
    required this.createdAt,
  });

  bool get isMasuk => type == 'in';

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'product_id': productId,
      'product_name': productName,
      'type': type,
      'quantity': quantity,
      'total_cost': totalCost,
      'note': note,
      'ref_type': refType,
      'ref_id': refId,
      'date': date.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    return StockMovement(
      id: map['id'] as int?,
      productId: (map['product_id'] as int?) ?? 0,
      productName: (map['product_name'] as String?) ?? '-',
      type: (map['type'] as String?) ?? 'in',
      quantity: (map['quantity'] as int?) ?? 0,
      totalCost: (map['total_cost'] as int?) ?? 0,
      note: map['note'] as String?,
      refType: map['ref_type'] as String?,
      refId: map['ref_id'] as int?,
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
