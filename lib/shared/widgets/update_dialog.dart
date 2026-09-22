import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../services/update_service.dart';

/// Tawarkan pembaruan aplikasi. Membuka browser untuk mengunduh APK baru.
Future<void> showUpdateDialog(BuildContext context, UpdateInfo info) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.system_update_alt, color: AppColors.primary, size: 26),
          SizedBox(width: 8),
          Text('Pembaruan tersedia'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versi ${info.latestVersion} sudah tersedia. '
            'HP ini memakai versi ${info.currentVersion}.',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Setelah selesai diunduh, buka file APK-nya untuk memasang '
              'pembaruan. Data toko Anda tidak akan hilang.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.infoMid,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Nanti'),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            Navigator.pop(dialogContext);
            try {
              await launchUrl(
                Uri.parse(info.downloadUrl),
                mode: LaunchMode.externalApplication,
              );
            } catch (_) {
              // Kalau gagal membuka browser, diamkan saja — pengguna bisa
              // memakai tombol Cek Pembaruan di layar Profil nanti.
            }
          },
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Unduh'),
        ),
      ],
    ),
  );
}
