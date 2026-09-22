import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/accounting_models.dart';
import '../models/cash_model.dart';

/// Repositori kas, beban, prive, dan riwayat stok.
///
/// Semua data lokal (offline). Rentang waktu selalu setengah terbuka:
/// `date >= start` dan `date < end`.
class CashRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ------------------------------------------------------------------- kas

  Future<int> insert(CashTransaction trx) async {
    final db = await _db.database;
    return db.insert('cash_transactions', trx.toMap());
  }

  /// Catat mutasi kas. Dipakai juga oleh modul lain (penjualan, hutang).
  Future<int> catat({
    required String type,
    required int amount,
    required String category,
    String? note,
    String? refType,
    int? refId,
    DateTime? date,
  }) async {
    if (amount <= 0) return 0;
    final now = date ?? DateTime.now();
    return insert(
      CashTransaction(
        type: type,
        amount: amount,
        category: category,
        note: note,
        refType: refType,
        refId: refId,
        date: now,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<List<CashTransaction>> getAll({
    DateTime? start,
    DateTime? end,
    String? type,
    String? category,
    int limit = 500,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (start != null) {
      where.add('date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('date < ?');
      args.add(end.toIso8601String());
    }
    if (type != null && type.isNotEmpty && type != 'semua') {
      where.add('type = ?');
      args.add(type);
    }
    if (category != null && category.isNotEmpty && category != 'semua') {
      where.add('category = ?');
      args.add(category);
    }

    final rows = await db.query(
      'cash_transactions',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map((m) => CashTransaction.fromMap(m)).toList();
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('cash_transactions', where: 'id = ?', whereArgs: [id]);
  }

  /// Total uang masuk & keluar pada satu rentang waktu.
  Future<CashSummary> getSummary(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) AS total
      FROM cash_transactions
      WHERE date >= ? AND date < ?
      GROUP BY type
    ''', [start.toIso8601String(), end.toIso8601String()]);

    var masuk = 0;
    var keluar = 0;
    for (final r in rows) {
      final total = (r['total'] as int?) ?? 0;
      if (r['type'] == CashType.masuk) {
        masuk = total;
      } else {
        keluar = total;
      }
    }
    return CashSummary(masuk: masuk, keluar: keluar);
  }

  /// Saldo kas sampai sekarang (semua waktu).
  Future<int> getSaldo() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE WHEN type = ? THEN amount ELSE -amount END
      ), 0) AS saldo
      FROM cash_transactions
    ''', [CashType.masuk]);
    return (rows.first['saldo'] as int?) ?? 0;
  }

  /// Saldo kas sebelum [start] — titik awal laporan arus kas.
  Future<int> getSaldoSebelum(DateTime start) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(
        CASE WHEN type = ? THEN amount ELSE -amount END
      ), 0) AS saldo
      FROM cash_transactions
      WHERE date < ?
    ''', [CashType.masuk, start.toIso8601String()]);
    return (rows.first['saldo'] as int?) ?? 0;
  }

  /// Rincian arus kas per kategori pada satu rentang waktu.
  Future<List<ArusKasItem>> getArusKas(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT category,
             COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END), 0) AS masuk,
             COALESCE(SUM(CASE WHEN type = ? THEN amount ELSE 0 END), 0) AS keluar
      FROM cash_transactions
      WHERE date >= ? AND date < ?
      GROUP BY category
      ORDER BY category ASC
    ''', [
      CashType.masuk,
      CashType.keluar,
      start.toIso8601String(),
      end.toIso8601String(),
    ]);

    return rows
        .map((r) => ArusKasItem(
              category: (r['category'] as String?) ?? CashCategory.lainnya,
              masuk: (r['masuk'] as int?) ?? 0,
              keluar: (r['keluar'] as int?) ?? 0,
            ))
        .toList();
  }

  // ----------------------------------------------------------------- beban

  Future<int> insertExpense(ExpenseModel expense) async {
    final db = await _db.database;
    return db.insert('expenses', expense.toMap());
  }

  Future<List<ExpenseModel>> getExpenses(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.query(
      'expenses',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map((m) => ExpenseModel.fromMap(m)).toList();
  }

  Future<int> deleteExpense(int id) async {
    final db = await _db.database;
    return db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  /// Beban dikelompokkan per kategori — untuk laporan laba rugi.
  Future<List<BebanItem>> getBebanPerKategori(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT category, COALESCE(SUM(amount), 0) AS total
      FROM expenses
      WHERE date >= ? AND date < ?
      GROUP BY category
      ORDER BY total DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return rows
        .map((r) => BebanItem(
              category: (r['category'] as String?) ?? 'Lain-lain',
              amount: (r['total'] as int?) ?? 0,
            ))
        .toList();
  }

  // ----------------------------------------------------------------- prive

  Future<int> insertPrive(PriveModel prive) async {
    final db = await _db.database;
    return db.insert('prive', prive.toMap());
  }

  Future<List<PriveModel>> getPrive(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.query(
      'prive',
      where: 'date >= ? AND date < ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC, id DESC',
    );
    return rows.map((m) => PriveModel.fromMap(m)).toList();
  }

  Future<int> totalPrive(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM prive
      WHERE date >= ? AND date < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<int> deletePrive(int id) async {
    final db = await _db.database;
    return db.delete('prive', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------------------------------------- riwayat stok

  Future<int> insertStockMovement(StockMovement movement) async {
    final db = await _db.database;
    return db.insert('stock_movements', movement.toMap());
  }

  Future<List<StockMovement>> getStockMovements({
    int? productId,
    DateTime? start,
    DateTime? end,
    int limit = 200,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (productId != null) {
      where.add('product_id = ?');
      args.add(productId);
    }
    if (start != null) {
      where.add('date >= ?');
      args.add(start.toIso8601String());
    }
    if (end != null) {
      where.add('date < ?');
      args.add(end.toIso8601String());
    }

    final rows = await db.query(
      'stock_movements',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'date DESC, id DESC',
      limit: limit,
    );
    return rows.map((m) => StockMovement.fromMap(m)).toList();
  }

  /// Total nilai belanja stok pada satu rentang waktu.
  Future<int> totalBelanjaStok(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total_cost), 0) AS total
      FROM stock_movements
      WHERE type = 'in' AND date >= ? AND date < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Nilai persediaan sekarang = stok x harga modal tiap produk.
  Future<int> getNilaiPersediaan() async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT COALESCE(SUM(stock * cost_price), 0) AS total FROM products',
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  /// Hapus semua data contoh (produk bawaan) — tidak dipakai sekarang,
  /// disediakan untuk pembersihan manual.
  Future<int> countAll(String table) async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
