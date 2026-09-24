import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aturan PIN akun — jalan pintas harian pengganti mengetik email & kata sandi.
///
/// Sejak v1.20.0 PIN **milik akun**, bukan milik perangkat. Cacahnya disimpan
/// di kolom `users.pin_hash` (skema v12), dan seluruh pembacaannya ada di
/// `AuthRepository` bersama kolom `users` yang lain. Sebelumnya hanya ada satu
/// PIN untuk seluruh HP, sehingga PIN yang sama membuka aplikasi untuk siapa
/// pun yang memegangnya — itu yang diperbaiki.
///
/// Berkas ini sengaja hanya memuat hal yang **tidak menyentuh database**: cacah
/// PIN, aturan kelayakannya, dan sisa PIN perangkat versi lama. Dengan begitu
/// tidak ada dua tempat yang bisa berbeda pendapat soal "PIN apa yang sah", dan
/// `AuthRepository` bisa memakainya tanpa saling mengimpor.
class PinService {
  PinService._();
  static final PinService instance = PinService._();

  /// Kunci PIN perangkat versi lama (sebelum v1.20.0).
  ///
  /// Hanya dibaca sekali untuk dipindahkan ke akun pemilik, lalu dibersihkan
  /// lewat [lupakanLama]. Tidak ada lagi yang menulis ke sini.
  static const String _kunciHashLama = 'pin_hash';
  static const String _kunciAktifLama = 'pin_aktif';
  static const String _kunciPanjangLama = 'pin_panjang';

  /// Panjang PIN yang diterima.
  static const int panjangMin = 4;
  static const int panjangMaks = 6;

  /// Cacah SHA-256 sebuah PIN.
  ///
  /// Sengaja TANPA garam, dan itu load-bearing, bukan kelalaian:
  /// `AuthRepository.pasangPin` memakainya untuk menolak PIN yang sudah dipakai
  /// akun lain, dan `AuthRepository.loginDenganPin` memakainya untuk menemukan
  /// pemilik sebuah PIN dengan satu query. Kalau diberi garam, dua akun yang
  /// memasang PIN sama akan menghasilkan cacah berbeda, keduanya lolos
  /// pemeriksaan keunikan, lalu PIN yang diketik di layar masuk tidak lagi
  /// menunjuk tepat satu orang — kasir bisa masuk sebagai pemilik toko.
  ///
  /// PIN hanya 4–6 angka, jadi cacahnya memang bukan pengamanan setara kata
  /// sandi. Yang dijaganya: PIN tidak terbaca mata telanjang di berkas database.
  static String hashPin(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

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

  // ---------------------------------------------------- PIN perangkat lama

  /// Cacah PIN perangkat versi lama, atau `null` kalau tidak ada.
  ///
  /// Butuh DUA syarat, sama seperti dulu: penandanya aktif DAN cacahnya masih
  /// ada. Kalau cacahnya hilang — misalnya preferensi dibersihkan sebagian —
  /// tidak ada yang bisa dipindahkan, dan aplikasi tidak boleh mengunci diri
  /// sendiri tanpa jalan masuk.
  Future<String?> hashLama() async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(_kunciAktifLama) ?? false)) return null;
    final hash = prefs.getString(_kunciHashLama) ?? '';
    return hash.isEmpty ? null : hash;
  }

  /// Buang seluruh jejak PIN perangkat versi lama.
  ///
  /// Dipanggil setelah cacahnya pindah ke akun pemilik — atau setelah database
  /// jelas sudah punya PIN sendiri, sehingga PIN lama tidak berlaku lagi.
  /// Ketiga kuncinya dihapus, bukan sekadar ditandai mati, supaya tidak ada
  /// sisa yang bisa bangkit kembali.
  Future<void> lupakanLama() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kunciHashLama);
    await prefs.remove(_kunciPanjangLama);
    await prefs.remove(_kunciAktifLama);
  }
}
