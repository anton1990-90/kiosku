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
