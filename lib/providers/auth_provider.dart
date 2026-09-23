import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'pin_provider.dart';

/// Auth state — tracks the current logged-in user.
class AuthState {
  final UserModel? user;

  /// Pembacaan status sesi saat aplikasi dibuka. Router menahan pengguna di
  /// splash selama ini bernilai true.
  ///
  /// Sengaja TIDAK dipakai untuk login/daftar yang sedang berjalan — lihat
  /// [sedangMasuk]. Kalau satu bendera dipakai untuk keduanya, router melempar
  /// pengguna keluar dari layar login ke splash di tengah proses; begitu
  /// kembali, gerbang PIN sudah menunggu dan PIN ditanyakan lagi tepat setelah
  /// pengguna mengetik password yang benar. `LicenseState` memakai pemisahan
  /// yang sama, dan karena alasan yang sama.
  final bool isLoading;

  /// Login atau pendaftaran sedang berjalan — tombolnya menampilkan spinner.
  final bool sedangMasuk;

  final String? error;
  final bool isFirstRun;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.sedangMasuk = false,
    this.error,
    this.isFirstRun = false,
  });

  bool get isAuthenticated => user != null;

  /// Akun yang sedang login adalah pemilik toko.
  ///
  /// Dipakai router untuk menolak rute yang bukan haknya, dan layar untuk
  /// menyembunyikan menu. Bawaannya `false`: selama identitasnya belum jelas,
  /// anggap bukan pemilik — arah yang aman untuk pemeriksaan hak akses.
  bool get isOwner => user?.isOwner ?? false;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? sedangMasuk,
    String? error,
    bool? isFirstRun,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      sedangMasuk: sedangMasuk ?? this.sedangMasuk,
      error: error,
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}

/// Auth notifier — handles registration, login, logout, and session restoration.
class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState(isLoading: true)) {
    _init();
  }

  /// Dipakai untuk membuka kunci PIN dari dalam alur login. Lihat [login].
  final Ref _ref;
  final AuthRepository _repo = AuthRepository();

  /// On startup: check if a user session exists and restore it.
  /// Also detect first-run (no registered users).
  Future<void> _init() async {
    var user = await _repo.getCurrentUser();

    // Sesi yang menunjuk akun nonaktif diputus di sini. Menonaktifkan kasir
    // harus benar-benar menghentikannya: tanpa pemeriksaan ini akun itu masih
    // bisa masuk lewat sesi lamanya sampai dia logout sendiri — yang tidak
    // akan pernah terjadi, karena tombol keluar pun ada di dalam aplikasi.
    if (user != null && !user.isActive) {
      await _repo.logout();
      user = null;
    }

    final hasUsers = await _repo.hasRegisteredUsers();
    state = AuthState(
      user: user,
      isLoading: false,
      isFirstRun: !hasUsers,
    );
  }

  /// Register a new account.
  Future<bool> register({
    required String email,
    required String password,
    required String storeName,
    String? storeAddress,
  }) async {
    state = state.copyWith(sedangMasuk: true, error: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        storeName: storeName,
        storeAddress: storeAddress,
      );
      // Akun dibuat memakai password, jadi kunci PIN (kalau ada dari pemasangan
      // sebelumnya) ikut dibuka — dan dibuka SEBELUM state auth berubah.
      // Alasannya sama seperti di [login].
      _ref.read(pinProvider.notifier).bukaSetelahLogin();
      state = AuthState(user: user, isFirstRun: false);
      return true;
    } catch (e) {
      state = state.copyWith(sedangMasuk: false, error: e.toString());
      return false;
    }
  }

  /// Login with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(sedangMasuk: true, error: null);
    try {
      final user = await _repo.login(email: email, password: password);

      // Password lebih kuat daripada PIN, jadi masuk dengan email & password
      // membuka kunci PIN — inilah jalan keluar kalau PIN lupa.
      //
      // WAJIB dipanggil SEBELUM state auth berubah. Kalau dipanggil sesudahnya
      // (dulu begitu, dari layar login), ada jendela waktu di mana
      // `isAuthenticated` sudah true tetapi `pinState.perluDibuka` masih true;
      // router melihat keadaan itu dan melempar pengguna ke /auth/pin — jadi
      // PIN ditanyakan lagi tepat setelah password yang benar diketik.
      //
      // Aman memanggil ini di sini: layar login tidak mungkin tampil selagi
      // `pinState.isLoading` true (router menahan di splash), jadi status PIN
      // sudah terbaca dan `aktif`-nya akurat.
      _ref.read(pinProvider.notifier).bukaSetelahLogin();

      state = AuthState(user: user, isFirstRun: false);
      return true;
    } catch (e) {
      state = state.copyWith(sedangMasuk: false, error: e.toString());
      return false;
    }
  }

  /// Ganti password tanpa login — dipakai alur "Lupa password".
  ///
  /// Pemanggil WAJIB sudah memverifikasi bukti kepemilikan (kode aktivasi)
  /// lebih dulu; metode ini sendiri tidak memeriksa apa pun.
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) {
    return _repo.resetPassword(email: email, newPassword: newPassword);
  }

  /// Logout and clear session.
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(isLoading: false);
  }

  /// Simpan perubahan info toko dari layar "Info toko".
  /// Mengembalikan true kalau berhasil.
  ///
  /// Field yang tidak dikirim (null) dipertahankan dari state sekarang, jadi
  /// mengganti logo tidak menghapus QRIS, dan sebaliknya.
  Future<bool> updateStore({
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
    String? qrisPath,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final userId = state.user?.id;
    if (userId == null) return false;

    try {
      final updated = await _repo.updateStore(
        userId: userId,
        storeName: storeName,
        storeAddress: storeAddress,
        storePhone: storePhone,
        logoPath: logoPath ?? state.user?.logoPath,
        qrisPath: qrisPath ?? state.user?.qrisPath,
        bankName: bankName ?? state.user?.bankName,
        bankAccountNumber: bankAccountNumber ?? state.user?.bankAccountNumber,
        bankAccountName: bankAccountName ?? state.user?.bankAccountName,
      );
      state = AuthState(
        user: updated,
        isLoading: false,
        isFirstRun: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Konfirmasi password akun yang sedang login — dipakai sebelum tindakan
  /// berbahaya seperti menghapus semua data.
  Future<bool> verifyPassword(String password) {
    return _repo.verifyCurrentPassword(password);
  }

  /// Hapus seluruh data usaha setelah password dikonfirmasi.
  /// Akun dan profil toko tidak ikut terhapus.
  ///
  /// Mengembalikan `false` juga kalau yang meminta bukan pemilik toko —
  /// penjagaannya ada di repositori, karena tindakan ini tidak punya rute
  /// sendiri yang bisa ditutup.
  Future<bool> resetAllData(String password) {
    return _repo.resetBusinessData(password);
  }

  /// Perbarui state setelah logo diganti, tanpa menulis ulang info toko.
  ///
  /// Kalau akun yang sedang login ternyata sudah dinonaktifkan (mungkin oleh
  /// dirinya sendiri, ketika masih ada pemilik lain), sesinya diputus di sini
  /// juga — bukan hanya saat aplikasi dibuka.
  Future<void> refreshUser() async {
    final user = await _repo.getCurrentUser();
    if (user == null) return;

    if (!user.isActive) {
      await _repo.logout();
      state = const AuthState(isLoading: false);
      return;
    }

    state = AuthState(user: user, isLoading: false, isFirstRun: false);
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
