import 'dart:convert';
import 'dart:io';

import 'package:sqflite/sqflite.dart';

import '../../data/database/database_helper.dart';
import '../../data/models/user_model.dart';
import 'backup_service.dart';

/// Ringkasan isi berkas cadangan, ditampilkan ke pengguna **sebelum** menekan
/// "Pulihkan" — supaya dia tahu berkas mana yang akan ditanam.
class RingkasanCadangan {
  final String dibuat;
  final String namaToko;
  final Map<String, int> jumlah;

  const RingkasanCadangan({
    required this.dibuat,
    required this.namaToko,
    required this.jumlah,
  });

  int get totalBaris => jumlah.values.fold(0, (a, b) => a + b);
}

/// Hasil pemulihan.
class HasilPulih {
  final int totalBaris;
  final Map<String, int> jumlah;

  const HasilPulih({required this.totalBaris, required this.jumlah});
}

/// Membaca kembali berkas cadangan JSON dan menanamnya ke database.
///
/// Dua hal yang membuat ini aman:
///
/// 1. **Seluruh proses berjalan dalam SATU transaksi.** Kalau ada satu baris
///    yang gagal ditanam, semuanya dibatalkan dan data lama tetap utuh. Ini
///    fitur yang paling tidak boleh gagal setengah jalan.
/// 2. **Berkas diperiksa dulu** sebelum apa pun diubah, dan berkas yang bukan
///    cadangan TokoKu ditolak dengan pesan yang jelas.
class RestoreService {
  RestoreService._();
  static final RestoreService instance = RestoreService._();

  /// Baca dan periksa berkas. Melempar [FormatException] dengan pesan yang
  /// bisa langsung ditampilkan ke pengguna kalau berkasnya tidak cocok.
  Future<Map<String, dynamic>> _baca(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const FormatException('Berkas cadangan tidak ditemukan.');
    }

    Object? isi;
    try {
      isi = jsonDecode(await file.readAsString());
    } catch (_) {
      throw const FormatException(
        'Berkas ini tidak bisa dibaca. Pastikan memilih berkas '
        '"cadangan-....json" hasil dari menu Cadangkan data.',
      );
    }

    if (isi is! Map<String, dynamic>) {
      throw const FormatException('Isi berkas cadangan tidak dikenali.');
    }
    if (isi['aplikasi'] != 'TokoKu') {
      throw const FormatException(
        'Berkas ini bukan cadangan dari aplikasi TokoKu.',
      );
    }

    final format = isi['format'];
    if (format is! int) {
      throw const FormatException('Berkas cadangan tidak memuat nomor format.');
    }
    if (format > BackupService.formatCadangan) {
      throw const FormatException(
        'Cadangan ini dibuat oleh aplikasi versi yang lebih baru. '
        'Perbarui aplikasi TokoKu dulu, lalu coba lagi.',
      );
    }
    if (isi['tabel'] is! Map) {
      throw const FormatException('Berkas cadangan tidak memuat data.');
    }

