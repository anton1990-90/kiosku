import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../shared/services/device_service.dart';
import '../models/license_model.dart';

/// Menangani aktivasi lisensi (online) dan penyimpanan statusnya (offline).
///
/// Alur: aplikasi mengirim Kode Perangkat + Kode Aktivasi ke server Supabase.
/// Server hanya mengizinkan satu perangkat per kode. Setelah berhasil, status
/// disimpan di HP sehingga aplikasi berjalan tanpa internet selamanya.
class LicenseRepository {
  static const _kCode = 'lic_code';
  static const _kDevice = 'lic_device';
  static const _kCustomer = 'lic_customer';
  static const _kStore = 'lic_store';
  static const _kActivated = 'lic_activated_at';
  static const _kSig = 'lic_sig';

  String _sign(String code, String deviceId, String activatedIso) {
    final payload = '$code|$deviceId|$activatedIso';
    return Hmac(sha256, utf8.encode(AppConfig.licenseIntegrityKey))
        .convert(utf8.encode(payload))
        .toString();
  }

  /// Aktifkan lisensi. Melempar [LicenseException] dengan pesan siap tampil.
  Future<LicenseModel> activate({required String code}) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      throw const LicenseException('Kode aktivasi tidak boleh kosong.');
    }
    if (!AppConfig.isActivationConfigured) {
      throw const LicenseException(
        'Server aktivasi belum diatur. Hubungi pengembang aplikasi.',
      );
    }

    final deviceId = await DeviceService.instance.getDeviceId();

    final http.Response response;
    try {
      response = await http
          .post(
            Uri.parse('${AppConfig.supabaseUrl}/rest/v1/rpc/activate_license'),
            headers: {
              'apikey': AppConfig.supabaseAnonKey,
              'Authorization': 'Bearer ${AppConfig.supabaseAnonKey}',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'p_code': trimmed,
              'p_device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw const LicenseException(
        'Tidak dapat menghubungi server aktivasi. Periksa koneksi internet Anda '
        'lalu coba lagi.',
      );
    }

    if (response.statusCode != 200) {
      throw LicenseException(
        'Server aktivasi menolak permintaan (${response.statusCode}). '
        'Coba lagi beberapa saat lagi.',
      );
    }

    final dynamic decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const LicenseException('Jawaban server tidak dikenali.');
    }
    final data = Map<String, dynamic>.from(decoded);

    if (data['ok'] != true) {
      throw LicenseException(_messageFor(data['reason']?.toString()));
    }

    return LicenseModel(
      code: trimmed,
      deviceId: deviceId,
      customerName: (data['customer_name'] ?? '').toString(),
      storeName: (data['store_name'] ?? '').toString(),
      activatedAt: DateTime.now(),
    );
  }

  String _messageFor(String? reason) {
    switch (reason) {
      case 'not_found':
        return 'Kode aktivasi tidak ditemukan. Periksa kembali penulisan kodenya.';
      case 'used_on_other_device':
        return 'Kode ini sudah dipakai di HP lain. Hubungi penjual untuk '
            'memindahkan lisensi ke HP ini.';
      case 'revoked':
        return 'Kode aktivasi ini sudah dinonaktifkan oleh penjual.';
      case 'invalid_code':
        return 'Kode aktivasi tidak boleh kosong.';
      default:
        return 'Aktivasi gagal. Hubungi penjual aplikasi.';
    }
  }

  /// Simpan status lisensi ke perangkat, disertai tanda tangan pemeriksa.
  Future<void> saveLocal(LicenseModel license) async {
    final prefs = await SharedPreferences.getInstance();
    final activatedIso = license.activatedAt.toIso8601String();
    await prefs.setString(_kCode, license.code);
    await prefs.setString(_kDevice, license.deviceId);
    await prefs.setString(_kCustomer, license.customerName);
    await prefs.setString(_kStore, license.storeName);
    await prefs.setString(_kActivated, activatedIso);
    await prefs.setString(
      _kSig,
      _sign(license.code, license.deviceId, activatedIso),
    );
  }

  /// Baca status lisensi dari perangkat.
  /// Mengembalikan null kalau belum pernah aktivasi atau data sudah diubah.
  Future<LicenseModel?> loadLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kCode);
    final deviceId = prefs.getString(_kDevice);
    final activatedIso = prefs.getString(_kActivated);
    final signature = prefs.getString(_kSig);
    if (code == null ||
        deviceId == null ||
        activatedIso == null ||
        signature == null) {
      return null;
    }

    if (_sign(code, deviceId, activatedIso) != signature) return null;

    // Kode perangkat harus masih sama dengan HP yang dipakai sekarang.
    final current = await DeviceService.instance.getDeviceId();
    if (current != deviceId) return null;

    return LicenseModel(
      code: code,
      deviceId: deviceId,
      customerName: prefs.getString(_kCustomer) ?? '',
      storeName: prefs.getString(_kStore) ?? '',
      activatedAt: DateTime.tryParse(activatedIso) ?? DateTime.now(),
    );
  }

  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCode);
    await prefs.remove(_kDevice);
    await prefs.remove(_kCustomer);
    await prefs.remove(_kStore);
    await prefs.remove(_kActivated);
    await prefs.remove(_kSig);
  }
}
