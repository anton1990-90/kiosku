import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/scanner_settings_model.dart';

/// Menyimpan & membaca [ScannerSettings] dari SharedPreferences.
///
/// Dipakai dua tempat: halaman Pengaturan Pemindai (lewat provider) dan
/// `main()` saat aplikasi dibuka. Jalur kedua sengaja membaca langsung dari
/// sini, bukan dari provider, karena penerima scanner dipasang **sebelum**
/// pohon widget ada — kalau menunggu provider, ketikan yang datang di detik
/// pertama tidak akan terbaca.
class ScannerSettingsService {
  ScannerSettingsService._();
  static final ScannerSettingsService instance = ScannerSettingsService._();

  static const String _kAktif = 'pindai_aktif';
  static const String _kJenis = 'pindai_jenis';
  static const String _kJeda = 'pindai_jeda_karakter';
  static const String _kAkhiran = 'pindai_akhiran';
  static const String _kMin = 'pindai_panjang_min';
  static const String _kMaks = 'pindai_panjang_maks';
  static const String _kAwalan = 'pindai_buang_awalan';
  static const String _kAkhiranBuang = 'pindai_buang_akhiran';
  static const String _kGetar = 'pindai_getar';
  static const String _kBunyi = 'pindai_bunyi';

  /// Batas nilai yang masuk akal. Nilai di luar ini dijepit, bukan ditolak:
  /// berkas preferensi yang rusak tidak boleh membuat scanner mati total.
  static const int jedaMin = 30;
  static const int jedaMaks = 500;
  static const int panjangMinBawah = 1;
  static const int panjangMinAtas = 24;
  static const int panjangMaksBawah = 16;
  static const int panjangMaksAtas = 512;

  static int _jepit(int nilai, int bawah, int atas) {
    if (nilai < bawah) return bawah;
    if (nilai > atas) return atas;
    return nilai;
  }

  Future<ScannerSettings> muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Panjang minimum tidak boleh melebihi maksimum — kalau itu terjadi,
      // tidak ada satu pun kode yang lolos dan gejalanya persis "scanner tidak
      // berfungsi", tanpa pesan apa pun.
      final min = _jepit(
        prefs.getInt(_kMin) ?? 4,
        panjangMinBawah,
        panjangMinAtas,
      );
      final maks = _jepit(
        prefs.getInt(_kMaks) ?? 256,
        panjangMaksBawah,
        panjangMaksAtas,
      );

      return ScannerSettings(
        aktif: prefs.getBool(_kAktif) ?? true,
        jenis: JenisPemindai.dariKode(prefs.getString(_kJenis)),
        jedaAntarKarakter: _jepit(
          prefs.getInt(_kJeda) ?? 120,
          jedaMin,
          jedaMaks,
        ),
        akhiran: AkhiranPindai.dariKode(prefs.getString(_kAkhiran)),
        panjangMinimum: min > maks ? maks : min,
        panjangMaksimum: maks,
        awalanBuang: prefs.getString(_kAwalan) ?? '',
        akhiranBuang: prefs.getString(_kAkhiranBuang) ?? '',
        getar: prefs.getBool(_kGetar) ?? true,
        bunyi: prefs.getBool(_kBunyi) ?? false,
      );
    } catch (_) {
      // Penyimpanan tidak terbaca: scanner tetap harus bisa dipakai, jadi
      // pakai pengaturan bawaan alih-alih mematikannya.
      return const ScannerSettings();
    }
  }

  Future<void> simpan(ScannerSettings pengaturan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAktif, pengaturan.aktif);
      await prefs.setString(_kJenis, pengaturan.jenis.kode);
      await prefs.setInt(_kJeda, pengaturan.jedaAntarKarakter);
      await prefs.setString(_kAkhiran, pengaturan.akhiran.kode);
      await prefs.setInt(_kMin, pengaturan.panjangMinimum);
      await prefs.setInt(_kMaks, pengaturan.panjangMaksimum);
      await prefs.setString(_kAwalan, pengaturan.awalanBuang);
      await prefs.setString(_kAkhiranBuang, pengaturan.akhiranBuang);
      await prefs.setBool(_kGetar, pengaturan.getar);
      await prefs.setBool(_kBunyi, pengaturan.bunyi);
    } catch (_) {
      // Gagal menyimpan bukan alasan mematikan scanner.
    }
  }
}
