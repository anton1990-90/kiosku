import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';

/// Auth repository — handles email registration, login, and session.
/// All offline: passwords are SHA-256 hashed, session stored in SharedPreferences.
/// After initial registration, login works without internet.
class AuthRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _sessionKey = 'logged_in_user_id';

  /// Hash a password using SHA-256
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  /// Register a new user with email & password.
  /// Returns the created user, or throws if email already exists.
  Future<UserModel> register({
    required String email,
    required String password,
    required String storeName,
    String? storeAddress,
  }) async {
    final db = await _db.database;

    // Check if email already exists
    final existing = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      throw Exception('Email sudah terdaftar. Silakan login.');
    }

    final user = UserModel(
      email: email.toLowerCase(),
      passwordHash: _hashPassword(password),
      storeName: storeName,
      storeAddress: storeAddress,
      createdAt: DateTime.now(),
    );

    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  /// Login with email & password. Returns user if valid.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final db = await _db.database;
    final hash = _hashPassword(password);

    final results = await db.query(
      'users',
      where: 'email = ? AND password_hash = ?',
      whereArgs: [email.toLowerCase(), hash],
      limit: 1,
    );

    if (results.isEmpty) {
      throw Exception('Email atau password salah.');
    }

    final user = UserModel.fromMap(results.first);
    await _saveSession(user.id!);
    return user;
  }

  /// Save logged-in user ID to SharedPreferences for offline session.
  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, userId);
  }

  /// Get current logged-in user, or null if not logged in.
  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_sessionKey);
    if (userId == null) return null;

    final db = await _db.database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return UserModel.fromMap(results.first);
  }

  /// Simpan perubahan info toko (nama, alamat, telepon, logo, QRIS, bank).
  /// Mengembalikan user yang sudah diperbarui.
  Future<UserModel> updateStore({
    required int userId,
    required String storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
    String? qrisPath,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
  }) async {
    final db = await _db.database;

    final current = await getCurrentUser();

    /// Kolom teks opsional: spasi saja dianggap kosong supaya tidak
    /// tersimpan sebagai string berisi spasi.
    String? bersih(String? value) {
      final trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final merged = UserModel(
      id: userId,
      email: current?.email ?? '',
      passwordHash: current?.passwordHash ?? '',
      storeName: storeName,
      storeAddress: bersih(storeAddress),
      storePhone: bersih(storePhone),
      logoPath: logoPath,
      qrisPath: qrisPath,
      bankName: bersih(bankName),
      bankAccountNumber: bersih(bankAccountNumber),
      bankAccountName: bersih(bankAccountName),
      createdAt: current?.createdAt ?? DateTime.now(),
    );

    await db.update(
      'users',
      {
        'store_name': merged.storeName,
        'store_address': merged.storeAddress,
        'store_phone': merged.storePhone,
        'logo_path': merged.logoPath,
        'qris_path': merged.qrisPath,
        'bank_name': merged.bankName,
        'bank_account_number': merged.bankAccountNumber,
        'bank_account_name': merged.bankAccountName,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    return merged;
  }

  /// Cocokkan password yang diketik pengguna dengan akun yang sedang login.
  ///
  /// Dipakai sebagai konfirmasi sebelum tindakan berbahaya seperti "Reset
  /// semua data". Password tidak pernah disimpan mentah — yang dibandingkan
  /// adalah hash SHA-256, sama seperti saat login.
  Future<bool> verifyCurrentPassword(String password) async {
    if (password.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_sessionKey);
    if (userId == null) return false;

    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['password_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    return rows.first['password_hash'] == _hashPassword(password);
  }

  /// Hapus seluruh data usaha setelah password dikonfirmasi.
  ///
  /// Mengembalikan `false` kalau password salah, supaya pemanggil bisa
  /// menampilkan pesan dan tidak ada data yang terhapus.
  Future<bool> resetBusinessData(String password) async {
    if (!await verifyCurrentPassword(password)) return false;
    await _db.resetBusinessData();
    return true;
  }

  /// Ganti password seorang pengguna tanpa login.
  ///
  /// Dipakai alur "Lupa password", di mana pemilik sudah membuktikan
  /// kepemilikannya lewat kode aktivasi. Metode ini sendiri tidak memeriksa
  /// bukti apa pun — pemanggil yang wajib melakukannya lebih dulu.
  ///
  /// Mengembalikan false kalau emailnya tidak terdaftar.
  Future<bool> resetPassword({
    required String email,
    required String newPassword,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return false;

    final terpengaruh = await db.update(
      'users',
      {'password_hash': newPassword},
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
    return terpengaruh > 0;
  }

  /// Simpan hanya path logo (dipakai setelah memilih gambar dari galeri).
  Future<void> updateLogoPath(int userId, String? logoPath) async {
    final db = await _db.database;
    await db.update(
      'users',
      {'logo_path': logoPath},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Logout — clears the session.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }

  /// Check if any user is registered (for first-run detection).
  Future<bool> hasRegisteredUsers() async {
    final db = await _db.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM users'),
    );
    return (count ?? 0) > 0;
  }
}
