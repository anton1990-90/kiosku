/// Jenis catatan hutang.
///   piutang — pelanggan berhutang ke toko (uang masuk nanti)
///   hutang  — toko berhutang ke supplier (uang keluar nanti)
class DebtType {
  static const piutang = 'piutang';
  static const hutang = 'hutang';
}

/// Status pelunasan.
class DebtStatus {
  static const belumLunas = 'belum_lunas';
  static const lunas = 'lunas';
}

/// Catatan hutang / piutang.
///
/// Terhubung ke transaksi penjualan ([saleId]) dan/atau produk ([productId])
/// supaya pemilik toko bisa melihat hutang ini berasal dari barang apa.
class DebtModel {
  final int? id;
  final String partyName; // nama pelanggan atau supplier
  final String? partyPhone;
  final String type; // DebtType.piutang / DebtType.hutang
  final int amount; // nilai hutang awal
  final int paidAmount; // sudah dibayar
  final String? note;
  final DateTime? dueDate; // jatuh tempo (opsional)
  final String status; // DebtStatus
  final int? supplierId; // terisi kalau terkait supplier
  final int? saleId; // terisi kalau berasal dari transaksi penjualan
  final int? productId; // terisi kalau hutang ini untuk satu produk
  final DateTime createdAt;
  final DateTime updatedAt;

  DebtModel({
    this.id,
    required this.partyName,
    this.partyPhone,
    this.type = DebtType.piutang,
    required this.amount,
    this.paidAmount = 0,
    this.note,
    this.dueDate,
    this.status = DebtStatus.belumLunas,
    this.supplierId,
    this.saleId,
    this.productId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Sisa yang belum dibayar.
  int get remaining {
    final sisa = amount - paidAmount;
    return sisa < 0 ? 0 : sisa;
  }

  bool get isLunas => status == DebtStatus.lunas || remaining == 0;

  bool get isPiutang => type == DebtType.piutang;

  /// Lewat jatuh tempo dan belum lunas.
  bool get isOverdue {
    if (isLunas || dueDate == null) return false;
    final today = DateTime.now();
    final d = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final t = DateTime(today.year, today.month, today.day);
    return d.isBefore(t);
  }

  /// Persentase yang sudah dibayar (0..1).
  double get paidRatio {
    if (amount <= 0) return 0;
    final ratio = paidAmount / amount;
    return ratio > 1 ? 1 : ratio;
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'party_name': partyName,
      'party_phone': partyPhone,
      'type': type,
      'amount': amount,
      'paid_amount': paidAmount,
      'note': note,
      'due_date': dueDate?.toIso8601String(),
      'status': status,
      'supplier_id': supplierId,
      'sale_id': saleId,
      'product_id': productId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    final dueRaw = map['due_date'] as String?;
    return DebtModel(
      id: map['id'] as int?,
      partyName: map['party_name'] as String,
      partyPhone: map['party_phone'] as String?,
      type: (map['type'] as String?) ?? DebtType.piutang,
      amount: map['amount'] as int,
      paidAmount: (map['paid_amount'] as int?) ?? 0,
      note: map['note'] as String?,
      dueDate: dueRaw == null ? null : DateTime.tryParse(dueRaw),
      status: (map['status'] as String?) ?? DebtStatus.belumLunas,
      supplierId: map['supplier_id'] as int?,
      saleId: map['sale_id'] as int?,
      productId: map['product_id'] as int?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  DebtModel copyWith({
    int? id,
    String? partyName,
    String? partyPhone,
    String? type,
    int? amount,
    int? paidAmount,
    String? note,
    DateTime? dueDate,
    String? status,
    int? supplierId,
    int? saleId,
    int? productId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      partyName: partyName ?? this.partyName,
      partyPhone: partyPhone ?? this.partyPhone,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      note: note ?? this.note,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      supplierId: supplierId ?? this.supplierId,
      saleId: saleId ?? this.saleId,
      productId: productId ?? this.productId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Riwayat pembayaran cicilan hutang.
class DebtPaymentModel {
  final int? id;
  final int debtId;
  final int amount;
  final String? note;
  final DateTime createdAt;

  DebtPaymentModel({
    this.id,
    required this.debtId,
    required this.amount,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'debt_id': debtId,
      'amount': amount,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DebtPaymentModel.fromMap(Map<String, dynamic> map) {
    return DebtPaymentModel(
      id: map['id'] as int?,
      debtId: map['debt_id'] as int,
      amount: map['amount'] as int,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
