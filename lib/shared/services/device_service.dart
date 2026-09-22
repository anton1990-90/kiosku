import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Menghasilkan Kode Perangkat yang stabil untuk HP ini.
///
/// Nilai ini dipakai sebagai pengikat lisensi: satu kode aktivasi hanya berlaku
/// untuk satu Kode Perangkat. Diambil dari Android ID lalu di-hash supaya ID
/// mentah perangkat tidak pernah ditampilkan atau dikirim ke server.
///
/// Catatan: Android ID berubah kalau aplikasi ditandatangani dengan kunci
/// berbeda atau HP di-reset pabrik. Karena itu kunci rilis harus dibuat
/// sebelum lisensi dijual.
class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  String? _cached;

  Future<String> getDeviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    String raw;
    try {
      final android = await DeviceInfoPlugin().androidInfo;
      raw = android.id;
    } catch (_) {
      raw = 'perangkat-tidak-dikenal';
    }

    final digest = sha256.convert(utf8.encode('tokoku::v1::$raw')).toString();
    final short = digest.substring(0, 12).toUpperCase();
    final code =
        'TK-${short.substring(0, 4)}-${short.substring(4, 8)}-${short.substring(8, 12)}';

    _cached = code;
    return code;
  }
}
