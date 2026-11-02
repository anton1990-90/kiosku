import 'package:flutter/services.dart';

/// Satu alat USB yang sedang tercolok.
class UsbScannerDevice {
  const UsbScannerDevice({
    required this.nama,
    required this.judul,
    required this.vendorId,
    required this.productId,
    required this.kelas,
    required this.hid,
    required this.izin,
  });

  /// Nama simpul dari Android, mis. `/dev/bus/usb/001/002`.
  final String nama;

  /// Nama yang bisa dibaca manusia, mis. `USB KeyBoard` atau `USB 1a86:7523`.
  final String judul;

  final int vendorId;
  final int productId;

  /// `HID`, `COM`, `PENYIMPANAN`, atau `LAIN`.
  final String kelas;

  /// Alat ini menampilkan diri sebagai keyboard (HID).
  final bool hid;

  /// Izin USB sudah diberikan Android untuk alat ini.
  final bool izin;

  /// Alat ini memakai mode serial (COM), bukan keyboard.
  ///
  /// Inilah kegagalan yang paling membingungkan saat memakai scanner lewat
  /// kabel: alatnya terdeteksi, lampunya menyala, dan Android menyebutnya
  /// "terpasang" — tetapi tidak ada satu karakter pun yang sampai ke aplikasi,
  /// karena alat itu mengirim lewat jalur serial yang tidak dibaca siapa pun.
  /// Memperbaikinya bukan dari sisi aplikasi, melainkan dengan memindai
  /// barcode "USB HID Keyboard" di buku manual alat.
  bool get modeCom => kelas == 'COM';
}

/// Hasil pemeriksaan colokan USB.
class HasilUsb {
  const HasilUsb({
    required this.tersedia,
    this.alat = const [],
    this.galat,
  });

  /// Apakah pemeriksaan bisa dijalankan.
  ///
  /// `false` di luar Android (mis. saat uji di komputer) dan pada build yang
  /// tidak menyertakan kanal native — bukan kesalahan pengguna.
  final bool tersedia;

  final List<UsbScannerDevice> alat;

  /// Pesan galat kalau pemeriksaan gagal karena hal lain.
  final String? galat;

  bool get adaHid => alat.any((a) => a.hid);
  bool get adaCom => alat.any((a) => a.modeCom);
}

/// Membaca daftar alat USB yang tercolok lewat kanal native.
///
/// Kanal ini **tidak** dipakai untuk menerima hasil scan. Scanner USB dan
/// dongle nirkabel sudah mengirim sebagai keyboard, jadi Android sendiri yang
/// meneruskannya ke aplikasi tanpa izin apa pun. Yang dibaca di sini hanya
/// daftar alatnya — supaya halaman pengaturan bisa membedakan tiga keadaan
/// yang gejalanya sama-sama "tidak bisa scan": tidak ada alat tercolok, alat
/// tercolok dalam mode COM, dan alat tercolok dalam mode keyboard yang benar.
class UsbScanner {
  UsbScanner._();

  static const MethodChannel _kanal = MethodChannel('tokoku/pemindai_usb');

  static Future<HasilUsb> periksa() async {
    try {
      final hasil = await _kanal.invokeMethod<List<dynamic>>('daftar');
      final alat = <UsbScannerDevice>[];
      for (final baris in hasil ?? const []) {
        if (baris is! Map) continue;
        alat.add(
          UsbScannerDevice(
            nama: _teks(baris['nama']),
            judul: _teks(baris['judul']),
            vendorId: _angka(baris['vendor']),
            productId: _angka(baris['produk']),
            kelas: _teks(baris['kelas']),
            hid: baris['hid'] == true,
            izin: baris['izin'] == true,
          ),
        );
      }
      return HasilUsb(tersedia: true, alat: alat);
    } on MissingPluginException {
      // Kanal belum ada: build tanpa ScannerUsb.kt, atau aplikasi dijalankan di
      // komputer. Bukan galat yang perlu ditampilkan sebagai kegagalan.
      return const HasilUsb(tersedia: false);
    } on PlatformException catch (e) {
      return HasilUsb(tersedia: false, galat: e.message ?? e.code);
    } catch (e) {
      return HasilUsb(tersedia: false, galat: e.toString());
    }
  }

  static String _teks(Object? nilai) => nilai is String ? nilai : '';

  static int _angka(Object? nilai) {
    if (nilai is int) return nilai;
    if (nilai is num) return nilai.toInt();
    return 0;
  }
}
