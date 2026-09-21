import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/product_model.dart';

/// Product repository — CRUD operations for products, all offline.
class ProductRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<ProductModel>> getAll({String? category, String? search}) async {
    final db = await _db.database;
    String where = '';
    List<dynamic> args = [];

    if (category != null && category != 'Semua') {
      where = 'category = ?';
      args.add(category);
    }
    if (search != null && search.isNotEmpty) {
      where = where.isEmpty ? 'name LIKE ?' : '$where AND name LIKE ?';
      args.add('%$search%');
    }

    final results = await db.query(
      'products',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name ASC',
    );
    return results.map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<ProductModel?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProductModel.fromMap(results.first);
  }

  /// Find a product by its barcode (EAN-13 / UPC).
  Future<ProductModel?> findByBarcode(String barcode) async {
    final db = await _db.database;
    final results = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return ProductModel.fromMap(results.first);
  }

  Future<int> insert(ProductModel product) async {
    final db = await _db.database;
    return await db.insert('products', product.toMap());
  }

  Future<int> update(ProductModel product) async {
    final db = await _db.database;
    return await db.update(
      'products',
      product.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  /// Reduce stock after a sale.
  Future<void> reduceStock(int productId, int quantity) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Add stock (restock).
  Future<void> addStock(int productId, int quantity) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Get products with stock at or below minimum.
  Future<List<ProductModel>> getLowStock() async {
    final db = await _db.database;
    final results = await db.query(
      'products',
      where: 'stock <= min_stock',
      orderBy: 'stock ASC',
    );
    return results.map((m) => ProductModel.fromMap(m)).toList();
  }

  /// Get distinct categories.
  Future<List<String>> getCategories() async {
    final db = await _db.database;
    final results = await db.rawQuery(
      'SELECT DISTINCT category FROM products ORDER BY category ASC',
    );
    return results.map((m) => m['category'] as String).toList();
  }

  /// Get stock summary counts.
  Future<({int ok, int low, int out})> getStockSummary() async {
    final db = await _db.database;
    final okResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM products WHERE stock > min_stock",
    );
    final lowResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM products WHERE stock > 0 AND stock <= min_stock",
    );
    final outResult = await db.rawQuery(
      "SELECT COUNT(*) as c FROM products WHERE stock = 0",
    );
    return (
      ok: Sqflite.firstIntValue(okResult) ?? 0,
      low: Sqflite.firstIntValue(lowResult) ?? 0,
      out: Sqflite.firstIntValue(outResult) ?? 0,
    );
  }
}
