import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Penyaring jeda untuk scanner barcode Bluetooth mode HID.
///
/// Scanner Bluetooth yang paling banyak dijual bekerja dalam mode HID: ke
/// Android ia tampil sebagai **keyboard fisik**. Alat itu "mengetik" digit
/// barcode sangat cepat (biasanya 5–30 ms antar karakter) lalu menutup dengan
/// Enter. Karena itu aplikasi ini tidak memerlukan Bluetooth API sama sekali —
/// tidak ada paket baru, tidak ada izin baru, dan tidak ada layar "pilih alat".
///
/// `flutter_blue_plus` yang sudah dipakai untuk printer termal **tidak** bisa
/// dipakai di sini: pustaka itu BLE (Bluetooth Low Energy), sedangkan scanner
/// HID memakai Bluetooth Classic (BR/EDR). Layar "cari alat scanner" justru
/// desain yang salah — alatnya dipasangkan sekali di Pengaturan Bluetooth
/// Android, lalu berlaku untuk aplikasi apa pun.
///
/// Yang membedakan scan dari ketikan manusia bukan isi tombolnya, melainkan
/// **jeda antar karakter**. Manusia mengetik dengan jeda ratusan milidetik;
/// scanner jauh lebih rapat. Kelas ini menyimpan jeda itu dan membuang
/// kumpulan karakter yang tersusun terlalu lambat, supaya angka yang diketik
/// manual tidak pernah ikut terbaca sebagai hasil scan.
class BarcodeWedge {
  /// Jeda antar karakter paling longgar yang masih dianggap satu scan.
  ///
  /// Manusia mengetik jauh lebih lambat daripada ini, jadi angka yang diketik
  /// manual selalu memutus kumpulan lebih dulu dan tidak pernah lolos.
  static const jedaMaksimum = Duration(milliseconds: 120);

  /// Panjang barcode paling pendek yang masih masuk akal, saat ada Enter.
  static const panjangMinimum = 4;

  /// Panjang paling pendek saat **tidak** ada Enter — sengaja lebih besar.
  static const panjangMinimumTanpaEnter = 6;

  /// Durasi paling lama untuk satu scan yang tidak diakhiri Enter.
  ///
  /// Enam karakter dalam 300 ms berarti di bawah 50 ms per karakter secara
  /// terus-menerus. Manusia tidak bisa melakukannya, jadi syarat ini yang
  /// menggantikan Enter tanpa membuka pintu bagi ketikan manual.
  static const durasiMaksimumTanpaEnter = Duration(milliseconds: 300);

  /// Batas aman panjang barcode dan kode internal.
  static const panjangMaksimum = 64;

  final StringBuffer _isi = StringBuffer();
  DateTime? _sebelumnya;
  DateTime? _mulai;

  /// Karakter yang sudah terkumpul sejauh ini.
  String get isi => _isi.toString();

  /// Buang kumpulan yang sedang berjalan.
  void bersihkan() {
    _isi.clear();
    _sebelumnya = null;
    _mulai = null;
  }

  /// Masukkan satu karakter beserta waktu kedatangannya.
  ///
  /// Jeda yang lebih longgar dari [jedaMaksimum] memutus kumpulan lebih dulu:
  /// itu bukan satu scan yang sedang berjalan, melainkan ketikan manusia.
  void masukkan(String karakter, DateTime sekarang) {
    final sebelum = _sebelumnya;
    if (sebelum != null && sekarang.difference(sebelum) > jedaMaksimum) {
      bersihkan();
    }
    _mulai ??= sekarang;
    _sebelumnya = sekarang;

    if (karakter.length != 1) return;
    if (_isi.length >= panjangMaksimum) return;
    _isi.write(karakter);
  }

  /// Tutup kumpulan karena ada penanda akhir yang pasti (Enter atau Tab).
  ///
  /// Mengembalikan barcode-nya, atau `null` kalau isinya tidak masuk akal.
  String? tutup() {
    final hasil = _isi.toString().trim();
    bersihkan();
    if (hasil.length < panjangMinimum) return null;
    if (hasil.length > panjangMaksimum) return null;
    return hasil;
  }

