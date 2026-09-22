/// Metode pembayaran yang bisa diatur pengguna.
/// `code` disimpan apa adanya ke kolom `sales.payment_method`.
class PaymentMethodModel {
  final int? id;
  final String code;
  final String name;
  final bool isActive;
  final int sortOrder;

  PaymentMethodModel({
    this.id,
    required this.code,
    required this.name,
    this.isActive = true,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'code': code,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
    };
  }

  factory PaymentMethodModel.fromMap(Map<String, dynamic> map) {
    return PaymentMethodModel(
      id: map['id'] as int?,
      code: map['code'] as String,
      name: map['name'] as String,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }

  PaymentMethodModel copyWith({
    int? id,
    String? code,
    String? name,
    bool? isActive,
    int? sortOrder,
  }) {
    return PaymentMethodModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
