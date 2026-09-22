import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/license_provider.dart';
import '../../shared/services/device_service.dart';

/// Layar aktivasi lisensi.
///
/// Muncul sebelum login/register. Pengguna menyalin Kode Perangkat, mengirimnya
/// ke penjual, lalu memasukkan Kode Aktivasi yang diterima. Setelah berhasil,
/// aplikasi berjalan offline selamanya.
class ActivationScreen extends ConsumerStatefulWidget {
  const ActivationScreen({super.key});

  @override
  ConsumerState<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends ConsumerState<ActivationScreen> {
  final _codeController = TextEditingController();
  String _deviceId = 'menghitung...';
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final id = await DeviceService.instance.getDeviceId();
    if (mounted) setState(() => _deviceId = id);
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _copyDeviceId() async {
    await Clipboard.setData(ClipboardData(text: _deviceId));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kode Perangkat disalin'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    if (AppConfig.sellerWhatsApp.isEmpty) return;
    final text = Uri.encodeComponent(
      'Halo, saya mau aktivasi aplikasi TokoKu.\n'
      'Kode Perangkat saya: $_deviceId',
    );
    try {
      await launchUrl(
        Uri.parse('https://wa.me/${AppConfig.sellerWhatsApp}?text=$text'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Diabaikan — pengguna masih bisa menyalin kode secara manual.
    }
  }

  Future<void> _activate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref
        .read(licenseProvider.notifier)
        .activate(_codeController.text);

    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Aktivasi Aplikasi',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Aplikasi ini berlisensi satu perangkat. Kirim Kode Perangkat di '
                'bawah ke penjual, lalu masukkan Kode Aktivasi yang Anda terima.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              if (!AppConfig.isActivationConfigured) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Server aktivasi belum diisi di lib/core/config/app_config.dart. '
                    'Aktivasi tidak akan bisa diproses.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.dangerMid,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _deviceCodeCard(),
              const SizedBox(height: 24),
              const Text(
                'Kode Aktivasi',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                enabled: !_busy,
                onSubmitted: (_) {
                  if (!_busy) _activate();
                },
                decoration: InputDecoration(
                  hintText: 'TK-XXXX-XXXX-XXXX',
                  filled: true,
                  fillColor: AppColors.bgCard,
                  prefixIcon: const Icon(Icons.key_outlined,
                      color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.dangerMid, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.dangerMid,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : _activate,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Aktivasi'),
                ),
              ),
              if (AppConfig.sellerWhatsApp.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Kirim Kode Perangkat ke Penjual'),
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _deviceCodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kode Perangkat HP ini',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  _deviceId,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              IconButton(
                onPressed: _copyDeviceId,
                icon: const Icon(Icons.copy, size: 18),
                color: AppColors.primary,
                tooltip: 'Salin',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Kode ini tetap sama selama aplikasi tidak diinstal ulang.',
            style: TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
