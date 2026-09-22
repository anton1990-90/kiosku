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
/// Muncul sebelum login/register. Pelanggan membeli Kode Voucher, lalu
/// menempelkannya di sini — atau membukanya lewat portal di browser dan
/// menempelkan Kode Aktivasi yang diterima. Dua-duanya jalan tanpa perlu
/// menghubungi penjual.
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

  Future<void> _bukaLink(String alamat) async {
    final uri = Uri.tryParse(alamat);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak bisa membuka $alamat'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _bukaPortal() async {
    if (!AppConfig.isActivationConfigured) return;
    await _bukaLink(AppConfig.portalUrl);
  }

  Future<void> _openWhatsApp() async {
    if (AppConfig.sellerWhatsApp.isEmpty) return;
    final text = Uri.encodeComponent(
      'Halo, saya mau aktivasi aplikasi TokoKu.\n'
      'Kode Perangkat saya: $_deviceId',
    );
    await _bukaLink('https://wa.me/${AppConfig.sellerWhatsApp}?text=$text');
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
                'Aplikasi ini berlisensi satu perangkat. Masukkan Kode Voucher '
                'yang Anda beli di kolom bawah, lalu tekan Aktivasi.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 20),
              if (!AppConfig.isActivationConfigured) ...[
                _kotakGalat(
                  'Server aktivasi belum diisi di lib/core/config/app_config.dart. '
                  'Aktivasi tidak akan bisa diproses.',
                ),
                const SizedBox(height: 16),
              ],
              _langkahCara(),
              const SizedBox(height: 20),
              _deviceCodeCard(),
              const SizedBox(height: 24),
              const Text(
                'Kode Voucher / Kode Aktivasi',
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
                  hintText: 'VC-XXXX-XXXX-XXXX',
                  filled: true,
                  fillColor: AppColors.bgCard,
                  prefixIcon: const Icon(Icons.key_outlined,
                      color: AppColors.textTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Awalan VC- untuk kode yang Anda beli, AK- untuk kode dari portal.',
                style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                _kotakGalat(_error!),
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
              if (AppConfig.isActivationConfigured) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _bukaPortal,
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Buka Portal Aktivasi'),
                  ),
                ),
              ],
              if (AppConfig.sellerWhatsApp.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: _busy ? null : _openWhatsApp,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Butuh bantuan? Chat penjual'),
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

  Widget _kotakGalat(String isi) {
    return Container(
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
              isi,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.dangerMid,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _langkahCara() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Cara aktivasi',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          SizedBox(height: 10),
          _Langkah(1, 'Salin Kode Perangkat di kotak hijau bawah.'),
          _Langkah(2, 'Masukkan Kode Voucher dari penjual, lalu tekan Aktivasi.'),
          _Langkah(
            3,
            'Belum punya Kode Voucher? Tekan Buka Portal Aktivasi untuk '
            'membeli dan menukarnya sendiri.',
          ),
        ],
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
            'Kode ini tetap sama selama aplikasi tidak diinstal ulang. '
            'Dibutuhkan kalau Anda mengaktifkan lewat portal.',
            style: TextStyle(fontSize: 11, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

/// Satu baris langkah bernomor di kotak "Cara aktivasi".
class _Langkah extends StatelessWidget {
  final int nomor;
  final String teks;

  const _Langkah(this.nomor, this.teks);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$nomor',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
