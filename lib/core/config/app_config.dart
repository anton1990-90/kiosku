/// Konfigurasi aplikasi TokoKu.
///
/// File ini berisi alamat server aktivasi lisensi dan pengaturan pembaruan.
/// Isi dua nilai Supabase di bawah sebelum aplikasi dijual.
class AppConfig {
  AppConfig._();

  /// URL project Supabase Anda, contoh: https://abcdefghijkl.supabase.co
  /// Ambil di Supabase > Project Settings > API > Project URL.
  static const String supabaseUrl = 'ISI_URL_SUPABASE_ANDA';

  /// Anon public key Supabase.
  /// Ambil di Supabase > Project Settings > API > Project API keys > anon public.
  /// Kunci ini memang aman ditanam di aplikasi (bukan kunci rahasia).
  static const String supabaseAnonKey = 'ISI_ANON_KEY_SUPABASE';

  /// Repo publik GitHub untuk cek pembaruan aplikasi.
  static const String githubRepo = 'anton1990-90/kiosku';

  /// Nomor WhatsApp penjual untuk kirim Kode Perangkat.
  /// Format internasional tanpa tanda plus, contoh: 6281234567890.
  /// Kosongkan ('') kalau tidak ingin tombol WhatsApp muncul.
  static const String sellerWhatsApp = '';

  /// Kunci untuk memeriksa keutuhan data lisensi yang tersimpan di HP.
  /// Ini hanya penghalang terhadap pengeditan biasa, bukan keamanan sungguhan.
  static const String licenseIntegrityKey =
      'tk_int_9f3a71c4e8b25d60a4f7c1e93b8d2a56';

  /// Apakah server aktivasi sudah diisi.
  static bool get isActivationConfigured =>
      !supabaseUrl.startsWith('ISI_') && !supabaseAnonKey.startsWith('ISI_');

  /// Link unduhan APK terbaru (selalu menunjuk rilis terakhir).
  static String get latestApkUrl =>
      'https://github.com/$githubRepo/releases/latest/download/app-release.apk';
}
