import '../database/database_helper.dart';
import '../models/supplier_model.dart';

/// Repositori supplier — bisa ditambah, diedit, dan dihapus pengguna.
class SupplierRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<SupplierModel>> getAll({String? search}) async {
    final db = await _db.database;
    final trimmed = search?.trim() ?? '';
    final results = await db.query(
      'suppliers',
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name ASC',
    );
    return results.map((m) => SupplierModel.fromMap(m)).toList();
  }

  Future<SupplierModel?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'suppliers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SupplierModel.fromMap(results.first);
  }

  /// Nama supplier saja — dipakai untuk dropdown di form produk.
  Future<List<String>> getNames() async {
    final db = await _db.database;
    final results = await db.rawQuery(
      'SELECT name FROM suppliers ORDER BY name ASC',
    );
    return results.map((m) => m['name'] as String).toList();
  }

  Future<int> insert(SupplierModel supplier) async {
    final db = await _db.database;
    return await db.insert('suppliers', supplier.toMap());
  }

  Future<int> update(SupplierModel supplier) async {
    final db = await _db.database;
    return await db.update(
      'suppliers',
      supplier.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [supplier.id],
    );
  }

  /// Hapus supplier. Kalau masih dipakai di catatan hutang, kaitannya
  /// dilepas dulu supaya tidak melanggar foreign key.
  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.transaction((txn) async {
      await txn.update(
        'debts',
        {'supplier_id': null},
        where: 'supplier_id = ?',
        whereArgs: [id],
      );
      return txn.delete('suppliers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> count() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM suppliers');
    return (rows.first['c'] as int?) ?? 0;
  }
}
