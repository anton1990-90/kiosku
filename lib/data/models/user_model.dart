/// User model for email-based authentication.
/// Stored locally in SQLite — enables offline login after initial registration.
/// Juga menyimpan info toko yang bisa diedit pengguna (nama, alamat, telepon,
/// dan path logo usaha di penyimpanan aplikasi).
class UserModel {
  final int? id;
  final String email;
  final String passwordHash;
  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? logoPath;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    this.logoPath,
    required this.createdAt,
  });

  /// Dua huruf pertama nama toko — dipakai kalau logo belum dipasang.
  String get initials {
    final trimmed = storeName.trim();
    if (trimmed.isEmpty) return 'TS';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return trimmed.length >= 2
          ? trimmed.substring(0, 2).toUpperCase()
          : trimmed.toUpperCase();
    }
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  bool get hasLogo => logoPath != null && logoPath!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'password_hash': passwordHash,
      'store_name': storeName,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'logo_path': logoPath,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      storeName: map['store_name'] as String,
      storeAddress: map['store_address'] as String?,
      storePhone: map['store_phone'] as String?,
      logoPath: map['logo_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
    DateTime? createdAt,
    bool clearAddress = false,
    bool clearPhone = false,
    bool clearLogo = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      storeName: storeName ?? this.storeName,
      storeAddress: clearAddress ? null : (storeAddress ?? this.storeAddress),
      storePhone: clearPhone ? null : (storePhone ?? this.storePhone),
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
