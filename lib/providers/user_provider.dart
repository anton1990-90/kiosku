import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_provider.dart';

/// State daftar akun — pemilik toko dan kasir.
class UserState {
  final List<UserModel> users;
  final bool isLoading;

  /// Jumlah pemilik yang masih aktif, dibaca dengan cara yang sama seperti
  /// penjagaan di repositori (`COUNT(*) ... WHERE role = 'owner' AND
  /// is_active = 1`). Sengaja TIDAK dihitung dari [users] di sini: dua cara
  /// menghitung angka yang sama cepat atau lambat akan berbeda, dan angka
  /// inilah yang memberi tahu pemilik toko apakah dia masih boleh
  /// menonaktifkan dirinya.
  final int pemilikAktif;

  /// Pesan kesalahan terakhir — misalnya penolakan "harus selalu ada satu
  /// pemilik aktif". Ditampilkan apa adanya di layar Pengguna, karena
  /// pesannya sudah ditulis untuk dibaca pemilik toko.
  final String? error;

  const UserState({
    this.users = const [],
    this.isLoading = false,
    this.pemilikAktif = 0,
    this.error,
  });

  UserState copyWith({
    List<UserModel>? users,
    bool? isLoading,
    int? pemilikAktif,
    String? error,
  }) {
    return UserState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      pemilikAktif: pemilikAktif ?? this.pemilikAktif,
      error: error,
    );
  }
}

/// Notifier akun — mengelola pemilik toko dan kasir.
///
/// Seluruh penjagaannya ada di [AuthRepository] (akun tidak pernah dihapus,
/// pemilik aktif terakhir tidak boleh diturunkan atau dinonaktifkan); notifier
/// ini hanya menyampaikan pesannya ke layar.
class UserNotifier extends StateNotifier<UserState> {
  final Ref _ref;
  final AuthRepository _repo = AuthRepository();

  UserNotifier(this._ref) : super(const UserState(isLoading: true)) {
    muat();
  }

  Future<void> muat() async {
    state = state.copyWith(isLoading: true, error: null);
    await _segarkan();
  }

  /// Membuat akun baru. Mengembalikan true kalau berhasil.
  Future<bool> tambah({
    required String email,
    required String password,
    required String role,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.createUser(
        email: email,
        password: password,
        role: role,
      );
      await _segarkan();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      return false;
    }
  }

  /// Mengubah peran sebuah akun. Menurunkan pemilik aktif terakhir ditolak.
  Future<bool> ubahPeran(int userId, String role) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.setUserRole(userId, role);
      await _segarkan();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      return false;
    }
  }

  /// Mengaktifkan atau menonaktifkan sebuah akun. Menonaktifkan pemilik aktif
  /// terakhir ditolak.
  Future<bool> ubahStatus(int userId, bool aktif) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.setUserActive(userId, aktif);
      await _segarkan();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      return false;
    }
  }

  /// Mengganti password akun lain.
  Future<bool> resetPassword(int userId, String passwordBaru) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repo.resetUserPassword(userId, passwordBaru);
      await _segarkan();
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _pesan(e));
      return false;
    }
  }

  void bersihkanError() {
    state = state.copyWith(error: null);
  }

  /// Memuat ulang daftar **dan** menyegarkan akun yang sedang login.
  ///
  /// Menyegarkan akun yang sedang login itu wajib, bukan hiasan: pemilik toko
  /// boleh menurunkan perannya sendiri selama masih ada pemilik lain. Kalau
  /// state auth tidak ikut diperbarui, dia masih tampak sebagai pemilik sampai
  /// aplikasi dibuka ulang — hak aksesnya hanya *terlihat* dicabut, dan rute
  /// yang seharusnya sudah tertutup masih bisa dibuka.
  Future<void> _segarkan() async {
    final daftar = await _repo.getUsers();
    final pemilik = await _repo.countActiveOwners();
    state = UserState(users: daftar, isLoading: false, pemilikAktif: pemilik);
    await _ref.read(authProvider.notifier).refreshUser();
  }

  /// Pesan dari repositori dipakai apa adanya, tanpa awalan "Exception: " —
  /// pesannya sudah ditulis dalam bahasa Indonesia untuk dibaca pemilik toko.
  String _pesan(Object e) => e.toString().replaceFirst('Exception: ', '');
}

final userProvider = StateNotifierProvider<UserNotifier, UserState>((ref) {
  return UserNotifier(ref);
});