  /// Tutup kumpulan karena tidak ada karakter baru selama beberapa lama.
  ///
  /// Dipakai kalau scanner-nya tidak dikonfigurasi mengirim Enter. Syaratnya
  /// sengaja jauh lebih ketat daripada [tutup] — tanpa penanda akhir, hanya
  /// ketikan yang mustahil dilakukan manusia yang boleh dipercaya.
  String? tutupKarenaDiam(DateTime sekarang) {
    final mulai = _mulai;
    final hasil = _isi.toString().trim();
    final cukupCepat = mulai != null &&
        sekarang.difference(mulai) <= durasiMaksimumTanpaEnter;

    // Kumpulan ini sudah selesai apa pun hasilnya, jadi jangan ditinggalkan
    // menggantung — kalau tidak, isinya bisa terbawa ke Enter berikutnya.
    bersihkan();

    if (!cukupCepat) return null;
    if (hasil.length < panjangMinimumTanpaEnter) return null;
    if (hasil.length > panjangMaksimum) return null;
    return hasil;
  }
}

/// Penerima scan untuk seluruh aplikasi.
///
/// Dipasang sekali di `app.dart` sebagai pembungkus `MaterialApp.router`, lalu
/// layar-layar yang butuh mendengarkan [hasil] di `initState` masing-masing.
class BarcodeWedgeScanner {
  BarcodeWedgeScanner._();

  /// Satu instance untuk seluruh aplikasi.
  static final BarcodeWedgeScanner instance = BarcodeWedgeScanner._();

  /// Jeda diam yang menutup kumpulan kalau scanner-nya tidak mengirim Enter.
  static const jedaDiam = Duration(milliseconds: 250);

  final _wedge = BarcodeWedge();
  final _pengendali = StreamController<String>.broadcast();
  Timer? _jamDiam;

  /// Aliran barcode yang selesai terbaca.
  ///
  /// Siarannya broadcast supaya beberapa layar boleh mendengarkan sekaligus;
  /// yang benar-benar bertindak hanya layar yang rutenya sedang tampil
  /// (dijaga `ModalRoute.of(context)?.isCurrent` di masing-masing layar).
  Stream<String> get hasil => _pengendali.stream;

  /// Pasang ke `Focus.onKeyEvent` yang membungkus seluruh aplikasi.
  ///
  /// Selalu mengembalikan [KeyEventResult.ignored] supaya ketikannya tetap
  /// sampai ke kolom teks yang sedang difokuskan — penyaring ini menambah
  /// jalur, bukan menggantikannya.
  KeyEventResult dengar(KeyEvent event) {
    // Hanya saat tombol ditekan: KeyUpEvent dan KeyRepeatEvent akan menggandakan
    // tiap karakter.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Pintasan papan ketik (Ctrl/Alt/Meta) bukan hasil scan.
    final papan = HardwareKeyboard.instance;
    if (papan.isControlPressed || papan.isAltPressed || papan.isMetaPressed) {
      _batalkanJam();
      _wedge.bersihkan();
      return KeyEventResult.ignored;
    }

    // Penanda akhir diperiksa LEBIH DULU daripada karakter: karakter untuk
    // Enter adalah baris baru, jadi kalau urutannya terbalik, baris baru itu
    // ikut masuk ke dalam barcode.
    final tombol = event.logicalKey;
    final penandaAkhir = tombol == LogicalKeyboardKey.enter ||
        tombol == LogicalKeyboardKey.numpadEnter ||
        tombol == LogicalKeyboardKey.tab;
    if (penandaAkhir) {
      _batalkanJam();
      final kode = _wedge.tutup();
      if (kode != null) _pengendali.add(kode);
      return KeyEventResult.ignored;
    }

    final karakter = event.character;
    if (karakter == null || karakter.isEmpty) return KeyEventResult.ignored;

    _wedge.masukkan(karakter, DateTime.now());
    _pasangJam();
    return KeyEventResult.ignored;
  }

  void _pasangJam() {
    _batalkanJam();
    _jamDiam = Timer(jedaDiam, _karenaDiam);
  }

  void _batalkanJam() {
    _jamDiam?.cancel();
    _jamDiam = null;
  }

  void _karenaDiam() {
    _jamDiam = null;
    final kode = _wedge.tutupKarenaDiam(DateTime.now());
    if (kode != null) _pengendali.add(kode);
  }
}
