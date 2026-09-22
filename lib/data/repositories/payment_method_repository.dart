import '../database/database_helper.dart';
import '../models/payment_method_model.dart';

/// Repositori metode pembayaran.
///
/// Metode yang aktif dipakai sebagai pilihan di layar Kasir. Menonaktifkan
/// sebuah metode tidak menghapus riwayat transaksi yang sudah memakainya.
class PaymentMethodRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<PaymentMethodModel>> getAll({bool onlyActive = false}) async {
    final db = await _db.database;
    final results = await db.query(
      'payment_methods',
      where: onlyActive ? 'is_active = 1' : null,
      orderBy: 'sort_order ASC, name ASC',
    );
    return results.map((m) => PaymentMethodModel.fromMap(m)).toList();
  }

  Future<int> insert(PaymentMethodModel method) async {
    final db = await _db.database;
    return await db.insert('payment_methods', method.toMap());
  }

  Future<int> update(PaymentMethodModel method) async {
    final db = await _db.database;
    return await db.update(
      'payment_methods',
      method.toMap(),
      where: 'id = ?',
      whereArgs: [method.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('payment_methods', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setActive(int id, bool isActive) async {
    final db = await _db.database;
    await db.update(
      'payment_methods',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Kode metode pembayaran yang aktif — dipakai layar Kasir.
  Future<List<String>> getActiveCodes() async {
    final db = await _db.database;
    final results = await db.query(
      'payment_methods',
      columns: ['code'],
      where: 'is_active = 1',
      orderBy: 'sort_order ASC',
    );
    return results.map((m) => m['code'] as String).toList();
  }

  /// Cari nama tampilan dari kode. Kalau tidak ada, kembalikan kodenya.
  Future<String> displayName(String code) async {
    final db = await _db.database;
    final results = await db.query(
      'payment_methods',
      columns: ['name'],
      where: 'code = ?',
      whereArgs: [code],
      limit: 1,
    );
    if (results.isEmpty) return code;
    return (results.first['name'] as String?) ?? code;
  }
}
