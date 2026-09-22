import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_config.dart';
import '../../shared/services/device_service.dart';
import '../models/license_model.dart';

/// Menangani aktivasi lisensi (online sekali) dan penyimpanan statusnya.
///
/// Alur jual lepas yang dipakai:
///   * Pelanggan membeli Kode Voucher (VC-XXXX-XXXX-XXXX) dari penjual.
///   * Kode itu ditukar menjadi Kode Aktivasi yang terkunci ke satu HP.
///     Penukarannya bisa lewat halaman portal (di browser) atau langsung
///     dari layar aktivasi aplikasi ini — hasilnya sama.
///   * Setelah berhasil, statusnya disimpan di HP dan aplikasi berjalan
///     penuh tanpa internet selamanya.
///
/// Server yang dipakai adalah Cloudflare Worker (lihat folder `cloudflare/`).
/// Worker tidak pernah dibekukan karena lama tidak dipakai, jadi lisensi
/// pelanggan tetap bisa diaktifkan kapan saja.
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

  /// Aktifkan lisensi memakai [code].
  ///
  /// [code] boleh berupa Kode Voucher (VC-...) yang baru dibeli, atau Kode
  /// Aktivasi (AK-...) yang didapat dari portal. Melempar [LicenseException]
  /// dengan pesan yang sudah siap ditampilkan ke pelanggan.
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
            Uri.parse('${AppConfig.activationServerUrl}/api/aktivasi'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': trimmed,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw const LicenseException(
        'Tidak dapat menghubungi server aktivasi. Periksa koneksi internet Anda '
        'lalu coba lagi.',
      );
    }

    final Map<String, dynamic> data;
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) {
        throw const FormatException('bukan objek');
      }
      data = Map<String, dynamic>.from(decoded);
    } catch (_) {
      throw LicenseException(
        'Jawaban server tidak dikenali (${response.statusCode}). '
        'Coba lagi beberapa saat lagi.',
      );
    }

    if (data['ok'] != true) {
      throw LicenseException(_messageFor(data['reason']?.toString()));
    }

    // Server mengembalikan Kode Aktivasi yang berlaku. Kalau pelanggan tadi
    // menempel Kode Voucher, nilainya berbeda dari yang dia ketik — karena
    // itu yang disimpan harus yang dari server, bukan yang diketik.
    final activationCode =
        (data['activation_code'] ?? trimmed).toString().toUpperCase();

    return LicenseModel(
      code: activationCode,
      deviceId: deviceId,
      customerName: (data['customer_name'] ?? '').toString(),
      storeName: (data['store_name'] ?? '').toString(),
      // Server mengirim waktu dalam UTC; ubah ke waktu HP supaya tanggal
      // yang tampil di pengaturan tidak membingungkan.
      activatedAt:
          DateTime.tryParse((data['activated_at'] ?? '').toString())
                  ?.toLocal() ??
              DateTime.now(),
    );
  }

  String _messageFor(String? reason) {
    switch (reason) {
      case 'not_found':
        return 'Kode tidak ditemukan. Periksa kembali penulisannya, atau '
            'hubungi penjual tempat Anda membeli.';
      case 'used_on_other_device':
        return 'Kode ini sudah dipakai di HP lain. Satu kode hanya berlaku '
            'untuk satu HP. Hubungi penjual kalau Anda baru mengganti HP.';
      case 'revoked':
        return 'Kode ini sudah dinonaktifkan oleh penjual.';
      case 'device_code_entered':
        return 'Sepertinya Anda menempel Kode Perangkat, bukan Kode Voucher. '
            'Isi kolom ini dengan kode berawalan VC- yang Anda beli.';
      case 'busy':
        return 'Sedang ada permintaan lain untuk kode ini. Tunggu sebentar '
            'lalu coba lagi.';
      case 'invalid_code':
        return 'Kode aktivasi tidak boleh kosong.';
      case 'bad_request':
      case 'server_error':
        return 'Server sedang bermasalah. Coba lagi beberapa saat lagi.';
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
