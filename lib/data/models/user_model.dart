/// User model for email-based authentication.
/// Stored locally in SQLite — enables offline login after initial registration.
class UserModel {
  final int? id;
  final String email;
  final String passwordHash;
  final String storeName;
  final String? storeAddress;
  final DateTime createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.storeName,
    this.storeAddress,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'password_hash': passwordHash,
      'store_name': storeName,
      'store_address': storeAddress,
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
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? storeName,
    String? storeAddress,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      storeName: storeName ?? this.storeName,
      storeAddress: storeAddress ?? this.storeAddress,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
