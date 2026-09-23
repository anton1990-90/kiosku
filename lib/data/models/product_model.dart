/// Product model for grocery store items.
/// Includes cost price (modal) and sell price for profit calculation.
class ProductModel {
  final int? id;
  final String name;
  final String category;
  final int costPrice;   // Harga modal (beli)
  final int sellPrice;  // Harga jual
  final int stock;
  final int minStock;    // Threshold for low-stock alert
  final String? supplier;
  final String? emoji;   // Visual placeholder for product image
  final String? barcode; // EAN-13 / UPC barcode for scanning
  /// Satuan jual: pcs, kg, liter, ikat, dan sebagainya. Dipakai supaya struk
  /// dan laporan menulis "2 kg", bukan sekadar "2".
  final String unit;
  /// Path foto barang yang dipilih dari galeri HP. Kalau null, tampilan
  /// kembali memakai [emoji] — jadi produk lama tidak perlu disunting.
  final String? photoPath;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProductModel({
    this.id,
    required this.name,
    required this.category,
    required this.costPrice,
    required this.sellPrice,
    required this.stock,
    this.minStock = 5,
    this.supplier,
    this.emoji,
    this.barcode,
    this.unit = 'pcs',
    this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Profit margin per unit
  int get profitPerUnit => sellPrice - costPrice;

  /// Stock status: 'ok', 'low', 'out'
  String get stockStatus {
    if (stock == 0) return 'out';
    if (stock <= minStock) return 'low';
    return 'ok';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'category': category,
      'cost_price': costPrice,
      'sell_price': sellPrice,
      'stock': stock,
      'min_stock': minStock,
      'supplier': supplier,
      'emoji': emoji,
      'barcode': barcode,
      'unit': unit,
      'photo_path': photoPath,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    return ProductModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      category: map['category'] as String,
      costPrice: map['cost_price'] as int,
      sellPrice: map['sell_price'] as int,
      stock: map['stock'] as int,
      minStock: (map['min_stock'] as int?) ?? 5,
      supplier: map['supplier'] as String?,
      emoji: (map['emoji'] as String?) ?? '📦',
      barcode: map['barcode'] as String?,
      unit: (map['unit'] as String?) ?? 'pcs',
      photoPath: map['photo_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  ProductModel copyWith({
    int? id,
    String? name,
    String? category,
    int? costPrice,
    int? sellPrice,
    int? stock,
    int? minStock,
    String? supplier,
    String? emoji,
    String? barcode,
    String? unit,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      costPrice: costPrice ?? this.costPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      stock: stock ?? this.stock,
      minStock: minStock ?? this.minStock,
      supplier: supplier ?? this.supplier,
      emoji: emoji ?? this.emoji,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
