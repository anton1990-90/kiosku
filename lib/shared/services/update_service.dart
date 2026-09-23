import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/config/app_config.dart';

/// Informasi pembaruan aplikasi.
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String downloadUrl;
  final String releaseUrl;

  /// Ukuran berkas APK dalam byte. 0 kalau servernya tidak melaporkan.
  final int ukuranBytes;

  /// Catatan rilis dari penjual (boleh kosong).
  final String catatan;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
    this.ukuranBytes = 0,
    this.catatan = '',
  });

  /// Ukuran berkas dalam teks yang enak dibaca, mis. "31,6 MB".
  /// Kosong kalau ukurannya tidak diketahui.
  String get ukuranTeks {
    if (ukuranBytes <= 0) return '';
    final mb = ukuranBytes / (1024 * 1024);
    if (mb >= 1) return '${mb.toStringAsFixed(1).replaceAll('.', ',')} MB';
    return '${(ukuranBytes / 1024).round()} KB';
  }
}

/// Memeriksa pembaruan aplikasi lewat server aktivasi sendiri.
///
/// Aplikasi TIDAK pernah menghubungi GitHub. Server aktivasi (Cloudflare
/// Worker) yang menanyakan versi terbaru ke GitHub lalu meneruskannya ke sini,
/// dan Worker juga yang mengalirkan berkas APK-nya. Alasannya sederhana:
/// pelanggan tidak perlu tahu — dan sebaiknya tidak bisa mencari — akun
/// GitHub penjual.
///
/// Kalau server aktivasi belum diisi, pemeriksaan dilewati sepenuhnya.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Mengembalikan [UpdateInfo] kalau ada versi lebih baru, selain itu null.
  /// Selalu gagal dengan tenang (return null) supaya aplikasi tetap bisa
  /// dipakai walau tidak ada internet.
  Future<UpdateInfo?> checkForUpdate() async {
    if (!AppConfig.isActivationConfigured) return null;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http
          .get(Uri.parse(AppConfig.versionCheckUrl))
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);

      // Server membalas ok:false kalau belum ada rilis sama sekali.
      if (data['ok'] != true) return null;

      final tag = (data['versi']?.toString() ?? '')
          .replaceFirst(RegExp(r'^v'), '')
          .trim();
      if (tag.isEmpty) return null;

      if (_compareVersions(tag, currentVersion) <= 0) return null;

      final unduh = (data['unduh']?.toString() ?? '').trim();
      final ukuran = data['ukuran'] is num
          ? (data['ukuran'] as num).toInt()
          : 0;

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tag,
        downloadUrl: unduh.isNotEmpty ? unduh : AppConfig.latestApkUrl,
        releaseUrl: AppConfig.downloadPageUrl,
        ukuranBytes: ukuran,
        catatan: (data['catatan']?.toString() ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Bandingkan dua versi bergaya `1.2.3`.
  /// Mengembalikan >0 kalau [a] lebih baru dari [b].
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.');
    final partsB = b.split('.');
    final length = partsA.length > partsB.length ? partsA.length : partsB.length;

    for (var i = 0; i < length; i++) {
      final valueA = i < partsA.length ? (int.tryParse(partsA[i]) ?? 0) : 0;
      final valueB = i < partsB.length ? (int.tryParse(partsB[i]) ?? 0) : 0;
      if (valueA != valueB) return valueA.compareTo(valueB);
    }
    return 0;
  }
}
