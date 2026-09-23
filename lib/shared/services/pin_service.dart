import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kunci PIN aplikasi — pengganti mengetik email & password setiap hari.
///
/// PIN **tidak pernah disimpan mentah**. Yang disimpan hanya hash SHA-256,
/// sama seperti password akun, jadi isi berkas preferensi tidak bisa dibaca
/// orang lain untuk mengetahui PIN-nya.
///
/// Disimpan di SharedPreferences, **bukan** di database, dengan dua alasan:
/// 1. Tidak perlu menaikkan versi skema database.
/// 2. Tidak ikut terhapus oleh "Reset semua data" — pemilik toko yang
///    menghapus data usahanya tetap terkunci dari orang lain.
class PinService {
  PinService._();
  static final PinService instance = PinService._();

  static const String _kunciHash = 'pin_hash';
  static const String _kunciAktif = 'pin_aktif';
  static const String _kunciPanjang = 'pin_panjang';

  /// Panjang PIN yang diterima.
  static const int panjangMin = 4;
  static const int panjangMaks = 6;

  String _hash(String pin) => sha256.convert(utf8.encode(pin)).toString();

  /// Apakah PIN sudah dipasang dan sedang aktif.
  ///
  /// Butuh DUA syarat: penandanya aktif DAN hashnya masih ada. Kalau hashnya
  /// hilang (misalnya preferensi dibersihkan sebagian), aplikasi tidak boleh
  /// mengunci diri sendiri tanpa jalan masuk.
  Future<bool> get aktif async {
    final prefs = await SharedPreferences.getInstance();
    final ditandai = prefs.getBool(_kunciAktif) ?? false;
    final hash = prefs.getString(_kunciHash) ?? '';
    return ditandai && hash.isNotEmpty;
  }

  /// Pasang PIN baru, atau ganti PIN lama.
  Future<void> pasang(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunciHash, _hash(pin));
    await prefs.setInt(_kunciPanjang, pin.length);
    await prefs.setBool(_kunciAktif, true);
  }

  /// Panjang PIN yang dipasang (4–6).
  ///
  /// Dipakai layar PIN untuk membuka kunci **otomatis** begitu jumlah angka
  /// yang diketik sudah pas — jadi pemilik toko tidak perlu menekan tombol
  /// "Buka" setiap kali membuka aplikasi. Panjangnya sendiri bukan rahasia:
  /// terlihat jelas saat mengetik.
  Future<int> get panjang async {
    final prefs = await SharedPreferences.getInstance();
    final tersimpan = prefs.getInt(_kunciPanjang) ?? panjangMin;
    if (tersimpan < panjangMin || tersimpan > panjangMaks) return panjangMin;
    return tersimpan;
  }

  /// Cocokkan PIN yang diketik. Yang dibandingkan hashnya, bukan teksnya.
  Future<bool> cocok(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final tersimpan = prefs.getString(_kunciHash) ?? '';
    if (tersimpan.isEmpty) return false;
    return tersimpan == _hash(pin);
  }

  /// Matikan PIN. Hashnya dihapus, bukan sekadar ditandai nonaktif — supaya
  /// tidak ada sisa hash yang bisa dipakai kalau nanti diaktifkan lagi.
  Future<void> matikan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kunciHash);
    await prefs.remove(_kunciPanjang);
    await prefs.setBool(_kunciAktif, false);
  }

  /// Periksa kelayakan PIN sebelum dipasang.
  ///
  /// Mengembalikan pesan kesalahan, atau `null` kalau PIN sudah layak.
  static String? periksa(String pin) {
    if (pin.length < panjangMin) {
      return 'PIN minimal $panjangMin angka.';
    }
    if (pin.length > panjangMaks) {
      return 'PIN maksimal $panjangMaks angka.';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) {
      return 'PIN hanya boleh berisi angka.';
    }
    // Semua angka sama, misalnya 1111 atau 2222.
    if (RegExp(r'^([0-9])\1+$').hasMatch(pin)) {
      return 'Jangan memakai angka yang sama semua.';
    }
    // Deret naik/turun yang paling sering dipakai orang.
    const mudah = {
      '1234', '12345', '123456',
      '4321', '54321', '654321',
      '0123', '01234', '012345',
      '0000', '9999',
    };
    if (mudah.contains(pin)) {
      return 'PIN terlalu mudah ditebak. Pakai angka lain.';
    }
    return null;
  }
}
