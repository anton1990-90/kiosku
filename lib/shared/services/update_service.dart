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

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
  });
}

/// Memeriksa pembaruan lewat GitHub Releases.
///
/// Tidak butuh server sendiri: setiap kali Anda push versi baru, workflow
/// menerbitkan Release dengan tag `v<versi>`, dan aplikasi membandingkannya
/// dengan versi yang terpasang. Kalau ada yang lebih baru, pengguna ditawari
/// unduh APK-nya.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  /// Mengembalikan [UpdateInfo] kalau ada versi lebih baru, selain itu null.
  /// Selalu gagal dengan tenang (return null) supaya aplikasi tetap bisa dipakai
  /// walau tidak ada internet.
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/${AppConfig.githubRepo}/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final data = Map<String, dynamic>.from(decoded);

      final tag = (data['tag_name']?.toString() ?? '')
          .replaceFirst(RegExp(r'^v'), '')
          .trim();
      if (tag.isEmpty) return null;

      if (_compareVersions(tag, currentVersion) <= 0) return null;

      String? downloadUrl;
      final assets = data['assets'];
      if (assets is List) {
        for (final asset in assets) {
          if (asset is Map &&
              (asset['name']?.toString() ?? '').endsWith('.apk')) {
            downloadUrl = asset['browser_download_url']?.toString();
            if (downloadUrl != null) break;
          }
        }
      }

      return UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: tag,
        downloadUrl: downloadUrl ?? AppConfig.latestApkUrl,
        releaseUrl: data['html_url']?.toString() ??
            'https://github.com/${AppConfig.githubRepo}/releases',
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
