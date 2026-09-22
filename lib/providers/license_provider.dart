import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/license_model.dart';
import '../data/repositories/license_repository.dart';

/// Status lisensi aplikasi.
///
/// [isLoading] hanya untuk pembacaan awal dari perangkat, bukan proses aktivasi.
/// Proses aktivasi dikelola di dalam layar aktivasi supaya router tidak
/// ter-redirect ke splash saat tombol Aktivasi ditekan.
class LicenseState {
  final bool isLoading;
  final bool isLicensed;
  final LicenseModel? license;

  const LicenseState({
    this.isLoading = true,
    this.isLicensed = false,
    this.license,
  });
}

/// Mengelola pembacaan dan aktivasi lisensi.
class LicenseNotifier extends StateNotifier<LicenseState> {
  final LicenseRepository _repo = LicenseRepository();

  LicenseNotifier() : super(const LicenseState()) {
    _init();
  }

  Future<void> _init() async {
    final local = await _repo.loadLocal();
    state = LicenseState(
      isLoading: false,
      isLicensed: local != null,
      license: local,
    );
  }

  /// Aktifkan lisensi dengan [code].
  /// Mengembalikan pesan kesalahan, atau `null` kalau berhasil.
  Future<String?> activate(String code) async {
    try {
      final license = await _repo.activate(code: code);
      await _repo.saveLocal(license);
      state = LicenseState(
        isLoading: false,
        isLicensed: true,
        license: license,
      );
      return null;
    } on LicenseException catch (e) {
      return e.message;
    } catch (e) {
      return 'Aktivasi gagal: $e';
    }
  }

  /// Muat ulang status dari perangkat (mis. setelah data dibersihkan).
  Future<void> refresh() async {
    state = const LicenseState();
    await _init();
  }
}

final licenseProvider =
    StateNotifierProvider<LicenseNotifier, LicenseState>((ref) {
  return LicenseNotifier();
});
