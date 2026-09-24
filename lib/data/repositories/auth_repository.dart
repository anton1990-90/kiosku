import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../shared/services/pin_service.dart';
import '../database/database_helper.dart';
import '../models/user_model.dart';

/// Auth repository — handles email registration, login, and session.
/// All offline: passwords are SHA-256 hashed, session stored in SharedPreferences.
/// After initial registration, login works without internet.
///
/// Sejak v1.16.0 berkas ini juga mengelola **akun** — pemilik toko dan kasir.
/// Sejak v1.20.0 di sini juga tersimpan **PIN tiap akun** (`users.pin_hash`,
/// skema v12) sebagai jalan pintas masuk harian. Tiga aturan menentukan
/// bentuknya:
///
///   * **Akun tidak pernah dihapus.** `sales.user_id` menunjuk ke tabel
///     `users`, jadi nota lama harus tetap punya pemiliknya. Karena itu tidak
///     ada method `delete` di sini: kasir yang berhenti cukup dinonaktifkan
///     lewat [setUserActive], riwayatnya utuh, dan namanya masih terbaca di
///     laporan.
///   * **Toko tidak boleh kehilangan pemilik aktif terakhirnya.** Menurunkan
///     peran atau menonaktifkan pemilik aktif yang tersisa akan mengunci
///     pengelolaan akun untuk selamanya — hanya pemilik yang bisa membukanya.
///     Kedua tindakan itu ditolak lewat [_tolakKalauPemilikTerakhir].
///   * **Satu PIN hanya boleh menunjuk satu akun.** PIN dicari lewat cacah
///     SHA-256 tanpa garam (lihat [PinService.hashPin]), jadi dua akun yang
///     memasang PIN sama menghasilkan cacah yang sama — dan saat itu aplikasi
///     tidak lagi tahu siapa yang sedang masuk. Karena itu [pasangPin]
///     menolaknya, dan penolakan itu berlaku untuk SEMUA akun, termasuk yang
///     sedang nonaktif: kalau tidak, PIN yang "terpesan" akan menabrak begitu
///     akunnya diaktifkan kembali.
class AuthRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  static const _sessionKey = 'logged_in_user_id';

  /// Hash a password using SHA-256
  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ------------------------------------------------------------------ akun

  /// Apakah akun yang sedang login adalah pemilik toko yang masih aktif?
  ///
  /// Dipakai sebagai penjagaan di lapisan data untuk tindakan yang tidak punya
  /// rute sendiri (misalnya "Reset semua data", yang berupa dialog). Menutup
  /// rutenya tidak menolong di situ — yang bisa dijaga hanyalah datanya.
  Future<bool> _punyaHakPemilik() async {
    final user = await getCurrentUser();
    return user != null && user.isOwner && user.isActive;
  }

  /// Jumlah pemilik yang masih aktif.
  ///
  /// Angka ini yang menjaga toko tetap bisa dikelola. Dipakai penjaga di
  /// bawah, dan ditampilkan di layar Pengguna supaya pemilik toko melihat
  /// sendiri bahwa tidak ada lagi pemilik lain sebelum mencoba menonaktifkan
  /// dirinya.
  Future<int> countActiveOwners() async {
    final db = await _db.database;
    final jumlah = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM users WHERE role = ? AND is_active = 1',
      [UserRole.owner],
    ));
    return jumlah ?? 0;
  }

  /// Menolak tindakan yang membuat toko tidak punya pemilik aktif lagi.
  ///
  /// [aksi] hanya dipakai untuk menyusun pesan, misalnya
  /// "menonaktifkan akun ini".
  ///
  /// Penjagaan ini ada di lapisan data, bukan hanya di layar: layar Pengguna
  /// memang satu-satunya pemanggilnya hari ini, tetapi aturannya menyangkut
  /// keadaan data, bukan tampilan.
  Future<void> _tolakKalauPemilikTerakhir(
    int userId, {
    required String aksi,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['role', 'is_active'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final role = (rows.first['role'] as String?) ?? UserRole.owner;
    final aktif = ((rows.first['is_active'] as int?) ?? 1) == 1;

    // Yang dilindungi hanya pemilik yang masih aktif. Akun kasir — dan pemilik
    // yang sudah nonaktif — boleh diubah tanpa penjagaan apa pun.
    if (role != UserRole.owner || !aktif) return;

    if (await countActiveOwners() > 1) return;

    throw Exception(
      'Tidak bisa $aksi. Harus selalu ada satu pemilik aktif — '
      'angkat atau aktifkan pemilik lain lebih dulu.',
    );
  }

  /// Seluruh akun, dari yang paling lama.
  ///
  /// Mengembalikan [UserModel] utuh, termasuk `passwordHash`. Layar Pengguna
  /// tidak pernah menampilkan maupun menyalin kolom itu; yang dibutuhkan
  /// hanyalah id, email, peran, dan status aktifnya.
  Future<List<UserModel>> getUsers() async {
    final db = await _db.database;
    final rows = await db.query('users', orderBy: 'id ASC');
    return rows.map(UserModel.fromMap).toList();
  }

  /// Membuat akun baru untuk toko yang sedang dipakai.
  ///
  /// Profil toko (nama, alamat, telepon, logo, QRIS, rekening) **disalin dari
  /// akun yang sedang login**, bukan diketik ulang. Kasir bekerja di toko yang
  /// sama, jadi struk dan halaman profilnya harus menampilkan nama, logo, dan
  /// rekening yang sama; kalau dikosongkan, struk kasir tercetak tanpa nama
  /// toko.
  ///
  /// Bawaannya [UserRole.kasir]. Akun dengan hak penuh harus diminta dengan
  /// menyebut perannya — arah yang aman, karena salah menebak ke arah kasir
  /// hanya membatasi.
  Future<UserModel> createUser({
    required String email,
    required String password,
    String role = UserRole.kasir,
  }) async {
    final surel = email.trim().toLowerCase();
    if (surel.isEmpty) {
      throw Exception('Email wajib diisi.');
    }
    if (password.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }
    if (role != UserRole.owner && role != UserRole.kasir) {
      throw Exception('Peran akun tidak dikenal.');
    }

    final db = await _db.database;
    final ada = await db.query(
      'users',
      columns: ['id'],
      where: 'email = ?',
      whereArgs: [surel],
      limit: 1,
    );
    if (ada.isNotEmpty) {
      throw Exception('Email sudah terdaftar.');
    }

    final induk = await getCurrentUser();
    final user = UserModel(
      email: surel,
      passwordHash: _hashPassword(password),
      role: role,
      storeName: induk?.storeName ?? '',
      storeAddress: induk?.storeAddress,
      storePhone: induk?.storePhone,
      logoPath: induk?.logoPath,
      qrisPath: induk?.qrisPath,
      bankName: induk?.bankName,
      bankAccountNumber: induk?.bankAccountNumber,
      bankAccountName: induk?.bankAccountName,
      createdAt: DateTime.now(),
    );

    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  /// Mengubah peran sebuah akun.
  ///
  /// Menurunkan pemilik aktif terakhir menjadi kasir ditolak — sesudah itu
  /// tidak ada seorang pun yang bisa membuka pengelolaan akun.
  Future<void> setUserRole(int userId, String role) async {
    if (role != UserRole.owner && role != UserRole.kasir) {
      throw Exception('Peran akun tidak dikenal.');
    }
    if (role == UserRole.kasir) {
      await _tolakKalauPemilikTerakhir(
        userId,
        aksi: 'menurunkan peran akun ini menjadi kasir',
      );
    }

    final db = await _db.database;
    await db.update(
      'users',
      {'role': role},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Mengaktifkan atau menonaktifkan sebuah akun.
  ///
  /// Menonaktifkan pemilik aktif terakhir ditolak. Akun yang dinonaktifkan
  /// tidak bisa login lagi, tetapi barisnya tetap ada supaya riwayat
  /// penjualannya masih punya pemilik.
  Future<void> setUserActive(int userId, bool aktif) async {
    if (!aktif) {
      await _tolakKalauPemilikTerakhir(
        userId,
        aksi: 'menonaktifkan akun ini',
      );
    }

    final db = await _db.database;
    await db.update(
      'users',
      {'is_active': aktif ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Mengganti password akun lain dari layar Pengguna.
  ///
  /// Berbeda dengan [resetPassword], yang tidak memeriksa apa pun karena
  /// dipakai alur "Lupa password" — di sini pemanggilnya adalah layar yang
  /// hanya bisa dibuka pemilik toko.
  Future<bool> resetUserPassword(int userId, String newPassword) async {
    if (newPassword.length < 6) {
      throw Exception('Password minimal 6 karakter.');
    }

    final db = await _db.database;
    final terpengaruh = await db.update(
      'users',
      {'password_hash': _hashPassword(newPassword)},
      where: 'id = ?',
      whereArgs: [userId],
    );
    return terpengaruh > 0;
  }

  // ------------------------------------------------------------- PIN akun

  /// Apakah ada akun **aktif** yang sudah memasang PIN.
  ///
  /// Ini yang menentukan apakah layar PIN muncul saat aplikasi dibuka. Akun
  /// yang dinonaktifkan tidak dihitung: PIN-nya tidak bisa dipakai masuk, jadi
  /// mengunci aplikasi karenanya hanya membuat pemilik terkunci tanpa jalan
  /// masuk.
  Future<bool> adaAkunBerpin() async {
    final db = await _db.database;
    final jumlah = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM users '
      'WHERE is_active = 1 AND pin_hash IS NOT NULL AND pin_hash <> ?',
      [''],
    ));
    return (jumlah ?? 0) > 0;
  }

  /// Masuk dengan PIN akun, atau `null` kalau PIN-nya tidak cocok dengan akun
  /// aktif mana pun.
  ///
  /// Seperti [login], sesinya ikut disimpan: PIN menggantikan email & kata
  /// sandi, jadi seluruh akibat "masuk" harus sama persis.
  ///
  /// Hanya akun aktif yang dicari: akun yang dinonaktifkan tidak boleh bisa
  /// masuk lagi, termasuk lewat PIN. Karena [pasangPin] menolak PIN kembar,
  /// hasilnya paling banyak satu baris — tidak ada pilihan yang harus ditebak.
  Future<UserModel?> loginDenganPin(String pin) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      where: 'pin_hash = ? AND is_active = 1',
      whereArgs: [PinService.hashPin(pin)],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final user = UserModel.fromMap(rows.first);
    await _saveSession(user.id!);
    return user;
  }

  /// Apakah akun ini sudah punya PIN.
  Future<bool> punyaPin(int userId) async {
    final db = await _db.database;
    final rows = await db.query(
      'users',
      columns: ['pin_hash'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return false;
    final hash = rows.first['pin_hash'] as String?;
    return hash != null && hash.isNotEmpty;
  }

  /// Pasang atau ganti PIN sebuah akun.
  ///
  /// Menolak PIN yang sudah dipakai akun LAIN — aktif maupun tidak, dan itu
  /// disengaja. Kalau dua akun boleh berbagi PIN, [loginDenganPin] harus
  /// memilih salah satunya, dan pemilik toko bisa masuk sebagai kasir atau
  /// sebaliknya. Akun nonaktif ikut dihitung supaya tidak ada PIN yang
  /// "terpesan" lalu menabrak begitu akunnya diaktifkan kembali.
  Future<void> pasangPin(int userId, String pin) async {
    final masalah = PinService.periksa(pin);
    if (masalah != null) throw Exception(masalah);

    final hash = PinService.hashPin(pin);
    final db = await _db.database;

    final bentrok = await db.query(
      'users',
      columns: ['id'],
      where: 'pin_hash = ? AND id <> ?',
      whereArgs: [hash, userId],
      limit: 1,
    );
    if (bentrok.isNotEmpty) {
      throw Exception('PIN ini sudah dipakai akun lain. Pakai PIN lain.');
    }

    await db.update(
      'users',
      {'pin_hash': hash},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Hapus PIN sebuah akun.
  ///
  /// Akunnya tetap bisa masuk lewat email dan kata sandi — PIN hanya jalan
  /// pintas, bukan syarat masuk. Karena itu tidak ada penjagaan "harus selalu
  /// ada yang ber-PIN" di sini, berbeda dengan pemilik aktif terakhir.
  Future<void> hapusPin(int userId) async {
    final db = await _db.database;
    await db.update(
      'users',
      {'pin_hash': null},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// Pindahkan PIN perangkat versi lama (SharedPreferences) ke akun pemilik.
  ///
  /// Sebelum v1.20.0 hanya ada satu PIN untuk seluruh perangkat. Toko yang
  /// memperbarui aplikasi akan kehilangan jalan pintas hariannya kalau cacah
  /// itu tidak dipindahkan: PIN-nya masih tersimpan, tetapi tidak ada akun yang
  /// mengenalinya. Pemilik aktif yang paling lama dipilih karena dialah pemilik
  /// perangkat ini — akun pertama yang dibuat saat pemasangan.
  ///
  /// [hashLama] sudah berupa cacah SHA-256 dari skema lama, dan skema lama
  /// memakai rumus yang sama persis ([PinService.hashPin]), jadi cacahnya
  /// dipindahkan apa adanya — bukan dihitung ulang, karena PIN mentahnya memang
  /// tidak pernah disimpan.
  ///
  /// Mengembalikan `true` kalau benar-benar dipindahkan. Aman dipanggil
  /// berkali-kali: kalau sudah ada akun ber-PIN, atau belum ada pemilik aktif,
  /// tidak ada yang berubah.
  Future<bool> adopsiPinPerangkat(String hashLama) async {
    if (hashLama.isEmpty) return false;

    final db = await _db.database;

    // Sudah ada yang memakai PIN di database — jangan menimpa apa pun.
    final sudahAda = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM users WHERE pin_hash IS NOT NULL AND pin_hash <> ?',
      [''],
    ));
    if ((sudahAda ?? 0) > 0) return false;

    final pemilik = await db.query(
      'users',
      columns: ['id'],
      where: 'role = ? AND is_active = 1',
      whereArgs: [UserRole.owner],
      orderBy: 'id ASC',
      limit: 1,
    );
    if (pemilik.isEmpty) return false;

    await db.update(
      'users',
      {'pin_hash': hashLama},
      where: 'id = ?',
      whereArgs: [pemilik.first['id']],
    );
    return true;
  }

  // -------------------------------------------------------- daftar & masuk

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

    // Akun PERTAMA di HP ini adalah pemilik toko. Pendaftaran mandiri hanya
    // terjadi sekali, saat pemasangan baru, dan pemilik pertama itulah yang
    // berhak membuka pengelolaan akun.
    //
    // Akun berikutnya dibuat dari layar Pengguna. Kalau karena suatu hal layar
    // daftar tetap terbuka padahal sudah ada akun, akun baru itu dibuat
    // sebagai KASIR — arah yang aman: salah menebak ke arah kasir hanya
    // membatasi, sedangkan salah menebak ke arah pemilik memberi hak penuh
    // kepada orang yang baru saja mendaftar sendiri.
    final jumlahAkun = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM users'),
        ) ??
        0;

    final user = UserModel(
      email: email.toLowerCase(),
      passwordHash: _hashPassword(password),
      role: jumlahAkun == 0 ? UserRole.owner : UserRole.kasir,
      storeName: storeName,
      storeAddress: storeAddress,
      createdAt: DateTime.now(),
    );

    final id = await db.insert('users', user.toMap());
    return user.copyWith(id: id);
  }

  /// Login with email & password. Returns user if valid.
  ///
  /// Akun yang dinonaktifkan ditolak dengan pesan tersendiri, **bukan** dengan
  /// "Email atau password salah". Alasannya: pemilik toko harus bisa
  /// menjelaskan kepada kasirnya kenapa dia tidak bisa masuk. Karena itu
  /// `is_active` sengaja TIDAK ikut masuk ke klausa WHERE — kalau ikut, akun
  /// nonaktif akan tampak seperti password yang salah, dan pemilik toko akan
  /// mencari-cari password yang sebenarnya sudah benar.
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
    if (!user.isActive) {
      throw Exception(
        'Akun ini dinonaktifkan pemilik toko. Hubungi pemilik toko untuk '
        'mengaktifkannya kembali.',
      );
    }

    await _saveSession(user.id!);
    return user;
  }

  /// Save logged-in user ID to SharedPreferences for offline session.
  Future<void> _saveSession(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionKey, userId);
  }

  /// Get current logged-in user, or null if not logged in.
  ///
  /// Mengembalikan barisnya apa adanya, termasuk akun yang sudah
  /// dinonaktifkan — pemanggil yang memutuskan. Sesi yang menunjuk akun
  /// nonaktif diputus saat aplikasi dibuka, di `AuthNotifier._init`.
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

  /// Simpan perubahan info toko (nama, alamat, telepon, logo, QRIS, bank,
  /// ucapan penutup struk). Mengembalikan user yang sudah diperbarui.
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
    String? receiptFooter,
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
      // Peran dan status aktif BUKAN bagian dari info toko. Keduanya dibawa
      // apa adanya dari baris yang sekarang supaya nilai kembalian method ini
      // — yang langsung dipakai sebagai state auth — tidak diam-diam
      // mengangkat kasir menjadi pemilik.
      role: current?.role ?? UserRole.owner,
      isActive: current?.isActive ?? true,
      storeName: storeName,
      storeAddress: bersih(storeAddress),
      storePhone: bersih(storePhone),
      logoPath: logoPath,
      qrisPath: qrisPath,
      bankName: bersih(bankName),
      bankAccountNumber: bersih(bankAccountNumber),
      bankAccountName: bersih(bankAccountName),
      // Ucapan struk juga lewat `bersih()`: spasi saja dianggap "belum diatur",
      // bukan teks berisi spasi. Mengosongkan kolomnya mengembalikan teks
      // bawaan di struk, bukan mencetak baris kosong.
      receiptFooter: bersih(receiptFooter),
      // PIN juga bukan bagian dari info toko. Dibawa apa adanya dari baris yang
      // sekarang supaya nilai kembalian method ini — yang langsung dipakai
      // sebagai state auth — tidak membuat aplikasi mengira akunnya belum punya
      // PIN padahal sudah. `pin_hash` sendiri TIDAK ikut ditulis oleh
      // `db.update` di bawah: PIN hanya berubah lewat [pasangPin].
      pinHash: current?.pinHash,
      createdAt: current?.createdAt ?? DateTime.now(),
    );

    // Ditulis ke SEMUA akun, bukan hanya baris yang sedang login: profil toko
    // milik toko, bukan milik akun. Kalau hanya baris pemilik yang diperbarui,
    // kasir akan terus mencetak struk dengan nama toko, logo, dan rekening
    // yang sudah lama.
    await db.update('users', {
      'store_name': merged.storeName,
      'store_address': merged.storeAddress,
      'store_phone': merged.storePhone,
      'logo_path': merged.logoPath,
      'qris_path': merged.qrisPath,
      'bank_name': merged.bankName,
      'bank_account_number': merged.bankAccountNumber,
      'bank_account_name': merged.bankAccountName,
      'receipt_footer': merged.receiptFooter,
    });

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
  /// Mengembalikan `false` kalau password salah **atau** yang meminta bukan
  /// pemilik toko. Penjagaan peran ada di sini, bukan hanya di tampilan:
  /// tindakan ini tidak punya rute sendiri — ia sebuah dialog — sehingga
  /// menutup rute tidak menjaga apa pun. Tindakan ini juga yang paling mahal
  /// kalau salah: seluruh riwayat penjualan hilang dan tidak bisa dikembalikan
  /// dari dalam aplikasi.
  Future<bool> resetBusinessData(String password) async {
    if (!await _punyaHakPemilik()) return false;
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
      {'password_hash': _hashPassword(newPassword)},
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
