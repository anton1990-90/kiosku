import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Jenis sambungan sebuah printer.
///
/// Ini bukan detail teknis yang bisa diabaikan: printer thermal 58 mm hampir
/// semuanya **klasik** (Bluetooth Classic SPP), sedangkan `flutter_blue_plus`
/// hanya bisa BLE. Perangkat klasik tidak akan pernah muncul di pemindaian BLE,
/// jadi keduanya harus ditangani lewat jalur yang berbeda.
enum JenisPrinter {
  /// Bluetooth Classic SPP (RFCOMM). Dipakai RPP02N, Xprinter, Goojprt,
  /// MPT-II, dan printer thermal murah lainnya.
  klasik,

  /// Bluetooth Low Energy (GATT). Dipakai sebagian printer kecil/portabel.
  ble,
}

/// Satu printer yang bisa dipilih pengguna.
class PrinterDevice {
  const PrinterDevice({
    required this.id,
    required this.nama,
    required this.jenis,
    this.terpasang = false,
  });

  /// Alamat MAC untuk printer klasik, atau remote id untuk BLE.
  final String id;
  final String nama;
  final JenisPrinter jenis;

  /// Sudah dipasangkan (bonded) di Pengaturan Bluetooth Android?
  /// Printer klasik harus dipasangkan lebih dulu sebelum bisa disambung.
  final bool terpasang;

  /// Nama yang layak ditampilkan. Sebagian printer tidak mengumumkan namanya.
  String get label => nama.trim().isEmpty ? id : nama.trim();

  @override
  bool operator ==(Object other) =>
      other is PrinterDevice && other.id == id && other.jenis == jenis;

  @override
  int get hashCode => Object.hash(id, jenis);
}

/// Keadaan Bluetooth di perangkat ini.
class StatusPrinter {
  const StatusPrinter({
    required this.didukung,
    required this.aktif,
    required this.izin,
  });

  /// Perangkat punya adaptor Bluetooth.
  final bool didukung;

  /// Bluetooth sedang menyala.
  final bool aktif;

  /// Izin runtime sudah diberikan (Android 12+).
  final bool izin;

  static const StatusPrinter tidakDidukung = StatusPrinter(
    didukung: false,
    aktif: false,
    izin: false,
  );
}

