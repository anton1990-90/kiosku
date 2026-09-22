import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/debt_model.dart';

/// Repositori hutang / piutang. Semua data lokal (offline).
class DebtRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<DebtModel>> getAll({
    String? type,
    String? status,
    String? search,
  }) async {
    final db = await _db.database;
    final where = <String>[];
    final args = <dynamic>[];

    if (type != null && type.isNotEmpty && type != 'semua') {
      where.add('type = ?');
      args.add(type);
    }
    if (status != null && status.isNotEmpty && status != 'semua') {
      where.add('status = ?');
      args.add(status);
    }
    if (search != null && search.trim().isNotEmpty) {
      where.add('party_name LIKE ?');
      args.add('%${search.trim()}%');
    }

    final results = await db.query(
      'debts',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      // Belum lunas di atas, lalu yang paling baru.
      orderBy: "status ASC, due_date IS NULL, due_date ASC, created_at DESC",
    );
    return results.map((m) => DebtModel.fromMap(m)).toList();
  }

  Future<DebtModel?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return DebtModel.fromMap(results.first);
  }

  Future<int> insert(DebtModel debt) async {
    final db = await _db.database;
    return await db.insert('debts', debt.toMap());
  }

  Future<int> update(DebtModel debt) async {
    final db = await _db.database;
    return await db.update(
      'debts',
      debt.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [debt.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  /// Catat pembayaran (bisa sebagian). Menghitung ulang sisa dan status.
  Future<void> addPayment({
    required int debtId,
    required int amount,
    String? note,
  }) async {
    if (amount <= 0) return;
    final db = await _db.database;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debtId],
        limit: 1,
      );
      if (rows.isEmpty) return;

      final debt = DebtModel.fromMap(rows.first);
      final newPaid = debt.paidAmount + amount;
      final isLunas = newPaid >= debt.amount;

      await txn.insert('debt_payments', {
        'debt_id': debtId,
        'amount': amount,
        'note': note,
        'created_at': DateTime.now().toIso8601String(),
      });

      await txn.update(
        'debts',
        {
          'paid_amount': isLunas ? debt.amount : newPaid,
          'status': isLunas ? DebtStatus.lunas : DebtStatus.belumLunas,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [debtId],
      );
    });
  }

  Future<List<DebtPaymentModel>> getPayments(int debtId) async {
    final db = await _db.database;
    final results = await db.query(
      'debt_payments',
      where: 'debt_id = ?',
      whereArgs: [debtId],
      orderBy: 'created_at DESC',
    );
    return results.map((m) => DebtPaymentModel.fromMap(m)).toList();
  }

  /// Total belum lunas, dipisah piutang dan hutang.
  Future<({int piutang, int hutang, int piutangCount, int hutangCount})>
      getSummary() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT type,
             COALESCE(SUM(amount - paid_amount), 0) AS sisa,
             COUNT(*) AS jumlah
      FROM debts
      WHERE status = ?
      GROUP BY type
    ''', [DebtStatus.belumLunas]);

    var piutang = 0;
    var hutang = 0;
    var piutangCount = 0;
    var hutangCount = 0;

    for (final r in rows) {
      final sisa = (r['sisa'] as int?) ?? 0;
      final jumlah = (r['jumlah'] as int?) ?? 0;
      if (r['type'] == DebtType.piutang) {
        piutang = sisa;
        piutangCount = jumlah;
      } else {
        hutang = sisa;
        hutangCount = jumlah;
      }
    }

    return (
      piutang: piutang,
      hutang: hutang,
      piutangCount: piutangCount,
      hutangCount: hutangCount,
    );
  }

  /// Hutang yang sudah lewat jatuh tempo.
  /// Dibandingkan per tanggal (bukan per jam) supaya jatuh tempo hari ini
  /// belum dianggap terlambat.
  Future<int> getOverdueCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM debts '
      'WHERE status = ? AND due_date IS NOT NULL AND date(due_date) < date(?)',
      [DebtStatus.belumLunas, DateTime.now().toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