    return isi;
  }

  /// Periksa berkas tanpa mengubah apa pun. Dipakai untuk menampilkan
  /// ringkasan sebelum pengguna menyetujui pemulihan.
  Future<RingkasanCadangan> periksa(String path) async {
    final data = await _baca(path);
    final tabel = data['tabel'] as Map;

    final jumlah = <String, int>{};
    for (final entry in tabel.entries) {
      final baris = entry.value;
      if (baris is List) jumlah['${entry.key}'] = baris.length;
    }

    final toko = data['toko'];

    return RingkasanCadangan(
      dibuat: '${data['dibuat'] ?? ''}',
      namaToko: toko is Map ? '${toko['nama'] ?? ''}' : '',
      jumlah: jumlah,
    );
  }

  /// Pulihkan data dari berkas cadangan.
  ///
  /// Data usaha yang ada di perangkat ini **diganti** oleh isi cadangan.
  /// Akun (email & password) dan pemasangan aplikasi tidak ikut tersentuh.
  Future<HasilPulih> pulihkan({
    required String path,
    required UserModel user,
  }) async {
    final data = await _baca(path);
    final tabel = (data['tabel'] as Map).cast<String, dynamic>();
    final toko = data['toko'] is Map
        ? (data['toko'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    final db = await DatabaseHelper.instance.database;
    final jumlah = <String, int>{};

    await db.transaction((txn) async {
      // 1. Kosongkan dulu — anak lebih dulu, baru induk, karena kunci asing
      //    aktif. Urutannya sama dengan "Reset semua data".
      for (final nama in BackupService.urutanHapus) {
        await txn.delete(nama);
      }

      // 2. Tanam ulang — induk lebih dulu, baru anak.
      for (final nama in BackupService.tabelCadangan) {
        final kolomSah = await _kolomTabel(txn, nama);
        final baris = tabel[nama];
        var masuk = 0;

        if (baris is List) {
          for (final item in baris) {
            if (item is! Map) continue;

            // Hanya kolom yang benar-benar ada di tabel ini yang dibawa.
            // Cadangan dari versi aplikasi lain bisa punya kolom tambahan
            // atau kolom yang sudah dihapus; menyaring di sini membuat
            // pemulihan tidak meledak karena satu kolom asing.
            final map = <String, Object?>{};
            for (final entry in item.entries) {
              final kunci = '${entry.key}';
              if (!kolomSah.contains(kunci)) continue;
              map[kunci] = entry.value;
            }
            if (map.isEmpty) continue;

            // Penjualan harus terikat ke akun yang ada DI PERANGKAT INI.
            // Id pemilik lama bisa saja sudah tidak ada di sini, dan kolom
            // `user_id` punya kunci asing ke tabel users.
            if (nama == 'sales' && user.id != null) {
              map['user_id'] = user.id;
            }

            // Metode pembayaran tidak pernah membawa `id` dari cadangan.
            // Tidak ada tabel yang menunjuk ke `payment_methods.id` — penjualan
            // menyimpan `code` sebagai teks — jadi id lama tidak berguna, dan
            // menanamnya bisa bentrok dengan id yang sudah terpakai di
            // perangkat ini (mis. perangkat ini sudah punya metode tambahan).
            if (nama == 'payment_methods') {
              map.remove('id');
              if (map.isEmpty) continue;

              // Dicocokkan lewat `code` yang unik: baris yang sudah ada
              // diperbarui, bukan ditanam ulang — menanam ulang akan bentrok
              // dengan `code` yang sama.
              final kode = map['code'];
              final sudahAda = await txn.query(
                'payment_methods',
                columns: ['id'],
                where: 'code = ?',
                whereArgs: [kode],
                limit: 1,
              );
              if (sudahAda.isNotEmpty) {
                await txn.update(
                  'payment_methods',
                  map,
                  where: 'code = ?',
                  whereArgs: [kode],
                );
                masuk++;
                continue;
              }
            }

            await txn.insert(nama, map);
            masuk++;
          }
        }

        jumlah[nama] = masuk;
      }

      // 3. Profil toko dikembalikan ke akun yang sedang login.
      //    Email dan password SENGAJA tidak ikut: akun itu milik perangkat
      //    ini, bukan milik berkas cadangan.
      if (user.id != null && toko.isNotEmpty) {
        final perbarui = <String, Object?>{};

        void ambil(String kunci, String kolom) {
          final nilai = toko[kunci];
          if (nilai is String && nilai.trim().isNotEmpty) {
            perbarui[kolom] = nilai;
          }
        }

        ambil('nama', 'store_name');
        ambil('alamat', 'store_address');
        ambil('telepon', 'store_phone');
        ambil('bankNama', 'bank_name');
        ambil('bankNomor', 'bank_account_number');
        ambil('bankAtasNama', 'bank_account_name');

        // Logo dan QRIS hanya dikembalikan kalau berkasnya benar-benar ada di
        // perangkat ini. Kalau tidak, alamatnya menunjuk berkas yang tidak ada
        // dan gambarnya tampil rusak — lebih baik dibiarkan kosong.
        for (final pasangan in const [
          ['logo', 'logo_path'],
          ['qris', 'qris_path'],
        ]) {
          final nilai = toko[pasangan[0]];
          if (nilai is String &&
              nilai.trim().isNotEmpty &&
              File(nilai).existsSync()) {
            perbarui[pasangan[1]] = nilai;
          }
        }

        if (perbarui.isNotEmpty) {
          await txn.update(
            'users',
            perbarui,
            where: 'id = ?',
            whereArgs: [user.id],
          );
        }
      }
    });

    return HasilPulih(
      totalBaris: jumlah.values.fold(0, (a, b) => a + b),
      jumlah: jumlah,
    );
  }

  /// Nama kolom yang benar-benar ada di sebuah tabel.
  Future<Set<String>> _kolomTabel(Transaction txn, String tabel) async {
    final hasil = await txn.rawQuery('PRAGMA table_info($tabel)');
    return hasil.map((r) => '${r['name']}').toSet();
  }
}
