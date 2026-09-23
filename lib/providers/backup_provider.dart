import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/user_model.dart';
import '../shared/services/backup_service.dart';

/// Status cadangan otomatis.
class BackupState {
  /// Sedang membaca preferensi.
  final bool isLoading;

  /// Cadangan otomatis menyala.
  final bool otomatis;

  /// Kapan cadangan terakhir berhasil dibuat.
  final DateTime? terakhir;

  /// Pesan hasil percobaan terakhir, untuk ditampilkan di layar.
  final String? pesan;

  /// Sedang membuat cadangan saat ini.
  final bool sedangJalan;

  const BackupState({
    this.isLoading = true,
    this.otomatis = true,
    this.terakhir,
    this.pesan,
    this.sedangJalan = false,
  });

  /// Apakah sudah lewat 24 jam sejak cadangan terakhir.
  ///
  /// Kalau belum pernah sama sekali, dianggap sudah waktunya.
  bool get sudahWaktunya {
    if (!otomatis) return false;
    final kapan = terakhir;
    if (kapan == null) return true;
    return DateTime.now().difference(kapan).inHours >= 24;
  }

  BackupState salin({
    bool? isLoading,
    bool? otomatis,
    DateTime? terakhir,
    String? pesan,
    bool? sedangJalan,
    bool hapusPesan = false,
  }) {
    return BackupState(
      isLoading: isLoading ?? this.isLoading,
      otomatis: otomatis ?? this.otomatis,
      terakhir: terakhir ?? this.terakhir,
      pesan: hapusPesan ? null : (pesan ?? this.pesan),
      sedangJalan: sedangJalan ?? this.sedangJalan,
    );
  }
}

/// Pengatur cadangan otomatis.
///
/// Cadangan **tidak** dijalankan oleh penjadwal latar belakang, karena Android
/// tidak bisa dijamin menjalankan kode saat aplikasi tertutup (HP bisa dimatikan
/// atau aplikasi dihentikan paksa oleh sistem). Yang dipakai: setiap kali
/// aplikasi dibuka, kalau cadangan terakhir sudah lewat 24 jam, cadangan
/// langsung dibuat. Hasilnya sama andalnya dan tidak ada backup yang terlewat.
class BackupNotifier extends StateNotifier<BackupState> {
  BackupNotifier() : super(const BackupState()) {
    _siap = _init();
  }

  /// Selesainya pembacaan preferensi.
  ///
  /// Dipakai untuk menunggu, bukan sekadar berharap. Beranda memanggil
  /// [jalankanOtomatis] dari `initState`, saat [BackupState.isLoading] masih
  /// benar — kalau tidak ditunggu, cadangan otomatis tidak akan pernah jalan
  /// pada pembukaan aplikasi yang cepat.
  late final Future<void> _siap;

  static const String _kunciOtomatis = 'backup_otomatis';
  static const String _kunciTerakhir = 'backup_terakhir';

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    final otomatis = prefs.getBool(_kunciOtomatis) ?? true;
    final teks = prefs.getString(_kunciTerakhir);

    state = BackupState(
      isLoading: false,
      otomatis: otomatis,
      terakhir: teks == null ? null : DateTime.tryParse(teks),
    );
  }

  /// Nyalakan atau matikan cadangan otomatis.
  Future<void> setOtomatis(bool nilai) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kunciOtomatis, nilai);
    state = state.salin(otomatis: nilai, hapusPesan: true);
  }

  /// Buat cadangan kalau memang sudah waktunya.
  ///
  /// Aman dipanggil setiap kali aplikasi dibuka: kalau belum lewat 24 jam,
  /// fungsi ini langsung keluar tanpa mengerjakan apa pun.
  Future<void> jalankanOtomatis({required UserModel user}) async {
    await _siap;
    if (state.sedangJalan) return;
    if (!state.sudahWaktunya) return;
    await _buat(user: user, otomatis: true);
  }

  /// Buat cadangan sekarang juga, dipicu tombol.
  Future<File?> cadangkanSekarang({required UserModel user}) async {
    await _siap;
    return _buat(user: user, otomatis: false);
  }

  Future<File?> _buat({
    required UserModel user,
    required bool otomatis,
  }) async {
    state = state.salin(sedangJalan: true, hapusPesan: true);

    try {
      final berkas = await BackupService.instance.createBackupJson(
        user: user,
        otomatis: otomatis,
      );

      final sekarang = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kunciTerakhir, sekarang.toIso8601String());

      state = state.salin(
        sedangJalan: false,
        terakhir: sekarang,
        pesan: otomatis
            ? 'Cadangan harian dibuat otomatis.'
            : 'Cadangan dibuat. Simpan berkasnya ke email atau Google Drive.',
      );
      return berkas;
    } catch (_) {
      // Gagal mencadangkan tidak boleh mengganggu pemakaian aplikasi, jadi
      // hanya dicatat sebagai pesan.
      state = state.salin(
        sedangJalan: false,
        pesan: 'Cadangan gagal dibuat. Coba lagi nanti.',
      );
      return null;
    }
  }

  /// Bersihkan pesan setelah ditampilkan.
  void bersihkanPesan() {
    if (state.pesan == null) return;
    state = state.salin(hapusPesan: true);
  }
}

final backupProvider = StateNotifierProvider<BackupNotifier, BackupState>((ref) {
  return BackupNotifier();
});
