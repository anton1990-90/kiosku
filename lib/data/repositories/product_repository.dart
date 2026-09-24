import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/cash_model.dart';
import '../models/debt_model.dart';
import '../../core/utils/formatters.dart';
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
  Future<void> reduceStock(int productId, double quantity) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Add stock (restock).
  Future<void> addStock(int productId, double quantity) async {
    final db = await _db.database;
    await db.rawUpdate(
      'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
      [quantity, DateTime.now().toIso8601String(), productId],
    );
  }

  /// Restok lengkap: menambah stok, mencatat riwayat stok, mencatat uang
  /// keluar ke kas, dan membuat hutang ke supplier kalau belum dibayar penuh.
  ///
  /// Semua ditulis dalam satu transaksi database supaya laporan tidak pernah
  /// melihat data setengah jadi.
  Future<void> restockProduct({
    required ProductModel product,
    required double quantity,
    int? costPerUnit,
    int paidNow = 0,
    String? supplierName,
    String? note,
    DateTime? dueDate,
  }) async {
    if (quantity <= 0) return;

    final db = await _db.database;
    final now = DateTime.now();

    final hargaModal = (costPerUnit != null && costPerUnit > 0)
        ? costPerUnit
        : product.costPrice;
    final totalCost = (hargaModal * quantity).round();
    final dibayar = paidNow < 0
        ? 0
        : (paidNow > totalCost ? totalCost : paidNow);
    final sisa = totalCost - dibayar;

    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE products SET stock = stock + ?, cost_price = ?, '
        'updated_at = ? WHERE id = ?',
        [quantity, hargaModal, now.toIso8601String(), product.id],
      );

      await txn.insert('stock_movements', {
        'product_id': product.id,
        'product_name': product.name,
        'type': 'in',
        'quantity': quantity,
        'total_cost': totalCost,
        'note': note,
        'ref_type': 'restock',
        'ref_id': null,
        'date': now.toIso8601String(),
        'created_at': now.toIso8601String(),
      });

      if (dibayar > 0) {
        await txn.insert('cash_transactions', {
          'type': CashType.keluar,
          'amount': dibayar,
          'category': CashCategory.restok,
          'note': note ?? 'Belanja stok ${product.name}',
          'ref_type': 'restock',
          'ref_id': product.id,
          'date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
      }

      // Belum dibayar penuh -> jadi hutang ke supplier, terhubung ke produk.
      if (sisa > 0) {
        await txn.insert('debts', {
          'party_name': (supplierName == null || supplierName.trim().isEmpty)
              ? 'Supplier'
              : supplierName.trim(),
          'type': DebtType.hutang,
          'amount': totalCost,
          'paid_amount': dibayar,
          'note': 'Belanja ${Formatters.jumlah(quantity)}x ${product.name}',
          'due_date': dueDate?.toIso8601String(),
          'status': DebtStatus.belumLunas,
          'product_id': product.id,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
      }
    });
  }

  /// Produk dengan stok di bawah atau sama dengan batas minimum, lengkap
  /// dengan nilai persediaannya. Dipakai di beranda dan layar stok menipis.
  Future<List<({ProductModel product, int nilaiModal, int nilaiJual})>>
      getLowStockDetail() async {
    final products = await getLowStock();
    return products
        .map((p) => (
              product: p,
              nilaiModal: (p.stock * p.costPrice).round(),
              nilaiJual: (p.stock * p.sellPrice).round(),
            ))
        .toList();
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
