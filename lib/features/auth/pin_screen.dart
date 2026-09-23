import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pin_provider.dart';
import '../../shared/services/pin_service.dart';

/// Layar kunci PIN.
///
/// Dipakai sebagai pengganti mengetik email & password setiap hari. Karena
/// aplikasi mengunci diri saat dibuka (lihat [PinNotifier]), layar ini muncul
/// lebih dulu daripada beranda.
///
/// Papan angkanya dibuat sendiri, tidak memakai keyboard bawaan Android,
/// supaya seluruh layar terlihat sekaligus dan tidak tertutup keyboard.
class PinScreen extends ConsumerStatefulWidget {
  const PinScreen({super.key});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  bool _sibuk = false;

  /// Panjang PIN yang dipasang pemilik toko (4–6). Dipakai untuk membuka
  /// kunci otomatis begitu jumlah angkanya sudah pas.
  int _panjang = PinService.panjangMin;

  @override
  void initState() {
    super.initState();
    _muatPanjang();
  }

  Future<void> _muatPanjang() async {
    final p = await PinService.instance.panjang;
    if (!mounted) return;
    setState(() => _panjang = p);
  }

  void _ketik(String angka) {
    if (_sibuk || _pin.length >= _panjang) return;
    ref.read(pinProvider.notifier).bersihkanError();
    setState(() => _pin += angka);
    // Begitu jumlahnya pas, langsung dicoba — tidak perlu menekan tombol.
    if (_pin.length == _panjang) _buka();
  }

  void _hapus() {
    if (_sibuk || _pin.isEmpty) return;
    ref.read(pinProvider.notifier).bersihkanError();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _buka() async {
    setState(() => _sibuk = true);
    final benar = await ref.read(pinProvider.notifier).buka(_pin);
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      // PIN salah: kosongkan supaya bisa dicoba lagi dari awal.
      if (!benar) _pin = '';
    });
  }

  /// Jalan keluar kalau PIN lupa: masuk dengan email & password.
  Future<void> _lupaPin() async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa PIN?'),
        content: const Text(
          'Untuk membuka, Anda perlu masuk dengan email dan password akun toko.\n\n'
          'Setelah berhasil masuk, ganti PIN di menu Profil → Kunci PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Masuk dengan email'),
          ),
        ],
      ),
    );

    if (lanjut != true || !mounted) return;

    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final pinState = ref.watch(pinProvider);
    final namaToko = ref.watch(authProvider).user?.storeName ?? '';

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 48),
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppColors.primary,
                  size: 38,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Masukkan PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                  letterSpacing: -0.3,
                ),
              ),
              if (namaToko.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  namaToko,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _titikPin(),
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: pinState.error == null
                    ? null
                    : Text(
                        pinState.error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              _papanAngka(),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _sibuk ? null : _lupaPin,
                child: const Text(
                  'Lupa PIN?',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  /// Deretan titik: satu titik per angka PIN, terisi seiring diketik.
  Widget _titikPin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_panjang, (i) {
        final terisi = i < _pin.length;
        return Container(
          width: 15,
          height: 15,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: terisi ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: terisi ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
          ),
        );
      }),
    );
  }

  Widget _papanAngka() {
    const baris = <List<String>>[
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'hapus'],
    ];

    return Column(
      children: [
        for (final isiBaris in baris)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final label in isiBaris)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: _tombol(label),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tombol(String label) {
    // Slot kosong di kiri bawah, supaya angka 0 tetap di tengah.
    if (label.isEmpty) {
      return const SizedBox(width: 70, height: 70);
    }

    final tombolHapus = label == 'hapus';

    // Warna diletakkan di `Material`, bukan di dalam anaknya — kalau tidak,
    // efek sentuh (ripple) hilang.
    return SizedBox(
      width: 70,
      height: 70,
      child: Material(
        color: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(35),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _sibuk ? null : (tombolHapus ? _hapus : () => _ketik(label)),
          child: Center(
            child: tombolHapus
                ? const Icon(
                    Icons.backspace_outlined,
                    size: 22,
                    color: AppColors.textSecondary,
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
