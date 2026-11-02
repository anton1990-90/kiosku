import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/print_settings_model.dart';
import '../shared/services/print_settings_service.dart';

/// Pengaturan cetak yang sedang dipakai layar pengaturan.
///
/// Nilainya dimuat sekali saat pertama dibaca, lalu setiap perubahan langsung
/// disimpan — tidak ada tombol "Simpan". Alasannya praktis: pengaturan cetak
/// diubah sambil mencoba-coba (ganti ukuran kertas, cetak contoh, lihat
/// hasilnya), dan pengaturan yang lupa disimpan setelah percobaan yang
/// berhasil adalah cara paling mudah membuat hasil cetak berikutnya berbeda.
class PrintSettingsNotifier extends StateNotifier<PrintSettings> {
  PrintSettingsNotifier() : super(const PrintSettings()) {
    _pemuatan = PrintSettingsService.instance.muat();
    _terapkan();
  }

  /// Pemuatan pertama. Disimpan supaya [siap] tidak memuat ulang dan menimpa
  /// perubahan yang dibuat sementara pemuatan pertama masih berjalan.
  late final Future<PrintSettings> _pemuatan;

  Future<void> _terapkan() async {
    final tersimpan = await _pemuatan;
    if (!mounted) return;
    state = tersimpan;
  }

  /// Tunggu pemuatan pertama selesai.
  ///
  /// Dipakai layar pengaturan sebelum menampilkan nilai, supaya yang terlihat
  /// bukan nilai bawaan yang sekejap kemudian berubah.
  Future<void> siap() => _terapkan();

  Future<void> ubah(PrintSettings baru) async {
    state = baru;
    await PrintSettingsService.instance.simpan(baru);
  }

  /// Baca ulang dari penyimpanan.
  ///
  /// Dipakai setelah mencetak contoh struk: printer yang barusan dipakai
  /// dicatat oleh layanan cetak, dan nama itu harus langsung terlihat di layar
  /// tanpa menunggu aplikasi dibuka ulang.
  Future<void> muatUlang() async {
    final tersimpan = await PrintSettingsService.instance.muat();
    if (!mounted) return;
    state = tersimpan;
  }

  Future<void> lupakanPrinter() async {
    await PrintSettingsService.instance.lupakanPrinter();
    if (!mounted) return;
    state = state.tanpaPrinter();
  }
}

final printSettingsProvider =
    StateNotifierProvider<PrintSettingsNotifier, PrintSettings>(
  (ref) => PrintSettingsNotifier(),
);
