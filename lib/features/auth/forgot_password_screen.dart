import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/license_provider.dart';

/// Layar "Lupa password".
///
/// Aplikasi ini bekerja offline dan belum bisa mengirim email, jadi pemulihan
/// tidak lewat tautan email melainkan lewat **kode aktivasi** — kode yang
/// pemilik toko terima saat membeli dan sudah tertanam di HP ini.
///
/// Kenapa kode aktivasi:
///   * Kode itu hanya bisa dipakai di HP ini (terkunci ke kode perangkat), jadi
///     memilikinya adalah bukti bahwa orang ini memang pemilik lisensinya.
///   * Pemeriksaannya dilakukan **di dalam HP**, bukan ke server, sehingga
///     pemulihan tetap bisa dilakukan tanpa internet — justru saat paling
///     dibutuhkan.
///
/// Password TIDAK bisa diganti tanpa kode ini. Kalau bisa, siapa pun yang
/// memegang HP dapat membuka data usaha pemiliknya.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _kodeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _ulangiController = TextEditingController();

  bool _sibuk = false;
  bool _obscure = true;
  String? _pesan;

  @override
  void dispose() {
    _emailController.dispose();
    _kodeController.dispose();
    _passwordController.dispose();
    _ulangiController.dispose();
    super.dispose();
  }

  /// Mengembalikan pesan kesalahan, atau `null` kalau password berhasil
  /// diganti.
  Future<String?> _pasangUlang() async {
    final lisensi = ref.read(licenseProvider).license;
    if (lisensi == null) {
      return 'Aplikasi ini belum diaktivasi, jadi kode aktivasi belum bisa '
          'dipakai untuk memulihkan password. Hubungi penjual aplikasi.';
    }

    // Dibandingkan tanpa membedakan huruf besar/kecil dan spasi di ujung,
    // supaya salah ketik sepele tidak membuat pemilik mengira kodenya salah.
    final diketik = _kodeController.text.trim().toUpperCase();
    if (diketik != lisensi.code.toUpperCase()) {
      return 'Kode aktivasi tidak cocok dengan lisensi yang terpasang di HP '
          'ini. Periksa kembali penulisannya.';
    }

    final berhasil = await ref.read(authProvider.notifier).resetPassword(
          email: _emailController.text.trim(),
          newPassword: _passwordController.text,
        );
    if (!berhasil) {
      return 'Email itu tidak terdaftar di HP ini. Periksa kembali '
          'penulisannya.';
    }
    return null;
  }

  Future<void> _kirim() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sibuk = true;
      _pesan = null;
    });

    final masalah = await _pasangUlang();
    if (!mounted) return;
    setState(() {
      _sibuk = false;
      _pesan = masalah;
    });
    if (masalah != null) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Password berhasil diganti'),
        content: const Text(
          'Silakan masuk memakai password baru Anda.\n\n'
          'PIN Anda tidak berubah. Kalau PIN juga lupa, cukup masuk dengan '
          'email dan password baru — kuncinya terbuka sendiri.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Masuk'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Lupa password'),
        backgroundColor: AppColors.bgPage,
        foregroundColor: AppColors.textMain,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _penjelasan(),
              const SizedBox(height: 20),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email akun toko',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email tidak boleh kosong';
                        }
                        if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$')
                            .hasMatch(value.trim())) {
                          return 'Format email tidak valid';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _kodeController,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Kode aktivasi',
                        hintText: 'AK-XXXX-XXXX-XXXX',
                        prefixIcon: Icon(Icons.verified_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Kode aktivasi tidak boleh kosong';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Password baru',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure ? Icons.visibility_off : Icons.visibility,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password tidak boleh kosong';
                        }
                        if (value.length < 6) {
                          return 'Password minimal 6 karakter';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _ulangiController,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Ulangi password baru',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Kedua password belum sama';
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) {
                        if (!_sibuk) _kirim();
                      },
                    ),
                  ],
                ),
              ),
              if (_pesan != null) ...[
                const SizedBox(height: 18),
                _kotakPesan(_pesan!),
              ],
              const SizedBox(height: 28),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _sibuk ? null : _kirim,
                  child: _sibuk
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Pasang password baru'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _penjelasan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.info.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.infoMid, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Pulihkan dengan kode aktivasi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.infoMid,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Masukkan kode aktivasi yang Anda terima saat membeli '
                  'aplikasi ini (berawalan AK-). Kode itu juga tampil di menu '
                  'Profil → Lisensi setelah Anda masuk.\n\n'
                  'Lupa kodenya? Hubungi penjual aplikasi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.infoMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakPesan(String pesan) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.danger,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
