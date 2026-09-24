import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../../core/utils/angka.dart';
import '../models/accounting_models.dart';
import '../models/cash_model.dart';
import 'cash_repository.dart';
import 'debt_repository.dart';

/// Repositori laporan keuangan.
///
/// Laporan disusun turunan dari transaksi yang sudah tercatat:
///   * Laba rugi      — penjualan, HPP (harga pokok penjualan), dan beban
///   * Perubahan ekuitas — laba ditahan awal, laba periode, prive
///   * Neraca         — kas, persediaan, piutang vs hutang & ekuitas
///   * Arus kas       — mutasi kas dikelompokkan per kategori
///
/// Rentang waktu selalu setengah terbuka: `>= start` dan `< end`.
class AccountingRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final CashRepository _cash = CashRepository();
  final DebtRepository _debt = DebtRepository();

  // -------------------------------------------------------------- laba rugi

  /// Pendapatan bruto (total penjualan) pada rentang waktu.
  Future<int> getPendapatan(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0)       AS total
      FROM sales_aktif
      WHERE created_at >= ? AND created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return Angka.uang(rows.first['total']);
  }

  /// Harga Pokok Penjualan = modal barang yang terjual.
  Future<int> getHpp(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(si.cost_price * si.quantity), 0) AS total
      FROM sale_items si
      INNER JOIN sales_aktif s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return Angka.uang(rows.first['total']);
  }

  /// Laporan laba rugi lengkap satu periode.
  Future<LabaRugi> getLabaRugi(DateTime start, DateTime end) async {
    final pendapatan = await getPendapatan(start, end);
    final hpp = await getHpp(start, end);
    final beban = await _cash.getBebanPerKategori(start, end);
    final totalBeban = beban.fold(0, (s, b) => s + b.amount);

    return LabaRugi(
      pendapatan: pendapatan,
      hpp: hpp,
      beban: beban,
      totalBeban: totalBeban,
    );
  }

  // ------------------------------------------------------- perubahan ekuitas

  /// Laba bersih kumulatif sebelum [start] dikurangi prive kumulatif —
  /// inilah "modal awal" pada laporan perubahan ekuitas.
  Future<int> getLabaDitahanSebelum(DateTime start) async {
    final db = await _db.database;
    final iso = start.toIso8601String();

    final penjualan = await db.rawQuery('''
      SELECT COALESCE(SUM(total_amount), 0) AS total
      FROM sales_aktif WHERE created_at < ?
    ''', [iso]);
    final hpp = await db.rawQuery('''
      SELECT COALESCE(SUM(si.cost_price * si.quantity), 0) AS total
      FROM sale_items si
      INNER JOIN sales_aktif s ON s.id = si.sale_id
      WHERE s.created_at < ?
    ''', [iso]);
    final beban = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM expenses WHERE date < ?
    ''', [iso]);
    final prive = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM prive WHERE date < ?
    ''', [iso]);

    final labaKumulatif =
        Angka.uang(penjualan.first['total']) -
            Angka.uang(hpp.first['total']) -
            Angka.uang(beban.first['total']);
    final priveKumulatif = Angka.uang(prive.first['total']);

    return labaKumulatif - priveKumulatif;
  }

  /// Total setoran modal pemilik (kategori kas "modal") sebelum [start].
  Future<int> getModalDisetorSebelum(DateTime start) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM cash_transactions
      WHERE type = ? AND category = ? AND date < ?
    ''', [CashType.masuk, CashCategory.modal, start.toIso8601String()]);
    return Angka.uang(rows.first['total']);
  }

  /// Laporan perubahan ekuitas satu periode.
  Future<PerubahanEkuitas> getPerubahanEkuitas(
    DateTime start,
    DateTime end,
  ) async {
    final modalAwal = await getLabaDitahanSebelum(start);
    final laba = await getLabaRugi(start, end);
    final prive = await _cash.totalPrive(start, end);

    final db = await _db.database;
    final modalRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM cash_transactions
      WHERE type = ? AND category = ? AND date >= ? AND date < ?
    ''', [
      CashType.masuk,
      CashCategory.modal,
      start.toIso8601String(),
      end.toIso8601String(),
    ]);

    return PerubahanEkuitas(
      modalAwal: modalAwal,
      labaBersih: laba.labaBersih,
      prive: prive,
      modalDisetor: Angka.uang(modalRows.first['total']),
    );
  }

  // ------------------------------------------------------------------ neraca

  /// Laporan posisi keuangan — memakai nilai terkini.
  Future<Neraca> getNeraca() async {
    final db = await _db.database;

    final kas = await _cash.getSaldo();
    final persediaan = await _cash.getNilaiPersediaan();
    final debtSummary = await _debt.getSummary();

    final modalRows = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM cash_transactions
      WHERE type = ? AND category = ?
    ''', [CashType.masuk, CashCategory.modal]);

    final penjualan = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) AS total FROM sales_aktif',
    );
    // Tanpa join ke `sales_aktif`, HPP transaksi yang sudah dibatalkan ikut
    // terhitung — padahal barangnya sudah kembali ke rak. Ini satu-satunya
    // query `sale_items` yang tidak menyaring lewat `sale_id`, jadi join-nya
    // ditulis di sini.
    final hpp = await db.rawQuery('''
      SELECT COALESCE(SUM(si.cost_price * si.quantity), 0) AS total
      FROM sale_items si
      INNER JOIN sales_aktif s ON s.id = si.sale_id
    ''');
    final beban = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses',
    );
    final prive = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM prive',
    );

    final labaDitahan =
        Angka.uang(penjualan.first['total']) -
            Angka.uang(hpp.first['total']) -
            Angka.uang(beban.first['total']) -
            Angka.uang(prive.first['total']);

    return Neraca(
      kas: kas,
      persediaan: persediaan,
      piutang: debtSummary.piutang,
      hutangUsaha: debtSummary.hutang,
      modalDisetor: Angka.uang(modalRows.first['total']),
      labaDitahan: labaDitahan,
    );
  }

  // --------------------------------------------------------------- arus kas

  Future<ArusKas> getArusKas(DateTime start, DateTime end) async {
    final saldoAwal = await _cash.getSaldoSebelum(start);
    final rincian = await _cash.getArusKas(start, end);
    return ArusKas(saldoAwal: saldoAwal, rincian: rincian);
  }

  // ------------------------------------------------------- daftar transaksi

  /// Transaksi penjualan pada rentang waktu, lengkap dengan rincian itemnya.
  Future<List<SaleWithItems>> getSalesWithItems(
    DateTime start,
    DateTime end, {
    int limit = 200,
  }) async {
    final db = await _db.database;
    final saleRows = await db.rawQuery('''
      SELECT * FROM sales_aktif
      WHERE created_at >= ? AND created_at < ?
      ORDER BY created_at DESC
      LIMIT ?
    ''', [start.toIso8601String(), end.toIso8601String(), limit]);

    if (saleRows.isEmpty) return const [];

    final ids = saleRows.map((r) => r['id'] as int).toList();
    final placeholders = List.filled(ids.length, '?').join(',');
    final itemRows = await db.rawQuery('''
      SELECT sale_id, product_name, quantity, sell_price, cost_price, subtotal,
             discount
      FROM sale_items
      WHERE sale_id IN ($placeholders)
      ORDER BY id ASC
    ''', ids);

    final bySale = <int, List<SaleLine>>{};
    for (final r in itemRows) {
      final saleId = r['sale_id'] as int;
      bySale.putIfAbsent(saleId, () => []).add(
            SaleLine(
              productName: (r['product_name'] as String?) ?? '-',
              quantity: Angka.jumlah(r['quantity']),
              sellPrice: (r['sell_price'] as int?) ?? 0,
              costPrice: (r['cost_price'] as int?) ?? 0,
              subtotal: (r['subtotal'] as int?) ?? 0,
              discount: (r['discount'] as int?) ?? 0,
            ),
          );
    }

    return saleRows.map((r) {
      final id = r['id'] as int;
      return SaleWithItems(
        saleId: id,
        invoiceNumber: (r['invoice_number'] as String?) ?? '-',
        customerName: r['customer_name'] as String?,
        paymentMethod: (r['payment_method'] as String?) ?? 'tunai',
        totalAmount: (r['total_amount'] as int?) ?? 0,
        totalProfit: (r['total_profit'] as int?) ?? 0,
        totalItems: Angka.jumlah(r['total_items']),
        paidAmount: (r['paid_amount'] as int?) ?? 0,
        changeAmount: (r['change_amount'] as int?) ?? 0,
        isDebt: ((r['is_debt'] as int?) ?? 0) == 1,
        discount: (r['discount'] as int?) ?? 0,
        createdAt:
            DateTime.tryParse(r['created_at'] as String? ?? '') ??
                DateTime.now(),
        lines: bySale[id] ?? const [],
      );
    }).toList();
  }

  /// Ringkasan produk terjual per produk pada rentang waktu.
  Future<List<({String name, int qty, int revenue, int profit})>>
      getRekapProduk(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT si.product_name AS name,
             SUM(si.quantity) AS qty,
             SUM(si.subtotal) AS revenue,
             -- Sama seperti daftar produk terlaris: laba harus dihitung dari
             -- harga setelah potongan, supaya potongan kasir mengurangi laba.
             SUM(si.subtotal - si.cost_price * si.quantity) AS profit
      FROM sale_items si
      INNER JOIN sales_aktif s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
      GROUP BY si.product_name
      ORDER BY revenue DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);

    return rows
        .map((r) => (
              name: (r['name'] as String?) ?? '-',
              qty: Angka.jumlah(r['qty']),
              revenue: Angka.uang(r['revenue']),
              profit: Angka.uang(r['profit']),
            ))
        .toList();
  }

  /// Jumlah baris item terjual pada rentang waktu — dipakai untuk
  /// memberi tahu pengguna kalau rincian dipotong.
  Future<int> countItemDetails(DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM sale_items si
      INNER JOIN sales_aktif s ON s.id = si.sale_id
      WHERE s.created_at >= ? AND s.created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}
