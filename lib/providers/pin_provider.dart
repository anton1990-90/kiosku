import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../shared/services/pin_service.dart';

/// Status kunci PIN aplikasi.
class PinState {
  /// Sedang membaca preferensi — layar splash ditahan selama ini.
  final bool isLoading;

  /// PIN sedang dipasang.
  final bool aktif;

  /// Aplikasi sedang terkunci dan menunggu PIN.
  final bool terkunci;

  /// Pesan kesalahan untuk ditampilkan di layar PIN.
  final String? error;

  const PinState({
    this.isLoading = true,
    this.aktif = false,
    this.terkunci = false,
    this.error,
  });

  /// Gerbang PIN hanya menahan kalau PIN memang dipasang DAN sedang terkunci.
  bool get perluDibuka => aktif && terkunci;

  PinState salin({
    bool? isLoading,
    bool? aktif,
    bool? terkunci,
    String? error,
    bool hapusError = false,
  }) {
    return PinState(
      isLoading: isLoading ?? this.isLoading,
      aktif: aktif ?? this.aktif,
      terkunci: terkunci ?? this.terkunci,
      error: hapusError ? null : (error ?? this.error),
    );
  }
}

/// Notifier kunci PIN.
///
/// Sengaja TIDAK memakai `autoDispose`: kalau provider ini dibuang lalu dibuat
/// ulang, `_init()` akan berjalan lagi dan mengunci aplikasi di tengah
/// pemakaian. Terkunci hanya boleh terjadi sekali, saat aplikasi dibuka.
class PinNotifier extends StateNotifier<PinState> {
  PinNotifier() : super(const PinState()) {
    _init();
  }

  /// Saat aplikasi dibuka: kalau PIN dipasang, langsung terkunci.
  ///
  /// Inilah yang membuat PIN ditanyakan **setiap kali aplikasi dibuka**,
  /// tanpa perlu memantau daur hidup aplikasi.
  Future<void> _init() async {
    final aktif = await PinService.instance.aktif;
    state = PinState(isLoading: false, aktif: aktif, terkunci: aktif);
  }

  /// Buka kunci dengan PIN. Mengembalikan true kalau PIN benar.
  Future<bool> buka(String pin) async {
    if (pin.isEmpty) {
      state = state.salin(error: 'Masukkan PIN Anda.');
      return false;
    }
    if (!await PinService.instance.cocok(pin)) {
      state = state.salin(error: 'PIN salah. Coba lagi.');
      return false;
    }
    state = const PinState(isLoading: false, aktif: true, terkunci: false);
    return true;
  }

  /// Pasang atau ganti PIN. Mengembalikan pesan kesalahan, atau null kalau
  /// berhasil. Setelah dipasang, aplikasi tidak ikut terkunci — pemiliknya
  /// baru saja membuktikan bahwa dia tahu PIN-nya.
  Future<String?> pasang(String pin) async {
    final masalah = PinService.periksa(pin);
    if (masalah != null) return masalah;
    await PinService.instance.pasang(pin);
    state = const PinState(isLoading: false, aktif: true, terkunci: false);
    return null;
  }

  /// Matikan kunci PIN.
  Future<void> matikan() async {
    await PinService.instance.matikan();
    state = const PinState(isLoading: false, aktif: false, terkunci: false);
  }

  /// Buka gerbang PIN setelah pengguna berhasil masuk dengan email & password.
  ///
  /// Ini jalan keluar kalau PIN lupa: password lebih kuat daripada PIN, jadi
  /// siapa pun yang tahu passwordnya memang berhak masuk. PIN-nya sendiri
  /// TIDAK dihapus — pemilik toko tinggal menggantinya di layar Profil.
  void bukaSetelahLogin() {
    if (!state.aktif) return;
    state = const PinState(isLoading: false, aktif: true, terkunci: false);
  }

  /// Kunci sekarang juga (dipakai tombol "Kunci" di layar profil).
  void kunciSekarang() {
    if (!state.aktif) return;
    state = const PinState(isLoading: false, aktif: true, terkunci: true);
  }

  /// Bersihkan pesan kesalahan saat pengguna mulai mengetik lagi.
  void bersihkanError() {
    if (state.error == null) return;
    state = state.salin(hapusError: true);
  }
}

final pinProvider = StateNotifierProvider<PinNotifier, PinState>((ref) {
  return PinNotifier();
});
