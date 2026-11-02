import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/scanner_settings_model.dart';
import '../shared/services/barcode_wedge.dart';
import '../shared/services/scanner_settings_service.dart';

/// Pengaturan pemindai yang sedang dipakai halaman Pengaturan Pemindai.
///
/// Setiap perubahan langsung disimpan **dan** langsung diteruskan ke penerima
/// scanner. Dua hal itu tidak bisa dipisah: halaman ini dipakai sambil
/// mencoba-coba (geser jeda, pindai ulang, lihat hasilnya), dan pengaturan yang
/// sudah terlihat di layar tetapi belum berlaku di penerima akan membuat
/// percobaan berikutnya menguji nilai yang salah.
class ScannerSettingsNotifier extends StateNotifier<ScannerSettings> {
  ScannerSettingsNotifier() : super(const ScannerSettings()) {
    _pemuatan = ScannerSettingsService.instance.muat();
    _terapkan();
  }

  /// Pemuatan pertama. Disimpan supaya [siap] tidak memuat ulang dan menimpa
  /// perubahan yang dibuat sementara pemuatan pertama masih berjalan.
  late final Future<ScannerSettings> _pemuatan;

  Future<void> _terapkan() async {
    final tersimpan = await _pemuatan;
    if (!mounted) return;
    state = tersimpan;
    BarcodeWedgeScanner.instance.atur(tersimpan);
  }

  /// Tunggu pemuatan pertama selesai.
  ///
  /// Dipakai halaman pengaturan sebelum menampilkan nilai, supaya yang terlihat
  /// bukan nilai bawaan yang sekejap kemudian berubah.
  Future<void> siap() => _terapkan();

  Future<void> ubah(ScannerSettings baru) async {
    state = baru;
    BarcodeWedgeScanner.instance.atur(baru);
    await ScannerSettingsService.instance.simpan(baru);
  }

  /// Perbarui nilai yang sedang dipakai **tanpa** menyimpan.
  ///
  /// Dipakai slider saat masih digeser. Slider mengirim puluhan nilai per
  /// detik, dan menyimpan semuanya berarti ratusan penulisan ke penyimpanan
  /// untuk satu gerakan jari — cukup untuk membuat geserannya tersendat di HP
  /// murah. Nilai tetap berlaku seketika (penerima scanner ikut diperbarui),
  /// lalu disimpan sekali saat jari dilepas lewat [ubah].
  void ubahSementara(ScannerSettings baru) {
    state = baru;
    BarcodeWedgeScanner.instance.atur(baru);
  }

  /// Buang kumpulan karakter yang sedang berjalan.
  ///
  /// Dipakai tombol "Bersihkan" di halaman uji: setelah mengubah jeda atau
  /// penanda akhir, sisa karakter dari percobaan sebelumnya bisa terbawa ke
  /// percobaan berikutnya dan membuat hasilnya membingungkan.
  void bersihkan() => BarcodeWedgeScanner.instance.bersihkan();
}

final scannerSettingsProvider =
    StateNotifierProvider<ScannerSettingsNotifier, ScannerSettings>(
  (ref) => ScannerSettingsNotifier(),
);
