/// Sale item model — a line item in a sale transaction.
class SaleItemModel {
  final int? id;
  final int saleId;
  final int productId;
  final String productName;
  final int costPrice;   // Captured at time of sale
  final int sellPrice;   // Captured at time of sale
  final int quantity;
  final int subtotal;

  SaleItemModel({
    this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.costPrice,
    required this.sellPrice,
    required this.quantity,
    required this.subtotal,
  });

  int get profit => (sellPrice - costPrice) * quantity;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sale_id': saleId,
      'product_id': productId,
      'product_name': productName,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'quantity': quantity,
      'subtotal': subtotal,
    };
  }

  factory SaleItemModel.fromMap(Map<String, dynamic> map) {
    return SaleItemModel(
      id: map['id'] as int?,
      saleId: map['sale_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      costPrice: map['cost_price'] as int,
      sellPrice: map['sell_price'] as int,
      quantity: map['quantity'] as int,
      subtotal: map['subtotal'] as int,
    );
  }
}
