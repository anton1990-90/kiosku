/// Utility formatters for Rupiah currency and dates.
/// Uses manual formatting (no external locale data needed) — fully offline.
class Formatters {
  Formatters._();

  /// Indonesian month names.
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  /// Indonesian day names (short, Mon-first).
  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  /// Format integer to Rupiah string: 65000 -> "Rp 65.000"
  static String rupiah(int amount) {
    final isNeg = amount < 0;
    final digits = (isNeg ? -amount : amount).toString();
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
    }
    return '${isNeg ? '-' : ''}Rp ${buffer.toString()}';
  }

  /// Format integer to compact Rupiah: 4200000 -> "Rp 4,2jt"
  static String rupiahCompact(int amount) {
    if (amount >= 1000000) {
      final jt = amount / 1000000;
      final str = jt % 1 == 0
          ? jt.toStringAsFixed(0)
          : jt.toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${str}jt';
    } else if (amount >= 1000) {
      final rb = amount / 1000;
      final str = rb % 1 == 0
          ? rb.toStringAsFixed(0)
          : rb.toStringAsFixed(1).replaceAll('.', ',');
      return 'Rp ${str}rb';
    }
    return rupiah(amount);
  }

  /// Format date: "21 Sep 2026"
  static String date(DateTime dt) {
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}';
  }

  /// Format date with time: "21 Sep 2026, 14:30"
  static String dateTime(DateTime dt) {
    return '${date(dt)}, ${time(dt)}';
  }

  /// Format time only: "14:30"
  static String time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Format short day name: "Sen", "Sel", etc.
  static String dayName(DateTime dt) {
    // DateTime.weekday: Mon=1 .. Sun=7
    return _days[dt.weekday - 1];
  }
}
