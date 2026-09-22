import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';

/// Auth state — tracks the current logged-in user.
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isFirstRun;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isFirstRun = false,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isFirstRun,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isFirstRun: isFirstRun ?? this.isFirstRun,
    );
  }
}

/// Auth notifier — handles registration, login, logout, and session restoration.
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo = AuthRepository();

  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  /// On startup: check if a user session exists and restore it.
  /// Also detect first-run (no registered users).
  Future<void> _init() async {
    final user = await _repo.getCurrentUser();
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
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.register(
        email: email,
        password: password,
        storeName: storeName,
        storeAddress: storeAddress,
      );
      state = AuthState(user: user, isLoading: false, isFirstRun: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Login with email and password.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = await _repo.login(email: email, password: password);
      state = AuthState(user: user, isLoading: false, isFirstRun: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Logout and clear session.
  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(isLoading: false);
  }

  /// Simpan perubahan info toko dari layar "Info toko".
  /// Mengembalikan true kalau berhasil.
  Future<bool> updateStore({
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
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

  /// Perbarui state setelah logo diganti, tanpa menulis ulang info toko.
  Future<void> refreshUser() async {
    final user = await _repo.getCurrentUser();
    if (user == null) return;
    state = AuthState(user: user, isLoading: false, isFirstRun: false);
  }

  /// Clear error message.
  void clearError() {
    state = state.copyWith();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
