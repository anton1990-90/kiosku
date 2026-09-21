import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

/// Sale repository — handles transaction creation and history queries.
/// All offline: transactions are stored locally in SQLite.
class SaleRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Create a new sale transaction with all line items.
  /// Also reduces product stock for each item.
  Future<SaleModel> createSale({
    required int userId,
    required List<SaleItemModel> items,
    String? customerName,
    required String paymentMethod,
    required int paidAmount,
  }) async {
    final db = await _db.database;

    final totalAmount = items.fold(0, (sum, i) => sum + i.subtotal);
    final totalProfit = items.fold(0, (sum, i) => sum + i.profit);
    final totalItems = items.fold(0, (sum, i) => sum + i.quantity);
    final changeAmount = paidAmount - totalAmount;

    final invoiceNumber = _generateInvoiceNumber();

    final sale = SaleModel(
      invoiceNumber: invoiceNumber,
      userId: userId,
      customerName: customerName,
      totalAmount: totalAmount,
      totalProfit: totalProfit,
      totalItems: totalItems,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      changeAmount: changeAmount,
      createdAt: DateTime.now(),
    );

    // Transaction: insert sale, insert items, reduce stock
    await db.transaction((txn) async {
      final saleId = await txn.insert('sales', sale.toMap());

      for (final item in items) {
        await txn.insert('sale_items', {
          ...item.toMap(),
          'sale_id': saleId,
        });
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?',
          [item.quantity, DateTime.now().toIso8601String(), item.productId],
        );
      }
    });

    return sale;
  }

  /// Generate invoice number: TK-YYYYMMDD-HHMMSS
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TK-$datePart-$timePart';
  }

  /// Get sales for a specific date range.
  Future<List<SaleModel>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await _db.database;
    String where = '';
    List<dynamic> args = [];

    if (startDate != null) {
      where = "created_at >= ?";
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final endFilter =
          endDate.add(const Duration(days: 1));
      where = where.isEmpty
          ? "created_at < ?"
          : "$where AND created_at < ?";
      args.add(endFilter.toIso8601String());
    }

    final results = await db.query(
      'sales',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((m) => SaleModel.fromMap(m)).toList();
  }

  /// Get sale items for a specific sale.
  Future<List<SaleItemModel>> getSaleItems(int saleId) async {
    final db = await _db.database;
    final results = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return results.map((m) => SaleItemModel.fromMap(m)).toList();
  }

  /// Get today's total sales amount.
  Future<int> getTodaySalesTotal() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales WHERE created_at >= ? AND created_at < ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get today's transaction count.
  Future<int> getTodayTransactionCount() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sales WHERE created_at >= ? AND created_at < ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get weekly sales data (last 7 days) for chart.
  Future<List<({String day, int total})>> getWeeklySales() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final results = <({String day, int total})>[];
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    for (var i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales WHERE created_at >= ? AND created_at < ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
      results.add((
        day: dayNames[i],
        total: Sqflite.firstIntValue(result) ?? 0,
      ));
    }
    return results;
  }
}
