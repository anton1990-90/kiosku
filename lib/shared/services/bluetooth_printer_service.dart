import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Bluetooth thermal printer service.
/// Scans for nearby Bluetooth thermal printers and sends ESC/POS bytes.
///
/// Most 58mm/80mm thermal printers (yang umum dipakai toko sembako)
/// menggunakan Bluetooth Classic SPP. `flutter_blue_plus` dapat menemukan
/// dan berkomunikasi dengan perangkat tersebut via characteristic write.
class BluetoothPrinterService {
  BluetoothPrinterService._();
  static final BluetoothPrinterService instance = BluetoothPrinterService._();

  /// Scan for nearby devices, filtered by common thermal printer names.
  Future<List<BluetoothDevice>> scanPrinters({Duration timeout = const Duration(seconds: 8)}) async {
    final found = <String, BluetoothDevice>{};

    // Start scan (skip existing results for a fresh list)
    await FlutterBluePlus.startScan(timeout: timeout);

    final sub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        final name = r.device.platformName.trim();
        final id = r.device.remoteId.str;
        // Common thermal printer keywords
        final isPrinter = _looksLikePrinter(name);
        if (isPrinter || name.isEmpty) {
          found[id] = r.device;
        }
      }
    });

    await Future.delayed(timeout);
    await sub.cancel();
    await FlutterBluePlus.stopScan();

    return found.values.toList();
  }

  /// Heuristic: does this device name look like a thermal printer?
  bool _looksLikePrinter(String name) {
    final lower = name.toLowerCase();
    const keywords = [
      'printer', 'prnt', 'thermal', '58', '80', 'esc', 'pos',
      'pp', 'mpt', 'rp', 'bt', 'receipt', 'casher', 'kasir',
    ];
    return keywords.any(lower.contains);
  }

  /// Connect to a device and return it (ready for writing).
  Future<BluetoothDevice> connect(BluetoothDevice device) async {
    await device.connect(timeout: const Duration(seconds: 10));
    await device.discoverServices();
    return device;
  }

  /// Find a writable characteristic on the connected device.
  BluetoothCharacteristic? findWriteCharacteristic(BluetoothDevice device) {
    for (final service in device.servicesList) {
      for (final characteristic in service.characteristics) {
        // Properties.write or Properties.writeWithoutResponse
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {
          return characteristic;
        }
      }
    }
    return null;
  }

  /// Write receipt bytes to the printer in chunks.
  Future<void> printBytes(BluetoothDevice device, List<int> bytes) async {
    final characteristic = findWriteCharacteristic(device);
    if (characteristic == null) {
      throw Exception('Characteristic printer tidak ditemukan');
    }

    const chunkSize = 20;
    for (var i = 0; i < bytes.length; i += chunkSize) {
      final end = (i + chunkSize > bytes.length) ? bytes.length : i + chunkSize;
      final chunk = bytes.sublist(i, end);
      await characteristic.write(chunk, withoutResponse: true);
      // Small delay to let the printer process each chunk
      await Future.delayed(const Duration(milliseconds: 20));
    }
  }

  /// Disconnect from a device.
  Future<void> disconnect(BluetoothDevice device) async {
    await device.disconnect();
  }
}
