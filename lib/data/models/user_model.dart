/// Peran akun.
///   owner — pemilik toko: melihat semuanya, termasuk laba, laporan keuangan,
///           pengaturan, cadangan data, dan pengelolaan pengguna.
///   kasir — melayani penjualan dan mencatat uang, tanpa melihat laba,
///           laporan keuangan, maupun pengaturan toko.
///
/// Nilainya disimpan sebagai teks di `users.role`, dan nilai awalnya `'owner'`
/// (lihat `DatabaseHelper._upgradeV9`). Akun yang sudah ada sebelum fitur ini
/// adalah pemilik toko; menebaknya sebagai kasir akan mengunci pemiliknya
/// sendiri dari pengaturan, tanpa pemilik tersisa yang bisa memperbaikinya.
class UserRole {
  static const owner = 'owner';
  static const kasir = 'kasir';
}

/// User model for email-based authentication.
/// Stored locally in SQLite — enables offline login after initial registration.
/// Juga menyimpan info toko yang bisa diedit pengguna (nama, alamat, telepon,
/// logo usaha, gambar QRIS, dan rekening bank untuk pembayaran non-tunai).
class UserModel {
  final int? id;
  final String email;
  final String passwordHash;

  /// Peran akun — [UserRole.owner] atau [UserRole.kasir].
  final String role;

  /// Akun yang dinonaktifkan tidak bisa login lagi, tetapi seluruh riwayatnya
  /// tetap ada. Akun **tidak pernah dihapus**: `sales.user_id` menunjuk ke
  /// sini, dan nota lama harus tetap punya pemiliknya.
  final bool isActive;

  final String storeName;
  final String? storeAddress;
  final String? storePhone;
  final String? logoPath;

  /// Gambar QRIS milik toko (path di penyimpanan aplikasi).
  final String? qrisPath;

  /// Rekening bank tujuan transfer — nama bank, nomor, dan atas nama.
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;

  /// Ucapan penutup yang dicetak di bawah struk — menggantikan teks tetap
  /// "Terima kasih atas kunjungan Anda!".
  ///
  /// `null` berarti pemilik belum pernah mengubahnya, dan layar cetak memakai
  /// teks bawaan itu. String kosong diperlakukan sama: `updateStore` membuang
  /// spasi dan mengubahnya menjadi `null`, supaya tidak ada struk yang
  /// mencetak satu baris kosong tanpa alasan yang jelas.
  final String? receiptFooter;

  final DateTime createdAt;

  UserModel({
    this.id,
    required this.email,
    required this.passwordHash,
    this.role = UserRole.owner,
    this.isActive = true,
    required this.storeName,
    this.storeAddress,
    this.storePhone,
    this.logoPath,
    this.qrisPath,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.receiptFooter,
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

  /// Pemilik toko melihat dan mengubah segalanya.
  bool get isOwner => role == UserRole.owner;

  /// Peran ini untuk ditampilkan di layar.
  String get roleLabel => isOwner ? 'Pemilik' : 'Kasir';

  bool get hasLogo => logoPath != null && logoPath!.isNotEmpty;

  bool get hasQris => qrisPath != null && qrisPath!.isNotEmpty;

  /// Rekening dianggap lengkap kalau nomornya sudah diisi. Nama bank dan
  /// atas nama boleh kosong supaya pemilik toko tidak dipaksa mengisi.
  bool get hasBankAccount =>
      bankAccountNumber != null && bankAccountNumber!.trim().isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'email': email,
      'password_hash': passwordHash,
      'role': role,
      // SQLite tidak punya tipe boolean — disimpan sebagai 1 / 0.
      'is_active': isActive ? 1 : 0,
      'store_name': storeName,
      'store_address': storeAddress,
      'store_phone': storePhone,
      'logo_path': logoPath,
      'qris_path': qrisPath,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
      'receipt_footer': receiptFooter,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      email: map['email'] as String,
      passwordHash: map['password_hash'] as String,
      // Baris lama dan berkas cadangan lama belum punya kolom ini. Nilai
      // bawaannya sama dengan nilai awal kolomnya, dan alasannya sama:
      // akun yang sudah ada sebelum fitur ini adalah pemilik toko.
      role: (map['role'] as String?) ?? UserRole.owner,
      isActive: ((map['is_active'] as int?) ?? 1) == 1,
      storeName: map['store_name'] as String,
      storeAddress: map['store_address'] as String?,
      storePhone: map['store_phone'] as String?,
      logoPath: map['logo_path'] as String?,
      qrisPath: map['qris_path'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      bankAccountName: map['bank_account_name'] as String?,
      // Baris lama dan berkas cadangan lama belum punya kolom ini. NULL di
      // sini berarti "pakai teks bawaan", bukan "kosong".
      receiptFooter: map['receipt_footer'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  UserModel copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? role,
    bool? isActive,
    String? storeName,
    String? storeAddress,
    String? storePhone,
    String? logoPath,
    String? qrisPath,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    String? receiptFooter,
    DateTime? createdAt,
    bool clearAddress = false,
    bool clearPhone = false,
    bool clearLogo = false,
    bool clearQris = false,
    bool clearBank = false,
    // `copyWith(receiptFooter: null)` berarti "pertahankan yang lama", bukan
    // "kosongkan". Tanpa bendera ini, mengosongkan ucapan struk lewat copyWith
    // akan diam-diam tidak berpengaruh — persis jebakan yang sama dengan
    // `clearBank` di atasnya.
    bool clearReceiptFooter = false,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      storeName: storeName ?? this.storeName,
      storeAddress: clearAddress ? null : (storeAddress ?? this.storeAddress),
      storePhone: clearPhone ? null : (storePhone ?? this.storePhone),
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      qrisPath: clearQris ? null : (qrisPath ?? this.qrisPath),
      bankName: clearBank ? null : (bankName ?? this.bankName),
      bankAccountNumber:
          clearBank ? null : (bankAccountNumber ?? this.bankAccountNumber),
      bankAccountName:
          clearBank ? null : (bankAccountName ?? this.bankAccountName),
      receiptFooter:
          clearReceiptFooter ? null : (receiptFooter ?? this.receiptFooter),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