/// Layanan printer thermal Bluetooth.
///
/// Dua jalur, dipilih menurut [JenisPrinter]:
///
///  * **klasik** — lewat kanal native `tokoku/printer_spp`
///    (lihat `tools/android/PrinterSpp.kt`). Inilah jalur untuk printer thermal
///    biasa, termasuk RPP02N.
///  * **ble** — lewat `flutter_blue_plus`, untuk printer BLE.
///
/// Kanal native juga yang meminta izin runtime `BLUETOOTH_SCAN` /
/// `BLUETOOTH_CONNECT`. Tanpa itu, pemindaian di Android 12+ mengembalikan nol
/// perangkat tanpa pesan galat sama sekali.
class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  static const MethodChannel _kanal = MethodChannel('tokoku/printer_spp');
  static const EventChannel _kanalPindai =
      EventChannel('tokoku/printer_spp/perangkat');

  /// Layanan GATT per printer BLE yang sudah tersambung.
  final Map<String, List<BluetoothService>> _layananBle = {};

  // -------------------------------------------------------------------
  // Status & izin
  // -------------------------------------------------------------------

  Future<StatusPrinter> status() async {
    try {
      final hasil = await _kanal.invokeMethod<Map<dynamic, dynamic>>('status');
      if (hasil == null) return StatusPrinter.tidakDidukung;
      return StatusPrinter(
        didukung: hasil['didukung'] == true,
        aktif: hasil['aktif'] == true,
        izin: hasil['izin'] == true,
      );
    } on MissingPluginException {
      // Kanal tidak terdaftar: build lama, atau aplikasi dijalankan di desktop.
      return StatusPrinter.tidakDidukung;
    } on PlatformException {
      return StatusPrinter.tidakDidukung;
    }
  }

  /// Minta izin Bluetooth. Mengembalikan true kalau sudah diberikan.
  ///
  /// Diberi batas waktu karena dialog izin bisa ditinggal tanpa dijawab —
  /// tanpa batas, layar akan berputar selamanya.
  Future<bool> mintaIzin() async {
    try {
      final hasil = await _kanal
          .invokeMethod<bool>('mintaIzin')
          .timeout(const Duration(minutes: 2));
      return hasil ?? false;
    } on TimeoutException {
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  // -------------------------------------------------------------------
  // Daftar perangkat
  // -------------------------------------------------------------------

  /// Printer yang sudah dipasangkan di Pengaturan Bluetooth Android.
  ///
  /// Ini daftar yang paling bisa diandalkan: pemasangan dilakukan sekali oleh
  /// pengguna, lalu printer selalu muncul di sini tanpa perlu memindai.
  Future<List<PrinterDevice>> printerTerpasang() async {
    try {
      final hasil = await _kanal.invokeMethod<List<dynamic>>('terpasang');
      if (hasil == null) return const [];
      final daftar = <PrinterDevice>[];
      for (final baris in hasil) {
        if (baris is! Map) continue;
        final id = (baris['id'] ?? '').toString();
        if (id.isEmpty) continue;
        daftar.add(
          PrinterDevice(
            id: id,
            nama: (baris['nama'] ?? '').toString(),
            jenis: JenisPrinter.klasik,
            terpasang: true,
          ),
        );
      }
      return daftar;
    } on MissingPluginException {
      return const [];
    } on PlatformException {
      return const [];
    }
  }

  /// Aliran printer klasik yang ditemukan saat memindai.
  ///
  /// Perangkat yang belum dipasangkan ikut muncul; layar pemilihan yang
  /// memutuskan kapan perlu memasangkan lebih dulu.
  Stream<PrinterDevice> pindaiKlasik() {
    return _kanalPindai.receiveBroadcastStream().map((kejadian) {
      if (kejadian is! Map) {
        return const PrinterDevice(
          id: '',
          nama: '',
          jenis: JenisPrinter.klasik,
        );
      }
      return PrinterDevice(
        id: (kejadian['id'] ?? '').toString(),
        nama: (kejadian['nama'] ?? '').toString(),
        jenis: JenisPrinter.klasik,
        terpasang: kejadian['terpasang'] == true,
      );
    }).where((alat) => alat.id.isNotEmpty);
  }

  /// Mulai memindai printer klasik. Hasilnya lewat [pindaiKlasik].
  Future<bool> mulaiPindaiKlasik() async {
    try {
      final hasil = await _kanal.invokeMethod<bool>('mulaiPindai');
      return hasil ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> hentikanPindaiKlasik() async {
    try {
      await _kanal.invokeMethod<bool>('hentikanPindai');
    } on MissingPluginException {
      // Tidak ada kanal: tidak ada pemindaian yang berjalan.
    } on PlatformException {
      // Idem.
    }
  }

  /// Pasangkan printer klasik (munculkan dialog PIN Android).
  Future<bool> pasangkan(String id) async {
    try {
      final hasil = await _kanal.invokeMethod<bool>('pasangkan', id);
      return hasil ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Pindai printer BLE. Cadangan untuk printer yang tidak memakai SPP.
  Future<List<PrinterDevice>> pindaiBle({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final ditemukan = <String, PrinterDevice>{};
    StreamSubscription<List<ScanResult>>? langganan;
    try {
      langganan = FlutterBluePlus.scanResults.listen((hasil) {
        for (final r in hasil) {
          final nama = r.device.platformName.trim();
          final id = r.device.remoteId.str;
          if (id.isEmpty) continue;
          ditemukan[id] = PrinterDevice(
            id: id,
            nama: nama,
            jenis: JenisPrinter.ble,
          );
        }
      });
      await FlutterBluePlus.startScan(timeout: timeout);
      await Future<void>.delayed(timeout);
    } catch (_) {
      // BLE tidak tersedia atau izin belum ada. Bukan alasan menggagalkan
      // seluruh pemindaian — jalur klasik tetap yang utama.
    } finally {
      await langganan?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Pemindaian memang sudah berhenti sendiri.
      }
    }
    return ditemukan.values.toList();
  }

  // -------------------------------------------------------------------
  // Sambungan
  // -------------------------------------------------------------------

  Future<void> sambung(PrinterDevice alat) async {
    if (alat.jenis == JenisPrinter.klasik) {
      await _kanal.invokeMethod<bool>('sambung', alat.id);
      return;
    }
    final perangkat = BluetoothDevice.fromId(alat.id);
    await perangkat.connect(timeout: const Duration(seconds: 15));
    _layananBle[alat.id] = await perangkat.discoverServices();
  }

  /// Kirim byte ESC/POS ke printer yang sedang tersambung.
  Future<void> cetak(PrinterDevice alat, List<int> bytes) async {
    if (bytes.isEmpty) {
      throw Exception('Data struk kosong');
    }
    if (alat.jenis == JenisPrinter.klasik) {
      await _kanal.invokeMethod<bool>('tulis', Uint8List.fromList(bytes));
      return;
    }
    await _tulisBle(alat, bytes);
  }

  Future<void> putus(PrinterDevice alat) async {
    if (alat.jenis == JenisPrinter.klasik) {
      try {
        await _kanal.invokeMethod<bool>('putus');
      } on MissingPluginException {
        // Tidak ada yang perlu diputus.
      } on PlatformException {
        // Idem.
      }
      return;
    }
    _layananBle.remove(alat.id);
    try {
      await BluetoothDevice.fromId(alat.id).disconnect();
    } catch (_) {
      // Sudah terputus sendiri.
    }
  }

  BluetoothCharacteristic? _cariKarakteristik(PrinterDevice alat) {
    final layanan = _layananBle[alat.id];
    if (layanan == null) return null;
    for (final s in layanan) {
      for (final c in s.characteristics) {
        if (c.properties.write || c.properties.writeWithoutResponse) {
          return c;
        }
      }
    }
    return null;
  }

  Future<void> _tulisBle(PrinterDevice alat, List<int> bytes) async {
    final karakteristik = _cariKarakteristik(alat);
    if (karakteristik == null) {
      throw Exception('Printer BLE tidak punya kanal tulis');
    }
    // BLE membatasi ukuran satu paket; 180 byte aman untuk hampir semua printer.
    const potong = 180;
    for (var i = 0; i < bytes.length; i += potong) {
      final akhir = i + potong > bytes.length ? bytes.length : i + potong;
      await karakteristik.write(
        bytes.sublist(i, akhir),
        withoutResponse: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 12));
    }
  }
}
