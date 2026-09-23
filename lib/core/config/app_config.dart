/// Konfigurasi aplikasi TokoKu.
///
/// Isi [activationServerUrl] dengan alamat Cloudflare Worker Anda sebelum
/// aplikasi dijual. Cara memasangnya ada di `cloudflare/README.md`.
///
/// Catatan penting: karena nilai di bawah memakai `static const`, mengisi
/// alamat server saja sudah cukup untuk menyalakan gerbang lisensi — tidak
/// perlu mengubah kode lain.
class AppConfig {
  AppConfig._();

  /// Alamat server aktivasi (Cloudflare Worker).
  ///
  /// Contoh: https://tokoku-lisensi.nama-anda.workers.dev
  /// Jangan diakhiri garis miring.
  static const String activationServerUrl =
      'https://tokoku-lisensi.dompetkuai.workers.dev';

  /// Halaman portal aktivasi untuk pelanggan.
  ///
  /// Worker yang sama juga menyajikan halaman portalnya, jadi alamatnya
  /// biasanya sama dengan [activationServerUrl]. Isi [_portalUrlKhusus]
  /// hanya kalau portalnya ditaruh di alamat lain.
  static const String _portalUrlKhusus = '';

  static String get portalUrl =>
      _portalUrlKhusus.isEmpty ? activationServerUrl : _portalUrlKhusus;

  /// Nomor WhatsApp penjual untuk bantuan aktivasi.
  /// Format internasional tanpa tanda plus, contoh: 6281234567890.
  /// Kosongkan ('') kalau tidak ingin tombol WhatsApp muncul.
  static const String sellerWhatsApp = '';

  /// Kunci untuk memeriksa keutuhan data lisensi yang tersimpan di HP.
  /// Ini hanya penghalang terhadap pengeditan biasa, bukan keamanan sungguhan.
  static const String licenseIntegrityKey =
      'tk_int_9f3a71c4e8b25d60a4f7c1e93b8d2a56';

  /// Apakah server aktivasi sudah diisi.
  static bool get isActivationConfigured =>
      !activationServerUrl.startsWith('ISI_') &&
      activationServerUrl.startsWith('http');

  /// Halaman unduh aplikasi yang bisa dibagikan ke pelanggan.
  static String get downloadPageUrl => '$activationServerUrl/unduh';

  /// Alamat pemeriksaan versi terbaru.
  static String get versionCheckUrl => '$activationServerUrl/api/versi';

  /// Link unduhan APK terbaru.
  ///
  /// Sengaja menunjuk ke server aktivasi sendiri, BUKAN ke GitHub. Server itu
  /// yang mengambilkan file APK-nya dari rilis, jadi pelanggan tidak pernah
  /// tahu — dan tidak bisa mencari — akun GitHub penjual.
  static String get latestApkUrl =>
      isActivationConfigured ? '$activationServerUrl/unduh/apk' : '';
}
