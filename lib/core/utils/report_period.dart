import 'formatters.dart';

/// Jenis periode laporan.
enum ReportPeriodType { harian, mingguan, bulanan }

/// Rentang waktu laporan beserta labelnya.
///
/// Rentang selalu setengah terbuka: `[start, end)`. Ini menghindari transaksi
/// di detik tepat tengah malam terhitung dua kali.
class ReportPeriod {
  final ReportPeriodType type;
  final DateTime anchor;

  const ReportPeriod({required this.type, required this.anchor});

  factory ReportPeriod.today() {
    return ReportPeriod(type: ReportPeriodType.harian, anchor: DateTime.now());
  }

  /// Awal periode.
  DateTime get start {
    switch (type) {
      case ReportPeriodType.harian:
        return DateTime(anchor.year, anchor.month, anchor.day);
      case ReportPeriodType.mingguan:
        // Minggu dimulai hari Senin.
        final monday = anchor.subtract(Duration(days: anchor.weekday - 1));
        return DateTime(monday.year, monday.month, monday.day);
      case ReportPeriodType.bulanan:
        return DateTime(anchor.year, anchor.month, 1);
    }
  }

  /// Akhir periode (eksklusif).
  DateTime get end {
    switch (type) {
      case ReportPeriodType.harian:
        return start.add(const Duration(days: 1));
      case ReportPeriodType.mingguan:
        return start.add(const Duration(days: 7));
      case ReportPeriodType.bulanan:
        // DateTime menangani tahun kabisat dan pergantian tahun otomatis.
        return DateTime(anchor.year, anchor.month + 1, 1);
    }
  }

  /// Tanggal terakhir yang termasuk periode (inklusif) — untuk ditampilkan.
  DateTime get lastDay => end.subtract(const Duration(days: 1));

  /// Label panjang untuk judul.
  String get label {
    switch (type) {
      case ReportPeriodType.harian:
        return Formatters.dateWithDay(start);
      case ReportPeriodType.mingguan:
        return Formatters.dateRange(start, lastDay);
      case ReportPeriodType.bulanan:
        return '${Formatters.monthNameFull(start.month)} ${start.year}';
    }
  }

  /// Label pendek untuk subjudul / chip.
  String get shortLabel {
    switch (type) {
      case ReportPeriodType.harian:
        return 'Harian';
      case ReportPeriodType.mingguan:
        return 'Mingguan';
      case ReportPeriodType.bulanan:
        return 'Bulanan';
    }
  }

  /// Apakah periode ini sedang berjalan (belum berakhir).
  bool get isCurrent {
    final now = DateTime.now();
    return !now.isBefore(start) && now.isBefore(end);
  }

  /// Periode berikutnya. Ditolak kalau sudah mencapai periode berjalan.
  ReportPeriod? next() {
    if (isCurrent) return null;
    final shifted = _shift(1);
    // Jangan lewat dari periode hari ini.
    if (!shifted.start.isBefore(DateTime.now())) return null;
    return shifted;
  }

  /// Periode sebelumnya.
  ReportPeriod previous() => _shift(-1);

  ReportPeriod _shift(int direction) {
    switch (type) {
      case ReportPeriodType.harian:
        return ReportPeriod(
          type: type,
          anchor: anchor.add(Duration(days: direction)),
        );
      case ReportPeriodType.mingguan:
        return ReportPeriod(
          type: type,
          anchor: anchor.add(Duration(days: 7 * direction)),
        );
      case ReportPeriodType.bulanan:
        return ReportPeriod(
          type: type,
          anchor: DateTime(anchor.year, anchor.month + direction, 1),
        );
    }
  }

  /// Ganti jenis periode sambil mempertahankan tanggal acuan.
  ReportPeriod withType(ReportPeriodType newType) {
    return ReportPeriod(type: newType, anchor: anchor);
  }

  /// Buat periode dengan tanggal acuan tertentu (dari pemilih tanggal).
  ReportPeriod withAnchor(DateTime newAnchor) {
    return ReportPeriod(type: type, anchor: newAnchor);
  }
}
