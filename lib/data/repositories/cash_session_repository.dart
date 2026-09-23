import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/cash_model.dart';
import '../models/cash_session_model.dart';
import 'cash_repository.dart';

/// Repositori sesi kas — membuka laci, menghitung uang, dan menyimpan
/// selisihnya.
///
/// Satu sesi mewakili satu "giliran jaga": dari laci dibuka sampai uangnya
/// dihitung dan dicocokkan dengan catatan sistem.
///
/// **Dua aturan yang menjaga seluruh fitur ini:**
///
///   1. **Hanya boleh ada satu sesi terbuka.** Dua sesi terbuka membuat
///      pertanyaan "seharusnya berapa isi laci sekarang?" tidak bisa dijawab,
///      karena tidak ada cara membagi mutasi kas ke dua sesi yang berjalan
///      bersamaan.
///   2. **Angka "seharusnya" selalu dibaca dari [CashRepository.getSaldo()],
///      bukan dihitung dari rentang waktu sesi.** Itu sumber yang sama dengan
///      layar Buku Kas, jadi angka yang dilihat kasir di layar Kas dan angka
///      yang dipakai menilai hitungannya tidak mungkin berbeda. Kalau dihitung
///      sendiri, satu perubahan cara pencatatan kas akan membuat keduanya
///      berselisih — dan kasir dituduh kurang uang tanpa sebab.
class CashSessionRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final CashRepository _cash = CashRepository();

  // -------------------------------------------------------------- membaca

  /// Sesi yang sedang terbuka, atau `null` kalau laci belum dibuka.
  Future<CashSessionModel?> sesiAktif() async {
    final db = await _db.database;
    final rows = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: [CashSessionStatus.terbuka],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return CashSessionModel.fromMap(rows.first);
  }

  /// Id sesi terbuka — dipakai [SaleRepository] untuk menandai nota.
  ///
  /// `null` bukan keadaan darurat: nota tanpa sesi tetap sah, dan penjualan
  /// tidak pernah dihalangi oleh sesi yang belum dibuka. Karena itu kolom
  /// `sales.session_id` boleh kosong.
  Future<int?> idSesiAktif() async {
    final sesi = await sesiAktif();
    return sesi?.id;
  }

  /// Riwayat sesi yang sudah ditutup, terbaru dulu.
  Future<List<CashSessionModel>> riwayat({int limit = 30}) async {
    final db = await _db.database;
    final rows = await db.query(
      'cash_sessions',
      where: 'status = ?',
      whereArgs: [CashSessionStatus.tertutup],
      orderBy: 'closed_at DESC, id DESC',
      limit: limit,
    );
    return rows.map((m) => CashSessionModel.fromMap(m)).toList();
  }

  /// Uang masuk & keluar selama satu sesi, dari Buku Kas.
  ///
  /// Sesi yang masih terbuka dihitung sampai sekarang.
  Future<CashSummary> ringkasanSesi(CashSessionModel sesi) async {
    final akhir = sesi.closedAt ?? DateTime.now();
    return _cash.getSummary(sesi.openedAt, akhir);
  }

  /// Jumlah nota dan total penjualan yang tercatat dalam satu sesi.
  ///
  /// Dibaca lewat view `sales_aktif`, jadi transaksi yang dibatalkan tidak
  /// ikut terhitung — sama seperti seluruh laporan lain.
  Future<({int nota, int total})> penjualanSesi(int sessionId) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS nota, COALESCE(SUM(total_amount), 0) AS total
      FROM sales_aktif
      WHERE session_id = ?
    ''', [sessionId]);
    final r = rows.first;
    return (
      nota: (r['nota'] as int?) ?? 0,
      total: (r['total'] as int?) ?? 0,
    );
  }

  // -------------------------------------------------------------- menulis

  /// Buka sesi kas baru.
  ///
  /// [oleh] diisi email pengguna yang membuka — disimpan sebagai teks, bukan
  /// id, karena berkas cadangan bisa dipulihkan di perangkat lain yang tidak
  /// punya akun itu.
  ///
  /// Ditolak kalau masih ada sesi terbuka. Saldo awal **tidak diketik
  /// pengguna**: diambil dari saldo sistem supaya aritmetikanya pasti. Kalau
  /// uang di laci memang tidak sama dengan catatan sistem, selisih itulah yang
  /// muncul di [tutupSesi] — satu angka, di tempat yang benar.
  Future<CashSessionModel> bukaSesi({String? oleh}) async {
    final db = await _db.database;
    // Dibaca di luar transaksi: `getSaldo` memakai koneksi yang sama, dan
    // memanggilnya di dalam transaksi bisa mengunci diri sendiri.
    final saldoAwal = await _cash.getSaldo();
    final now = DateTime.now();
    late int id;

    await db.transaction((txn) async {
      final ada = await txn.query(
        'cash_sessions',
        columns: ['id'],
        where: 'status = ?',
        whereArgs: [CashSessionStatus.terbuka],
        limit: 1,
      );
      if (ada.isNotEmpty) {
        throw Exception(
          'Masih ada sesi kas yang terbuka. Tutup dulu sesi itu '
          'sebelum membuka sesi baru.',
        );
      }
      id = await txn.insert('cash_sessions', {
        'opened_at': now.toIso8601String(),
        'opening_balance': saldoAwal,
        'opened_by': oleh,
        'status': CashSessionStatus.terbuka,
      });
    });

    return CashSessionModel(
      id: id,
      openedAt: now,
      openingBalance: saldoAwal,
      openedBy: oleh,
      status: CashSessionStatus.terbuka,
    );
  }

  /// Tutup sesi: simpan uang fisik yang dihitung kasir dan selisihnya.
  ///
  /// [uangFisik] adalah hasil hitung uang di laci, bukan angka sistem.
  /// Selisihnya dihitung sekali di sini lalu **disimpan**, bukan dihitung ulang
  /// saat dibaca: kalau ada mutasi kas lama yang menyusul dicatat, angka yang
  /// sudah dilihat pemilik toko tidak boleh berubah diam-diam.
  ///
  /// [catatan] wajib diisi pemanggil kalau selisihnya tidak nol — penjelasan
  /// kasir adalah satu-satunya hal yang membuat selisih bisa ditindaklanjuti.
  Future<CashSessionModel> tutupSesi({
    required int id,
    required int uangFisik,
    String? oleh,
    String? catatan,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'cash_sessions',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw Exception('Sesi kas tidak ditemukan.');
    }
    final sesi = CashSessionModel.fromMap(rows.first);
    if (!sesi.masihTerbuka) {
      throw Exception('Sesi kas ini sudah ditutup.');
    }

    // Sumber yang sama dengan layar Buku Kas — lihat catatan kelas.
    final seharusnya = await _cash.getSaldo();
    final selisih = uangFisik - seharusnya;
    final now = DateTime.now();

    await db.update(
      'cash_sessions',
      {
        'closed_at': now.toIso8601String(),
        'expected_closing': seharusnya,
        'counted_cash': uangFisik,
        'difference': selisih,
        'closed_by': oleh,
        'note': catatan,
        'status': CashSessionStatus.tertutup,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return CashSessionModel(
      id: id,
      openedAt: sesi.openedAt,
      openingBalance: sesi.openingBalance,
      openedBy: sesi.openedBy,
      closedAt: now,
      expectedClosing: seharusnya,
      countedCash: uangFisik,
      difference: selisih,
      closedBy: oleh,
      note: catatan,
      status: CashSessionStatus.tertutup,
    );
  }
}
