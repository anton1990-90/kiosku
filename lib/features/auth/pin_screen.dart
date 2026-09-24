import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pin_provider.dart';
import '../../shared/services/pin_service.dart';

/// Layar PIN — pintu masuk harian aplikasi.
///
/// Sejak v1.20.0 PIN milik akun, jadi layar ini **menggantikan** layar masuk
/// untuk pemakaian sehari-hari: PIN yang diketik menentukan siapa yang masuk,
/// bukan sekadar membuka kunci perangkat. Akun yang belum memasang PIN tetap
/// masuk lewat email & kata sandi, dan jalan itu disediakan tombol "Lupa PIN?".
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
  String? _error;

  /// Jumlah titik yang ditampilkan.
  ///
  /// PIN tiap akun bisa 4–6 angka, jadi jumlah titik TIDAK bisa dipakai untuk
  /// menebak kapan PIN-nya selesai. Dulu panjangnya tersimpan di perangkat dan
  /// layar ini membuka kuncinya sendiri begitu jumlah angkanya pas; sekarang
  /// panjang itu milik masing-masing akun, dan membocorkannya lewat tampilan
  /// berarti memberi tahu penebak berapa angka yang harus dia coba. Satu titik
  /// kosong selalu disisakan sebagai "posisi berikutnya".
  int get _jumlahTitik {
    final perlu = _pin.length + 1;
    if (perlu < PinService.panjangMin) return PinService.panjangMin;
    if (perlu > PinService.panjangMaks) return PinService.panjangMaks;
    return perlu;
  }

  /// Tombol "Buka" baru boleh ditekan kalau panjangnya sudah masuk akal.
  bool get _bolehBuka => _pin.length >= PinService.panjangMin;

  void _ketik(String angka) {
    if (_sibuk || _pin.length >= PinService.panjangMaks) return;
    setState(() {
      _error = null;
      _pin += angka;
    });
  }

  void _hapus() {
    if (_sibuk || _pin.isEmpty) return;
    setState(() {
      _error = null;
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  /// Coba buka dengan PIN yang sudah diketik.
  ///
  /// Tidak ada pembukaan otomatis: yang memutuskan kapan PIN selesai adalah
  /// pemakainya, lewat tombol "Buka". Dengan PIN per akun, panjangnya berbeda
  /// antar akun, jadi layar ini tidak punya cara tahu kapan berhenti — dan
  /// menebak terlalu cepat akan mengirim PIN yang belum selesai.
  Future<void> _buka() async {
    if (_sibuk || !_bolehBuka) return;
    setState(() => _sibuk = true);

    final keluhan = await ref.read(authProvider.notifier).masukDenganPin(_pin);
    if (!mounted) return;

    setState(() {
      _sibuk = false;
      _error = keluhan;
      // PIN salah: kosongkan supaya bisa dicoba lagi dari awal.
      if (keluhan != null) _pin = '';
    });
  }

  /// Jalan keluar kalau PIN lupa: masuk dengan email & password.
  Future<void> _lupaPin() async {
    final lanjut = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lupa PIN?'),
        content: const Text(
          'Masuk dengan email dan password akun Anda.\n\n'
          'Setelah berhasil masuk, PIN tidak ditanyakan lagi. PIN akun Anda '
          'sendiri tidak berubah; atur atau gantinya di menu Profil → PIN '
          'akun.\n\n'
          'Kalau passwordnya juga lupa, pilih "Lupa password?" di layar masuk.',
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

    // Sesinya diputus LEBIH DULU, baru gerbangnya dibuka. Urutan ini yang
    // menjaga: membuka gerbang tanpa memutus sesi akan melempar pengguna
    // langsung ke beranda — melewati email & kata sandi sama sekali.
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    ref.read(pinProvider.notifier).bukaUntukMasukManual();
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(height: 6),
              Text(
                namaToko.isNotEmpty ? namaToko : 'PIN akun Anda',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              _titikPin(),
              const SizedBox(height: 14),
              SizedBox(
                height: 20,
                child: _error == null
                    ? null
                    : Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 18),
              _papanAngka(),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_sibuk || !_bolehBuka) ? null : _buka,
                  child: _sibuk
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Buka'),
                ),
              ),
              const SizedBox(height: 6),
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

  /// Deretan titik: satu titik per angka yang sudah diketik, plus satu titik
  /// kosong sebagai posisi berikutnya.
  Widget _titikPin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_jumlahTitik, (i) {
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
