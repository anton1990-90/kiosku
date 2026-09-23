/// Status sesi kas.
///
/// Sesi yang ditutup **tidak dihapus**, sama seperti transaksi yang dibatalkan
/// (versi 7): riwayat hitung uang harus bisa dilihat lagi berbulan-bulan
/// kemudian, karena justru itulah gunanya — menjawab "kenapa kas saya beda?"
/// dan "siapa yang memegang laci saat itu?".
class CashSessionStatus {
  static const terbuka = 'open';
  static const tertutup = 'closed';

  static const semua = [terbuka, tertutup];

  /// Label Indonesia untuk ditampilkan.
  static String label(String status) =>
      status == terbuka ? 'Sedang terbuka' : 'Sudah ditutup';
}

/// Satu sesi kas — dari laci dibuka sampai uangnya dihitung.
///
/// Sesi ini yang menjawab pertanyaan harian pemilik toko: "uang di laci
/// sekarang seharusnya berapa, dan apakah jumlahnya cocok?". Tanpa sesi,
/// selisih kas baru ketahuan berbulan-bulan kemudian dan tidak bisa lagi
/// ditelusuri ke siapa.
///
/// Dua angka yang paling penting, [openingBalance] dan [expectedClosing],
/// **sama-sama dibaca dari `CashRepository.getSaldo()`** — sumber yang sama
/// dengan layar Buku Kas. Jadi "seharusnya ada di laci" tidak mungkin berbeda
/// dengan saldo yang dilihat kasir di layar Kas. Kalau sesi menghitung sendiri
/// dari rentang waktunya, satu perubahan cara pencatatan kas akan membuat dua
/// angka itu berselisih, dan kasir dituduh kurang uang tanpa sebab.
class CashSessionModel {
  final int? id;
  final DateTime openedAt;

  /// Saldo kas sistem saat sesi dibuka. Diisi otomatis, bukan diketik.
  final int openingBalance;

  /// Email pembuka sesi — snapshot, bukan id pengguna.
  final String? openedBy;

  final DateTime? closedAt;

  /// Saldo kas sistem saat sesi ditutup — "seharusnya ada di laci".
  final int? expectedClosing;

  /// Uang fisik yang benar-benar dihitung kasir.
  final int? countedCash;

  /// [countedCash] - [expectedClosing]. **Negatif berarti uang di laci kurang.**
  final int? difference;

  /// Email penutup sesi — snapshot, bukan id pengguna.
  final String? closedBy;

  final String? note;
  final String status;

  CashSessionModel({
    this.id,
    required this.openedAt,
    this.openingBalance = 0,
    this.openedBy,
    this.closedAt,
    this.expectedClosing,
    this.countedCash,
    this.difference,
    this.closedBy,
    this.note,
    this.status = CashSessionStatus.terbuka,
  });

  bool get masihTerbuka => status == CashSessionStatus.terbuka;

  /// Apakah selisihnya pas — tidak lebih dan tidak kurang.
  bool get cocok => (difference ?? 0) == 0;

  /// Uang yang seharusnya bertambah selama sesi ini.
  ///
  /// Selama sesi masih terbuka, [expectedClosing] belum ada, jadi yang dipakai
  /// adalah saldo terakhir yang diketahui ([openingBalance]) — hasilnya nol.
  /// Pemanggil yang butuh angka berjalan harus membaca saldo sistem terkini.
  int get pergerakanSesi => (expectedClosing ?? openingBalance) - openingBalance;

  /// Selisih dengan tanda untuk ditampilkan: `Lebih` / `Kurang` / `Cocok`.
  String get labelSelisih {
    final d = difference ?? 0;
    if (d == 0) return 'Cocok';
    return d > 0 ? 'Lebih' : 'Kurang';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'opened_at': openedAt.toIso8601String(),
      'opening_balance': openingBalance,
      'opened_by': openedBy,
      'closed_at': closedAt?.toIso8601String(),
      'expected_closing': expectedClosing,
      'counted_cash': countedCash,
      'difference': difference,
      'closed_by': closedBy,
      'note': note,
      'status': status,
    };
  }

  factory CashSessionModel.fromMap(Map<String, dynamic> map) {
    return CashSessionModel(
      id: map['id'] as int?,
      openedAt:
          DateTime.tryParse(map['opened_at'] as String? ?? '') ?? DateTime.now(),
      // Baris lama (kalau ada) belum tentu punya kolom ini.
      openingBalance: (map['opening_balance'] as int?) ?? 0,
      openedBy: map['opened_by'] as String?,
      closedAt: DateTime.tryParse(map['closed_at'] as String? ?? ''),
      expectedClosing: map['expected_closing'] as int?,
      countedCash: map['counted_cash'] as int?,
      difference: map['difference'] as int?,
      closedBy: map['closed_by'] as String?,
      note: map['note'] as String?,
      // Baris sebelum versi 10 belum ada; sesi tanpa status dianggap tertutup
      // supaya tidak pernah muncul sebagai sesi yang bisa ditutup dua kali.
      status: (map['status'] as String?) ?? CashSessionStatus.tertutup,
    );
  }
}
