import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/report_models.dart';

/// Repositori laporan penjualan.
///
/// Semua rentang waktu dihitung setengah terbuka: `created_at >= start` dan
/// `created_at < end`. Karena `created_at` disimpan sebagai ISO-8601 waktu
/// lokal dengan format tetap, perbandingan teks sudah kronologis.
class ReportRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Ringkasan angka untuk rentang [start] sampai [end].
  Future<ReportSummary> getSummary(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) AS total_sales,
             COALESCE(SUM(total_profit), 0) AS total_profit,
             COUNT(*) AS transactions,
             COALESCE(SUM(total_items), 0) AS items_sold
      FROM sales
      WHERE created_at >= ? AND created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    if (rows.isEmpty) return const ReportSummary();
    final r = rows.first;
    return ReportSummary(
      totalSales: (r['total_sales'] as int?) ?? 0,
      totalProfit: (r['total_profit'] as int?) ?? 0,
      transactions: (r['transactions'] as int?) ?? 0,
      itemsSold: (r['items_sold'] as int?) ?? 0,
    );
  }

  /// Detail setiap produk yang terjual dalam rentang waktu, lengkap dengan
  /// tanggal & waktu transaksinya. Ini yang ditampilkan di laporan harian.
  ///
  /// `debts` di-join dari kiri lewat `sale_id` supaya setiap baris tahu sisa
  /// piutangnya **saat ini** — jadi laporan bisa membedakan transaksi tunai,
  /// piutang yang belum dibayar, dan piutang yang sudah lunas.
  Future<List<ReportItemDetail>> getItemDetails(
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT si.product_name, si.quantity, si.cost_price, si.sell_price,
             si.subtotal, s.created_at, s.invoice_number, s.customer_name,
             s.payment_method, s.is_debt, s.total_amount, s.paid_amount,
             COALESCE(d.amount - d.paid_amount, 0) AS sisa
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      LEFT JOIN debts d ON d.sale_id = s.id
      WHERE s.created_at >= ? AND s.created_at < ?
      ORDER BY s.created_at DESC, si.id ASC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return rows.map((m) => ReportItemDetail.fromMap(m)).toList();
  }

  /// Produk terlaris pada rentang waktu.
  Future<List<TopProduct>> getTopProducts(
    DateTime start,
    DateTime end, {
    int limit = 5,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT si.product_name,
             SUM(si.quantity) AS qty,
             SUM(si.subtotal) AS revenue,
             -- Laba dihitung dari harga setelah potongan baris, bukan dari
             -- harga label. Kalau memakai sell_price, potongan kasir tidak
             -- ikut mengurangi laba dan laba yang dilaporkan jadi terlalu besar.
             SUM(si.subtotal - si.cost_price * si.quantity) AS profit
      FROM sale_items si
      INNER JOIN sales s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY si.product_name
      ORDER BY qty DESC, revenue DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return rows
        .map((r) => TopProduct(
              productName: r['product_name'] as String,
              quantity: (r['qty'] as int?) ?? 0,
              revenue: (r['revenue'] as int?) ?? 0,
              profit: (r['profit'] as int?) ?? 0,
            ))
        .toList();
  }

  /// Total penjualan per hari dalam rentang waktu — untuk grafik.
  Future<List<({DateTime date, int total})>> getDailyTotals(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT date(created_at) AS d, COALESCE(SUM(total_amount), 0) AS total
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY d
      ORDER BY d ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <({DateTime date, int total})>[];
    for (final r in rows) {
      final parsed = DateTime.tryParse(r['d'] as String? ?? '');
      if (parsed == null) continue;
      result.add((date: parsed, total: (r['total'] as int?) ?? 0));
    }
    return result;
  }

  /// Total penjualan per bulan dalam satu tahun — untuk laporan bulanan.
  Future<List<({int month, int total})>> getMonthlyTotals(int year) async {
    final db = await _db.database;
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final rows = await db.rawQuery('''
      SELECT strftime('%m', created_at) AS m,
             COALESCE(SUM(total_amount), 0) AS total
      FROM sales
      WHERE created_at >= ? AND created_at < ?
      GROUP BY m
      ORDER BY m ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <({int month, int total})>[];
    for (final r in rows) {
      final month = int.tryParse(r['m'] as String? ?? '');
      if (month == null) continue;
      result.add((month: month, total: (r['total'] as int?) ?? 0));
    }
    return result;
  }

  /// Ringkasan hutang belum lunas (dipakai di beranda).
  Future<({int piutang, int hutang})> getDebtTotals() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT type, COALESCE(SUM(amount - paid_amount), 0) AS sisa
      FROM debts
      WHERE status = 'belum_lunas'
      GROUP BY type
    ''');
    var piutang = 0;
    var hutang = 0;
    for (final r in rows) {
      if (r['type'] == 'piutang') {
        piutang = (r['sisa'] as int?) ?? 0;
      } else {
        hutang = (r['sisa'] as int?) ?? 0;
      }
    }
    return (piutang: piutang, hutang: hutang);
  }

  /// Jumlah transaksi pada satu hari — untuk ringkasan cepat.
  Future<int> countSalesOn(DateTime day) async {
    final db = await _db.database;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM sales WHERE created_at >= ? AND created_at < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
