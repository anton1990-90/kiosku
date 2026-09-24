import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../core/utils/angka.dart';
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
      FROM sales_aktif
      WHERE created_at >= ? AND created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);

    if (rows.isEmpty) return const ReportSummary();
    final r = rows.first;
    return ReportSummary(
      totalSales: Angka.uang(r['total_sales']),
      totalProfit: Angka.uang(r['total_profit']),
      transactions: (r['transactions'] as int?) ?? 0,
      itemsSold: Angka.jumlah(r['items_sold']),
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
      INNER JOIN sales_aktif s ON s.id = si.sale_id
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
      INNER JOIN sales_aktif s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY si.product_name
      ORDER BY qty DESC, revenue DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return rows
        .map((r) => TopProduct(
              productName: r['product_name'] as String,
              quantity: Angka.jumlah(r['qty']),
              revenue: Angka.uang(r['revenue']),
              profit: Angka.uang(r['profit']),
            ))
        .toList();
  }

  /// Produk yang paling sedikit terjual pada rentang waktu.
  ///
  /// Berbeda dari [getTopProducts] yang berangkat dari `sale_items`, di sini
  /// sumbernya tabel `products`. Alasannya: barang yang **tidak terjual sama
  /// sekali** justru yang paling perlu diketahui pemilik toko, dan produk
  /// seperti itu tidak punya satu pun baris di `sale_items` untuk dibaca.
  /// Kalau query-nya dimulai dari `sale_items`, daftarnya diam-diam berubah
  /// arti menjadi "paling sedikit di antara yang laku".
  ///
  /// Syarat tanggalnya ada **di dalam** subquery, bukan di `WHERE`. Menaruhnya
  /// di `WHERE` akan membuang baris produk yang tidak punya pasangan, dan
  /// menaruhnya di klausa `ON` saja tidak cukup: baris `sale_items` dari luar
  /// periode tetap ikut terbawa karena `s` yang gagal di-join menjadi NULL
  /// sementara `si` tetap ada, sehingga jumlah terjualnya jadi terlalu besar.
  Future<List<TopProduct>> getLeastProducts(
    DateTime start,
    DateTime end, {
    int limit = 5,
  }) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT p.name AS product_name,
             COALESCE(SUM(si.quantity), 0) AS qty,
             COALESCE(SUM(si.subtotal), 0) AS revenue,
             -- Laba memakai rumus yang sama dengan getTopProducts: dari harga
             -- setelah potongan baris, bukan dari harga label.
             COALESCE(SUM(si.subtotal - si.cost_price * si.quantity), 0) AS profit
      FROM products p
      LEFT JOIN (
        SELECT si.product_id, si.quantity, si.subtotal, si.cost_price
        FROM sale_items si
        INNER JOIN sales_aktif s ON s.id = si.sale_id
        WHERE s.created_at >= ? AND s.created_at < ?
      ) si ON si.product_id = p.id
      GROUP BY p.id, p.name
      -- Yang belum pernah terjual lebih dulu. Di antara sesama nol, barang yang
      -- stoknya paling banyak menumpuk adalah yang paling mendesak untuk
      -- dipikirkan; nama dipakai paling akhir supaya urutannya pasti dan tidak
      -- bergantung urutan baris tabel.
      ORDER BY qty ASC, p.stock DESC, p.name ASC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    return rows
        .map((r) => TopProduct(
              productName: r['product_name'] as String,
              quantity: Angka.jumlah(r['qty']),
              revenue: Angka.uang(r['revenue']),
              profit: Angka.uang(r['profit']),
            ))
        .toList();
  }

  /// Kunci satu hari dengan bentuk yang sama persis dengan `date(created_at)`
  /// di SQLite — `YYYY-MM-DD`. Dipakai untuk mencocokkan hasil query harian
  /// dengan tanggal yang diminta.
  static String _kunciHari(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Total penjualan [jumlahHari] hari terakhir, **selalu sebanyak itu**.
  ///
  /// [getDailyTotals] hanya mengembalikan hari yang ada penjualannya, jadi
  /// grafik "seminggu" bisa muncul sebagai tiga batang — dan itu menyesatkan,
  /// karena lebar grafiknya ikut berubah dan naik-turunnya tidak terbaca.
  /// Di sini hari yang kosong diisi nol, sehingga selalu ada satu batang per
  /// hari dan sumbu waktunya tetap.
  ///
  /// [hariIni] bisa disuntikkan supaya bisa diuji tanpa bergantung jam mesin.
  Future<List<({DateTime date, int total})>> getDailyTotalsTerakhir(
    int jumlahHari, {
    DateTime? hariIni,
  }) async {
    final acuan = hariIni ?? DateTime.now();
    final hariIni0 = DateTime(acuan.year, acuan.month, acuan.day);
    final mulai = DateTime(hariIni0.year, hariIni0.month,
        hariIni0.day - (jumlahHari - 1));
    final selesai = DateTime(hariIni0.year, hariIni0.month, hariIni0.day + 1);

    final rows = await getDailyTotals(mulai, selesai);
    final perHari = <String, int>{
      for (final r in rows) _kunciHari(r.date): r.total,
    };

    final hasil = <({DateTime date, int total})>[];
    for (var i = 0; i < jumlahHari; i++) {
      // Konstruktor DateTime menormalkan tanggal di luar bulan, jadi ini aman
      // untuk pergantian bulan dan tahun.
      final d = DateTime(mulai.year, mulai.month, mulai.day + i);
      hasil.add((date: d, total: perHari[_kunciHari(d)] ?? 0));
    }
    return hasil;
  }

  /// Total penjualan per hari dalam rentang waktu — untuk grafik.
  Future<List<({DateTime date, int total})>> getDailyTotals(
    DateTime start,
    DateTime end,
  ) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT date(created_at) AS d, COALESCE(SUM(total_amount), 0) AS total
      FROM sales_aktif
      WHERE created_at >= ? AND created_at < ?
      GROUP BY d
      ORDER BY d ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <({DateTime date, int total})>[];
    for (final r in rows) {
      final parsed = DateTime.tryParse(r['d'] as String? ?? '');
      if (parsed == null) continue;
      result.add((date: parsed, total: Angka.uang(r['total'])));
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
      FROM sales_aktif
      WHERE created_at >= ? AND created_at < ?
      GROUP BY m
      ORDER BY m ASC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    final result = <({int month, int total})>[];
    for (final r in rows) {
      final month = int.tryParse(r['m'] as String? ?? '');
      if (month == null) continue;
      result.add((month: month, total: Angka.uang(r['total'])));
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
        piutang = Angka.uang(r['sisa']);
      } else {
        hutang = Angka.uang(r['sisa']);
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
      'SELECT COUNT(*) AS c FROM sales_aktif WHERE created_at >= ? AND created_at < ?',
      [start.toIso8601String(), end.toIso8601String()],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
