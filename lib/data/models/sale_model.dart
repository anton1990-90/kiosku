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
    required this.createdAt,
  });

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
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
