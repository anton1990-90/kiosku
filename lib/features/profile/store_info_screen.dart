import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/store_logo_service.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Info toko — nama, alamat, telepon, logo usaha, dan data pembayaran
/// non-tunai (gambar QRIS + rekening bank).
///
/// Gambar yang dipilih dari galeri disalin ke penyimpanan aplikasi, jadi tetap
/// ada walaupun foto aslinya dihapus dari galeri. Logo tampil di header
/// beranda & profil serta di struk; gambar QRIS dan data rekening muncul di
/// layar kasir saat pelanggan memilih bayar QRIS atau transfer bank.
class StoreInfoScreen extends ConsumerStatefulWidget {
  const StoreInfoScreen({super.key});

  @override
  ConsumerState<StoreInfoScreen> createState() => _StoreInfoScreenState();
}

class _StoreInfoScreenState extends ConsumerState<StoreInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankNumberController = TextEditingController();
  final _bankHolderController = TextEditingController();
  final _footerController = TextEditingController();

  String? _logoPath;
  String? _qrisPath;
  bool _saving = false;
  bool _pickingLogo = false;
  bool _pickingQris = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Isi kolom sekali saja, setelah data user tersedia.
    if (_initialized) return;
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _nameController.text = user.storeName;
    _addressController.text = user.storeAddress ?? '';
    _phoneController.text = user.storePhone ?? '';
    _bankNameController.text = user.bankName ?? '';
    _bankNumberController.text = user.bankAccountNumber ?? '';
    _bankHolderController.text = user.bankAccountName ?? '';
    // Kosong berarti pemilik belum pernah mengubahnya; struk memakai teks
    // bawaan selama kolom ini kosong.
    _footerController.text = user.receiptFooter ?? '';
    _logoPath = user.logoPath;
    _qrisPath = user.qrisPath;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _bankNameController.dispose();
    _bankNumberController.dispose();
    _bankHolderController.dispose();
    _footerController.dispose();
    super.dispose();
  }

  /// Nama toko yang dipakai saat menyimpan gambar, supaya tidak ikut kosong
  /// kalau pengguna belum mengetik apa pun di kolom nama.
  String get _namaToko {
    final diketik = _nameController.text.trim();
    if (diketik.isNotEmpty) return diketik;
    return ref.read(authProvider).user?.storeName ?? 'Toko Saya';
  }

  void _pesan(String teks, {bool sukses = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        behavior: SnackBarBehavior.floating,
        backgroundColor: sukses ? AppColors.successMid : AppColors.danger,
      ),
    );
  }

  Future<void> _pickLogo() async {
    setState(() => _pickingLogo = true);
    try {
      final path = await StoreLogoService.instance.pickAndSaveLogo();
      if (!mounted || path == null) return;
      setState(() => _logoPath = path);
      // Simpan langsung supaya logo terlihat di header tanpa harus menekan
      // tombol Simpan lebih dulu.
      await ref.read(authProvider.notifier).updateStore(
            storeName: _namaToko,
            storeAddress: _addressController.text,
            storePhone: _phoneController.text,
            logoPath: path,
          );
    } catch (_) {
      _pesan('Gagal memuat gambar. Coba pilih gambar lain.', sukses: false);
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    await StoreLogoService.instance.deleteLogo();
    await ref.read(authProvider.notifier).updateStore(
          storeName: _namaToko,
          storeAddress: _addressController.text,
          storePhone: _phoneController.text,
          logoPath: '',
        );
    if (mounted) setState(() => _logoPath = null);
  }

  Future<void> _pickQris() async {
    setState(() => _pickingQris = true);
    try {
      final path = await StoreLogoService.instance.pickAndSaveQris();
      if (!mounted || path == null) return;
      setState(() => _qrisPath = path);
      await ref.read(authProvider.notifier).updateStore(
            storeName: _namaToko,
            storeAddress: _addressController.text,
            storePhone: _phoneController.text,
            qrisPath: path,
          );
      _pesan('Gambar QRIS tersimpan');
    } catch (_) {
      _pesan('Gagal memuat gambar QRIS. Coba pilih gambar lain.', sukses: false);
    } finally {
      if (mounted) setState(() => _pickingQris = false);
    }
  }

  Future<void> _removeQris() async {
    await StoreLogoService.instance.deleteQris();
    await ref.read(authProvider.notifier).updateStore(
          storeName: _namaToko,
          storeAddress: _addressController.text,
          storePhone: _phoneController.text,
          qrisPath: '',
        );
    if (mounted) setState(() => _qrisPath = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ok = await ref.read(authProvider.notifier).updateStore(
          storeName: _nameController.text.trim(),
          storeAddress: _addressController.text,
          storePhone: _phoneController.text,
          logoPath: _logoPath,
          qrisPath: _qrisPath,
          bankName: _bankNameController.text,
          bankAccountNumber: _bankNumberController.text,
          bankAccountName: _bankHolderController.text,
          receiptFooter: _footerController.text,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    _pesan(
      ok ? 'Info toko disimpan' : 'Gagal menyimpan info toko',
      sukses: ok,
    );

    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Info Toko')),
      body: Form(
        key: _formKey,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Logo usaha
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickingLogo ? null : _pickLogo,
                      child: Stack(
                        children: [
                          StoreAvatar(
                            logoPath: _logoPath,
                            initials: user?.initials ?? 'TS',
                            radius: 48,
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.bgPage,
                                  width: 2.5,
                                ),
                              ),
                              child: _pickingLogo
                                  ? const Padding(
                                      padding: EdgeInsets.all(7),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt,
                                      size: 15, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _pickingLogo ? null : _pickLogo,
                      icon: const Icon(Icons.photo_library_outlined, size: 16),
                      label: const Text('Ganti logo usaha'),
                    ),
                    if (_logoPath != null)
                      TextButton(
                        onPressed: _removeLogo,
                        child: const Text(
                          'Hapus logo',
                          style: TextStyle(color: AppColors.danger),
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'Logo ini tampil di beranda, halaman profil, dan struk.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama usaha',
                  hintText: 'Contoh: Toko Sembako Berkah',
                  prefixIcon: Icon(Icons.store_outlined,
                      color: AppColors.textTertiary),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP / WhatsApp toko (opsional)',
                  prefixIcon:
                      Icon(Icons.phone_outlined, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Alamat toko (opsional)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.location_on_outlined,
                      color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Nama dan alamat toko ikut tercetak di struk pembelian '
                  'pelanggan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.infoMid,
                    height: 1.5,
                  ),
                ),
              ),

              // ------------------------------------------------ ucapan struk
              const SizedBox(height: 16),
              TextFormField(
                controller: _footerController,
                // Struk termal 58mm hanya memuat sekitar 32 karakter per baris.
                // Dibatasi 100 karakter supaya ucapan tetap terbaca utuh, bukan
                // terpotong di tengah kalimat.
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Ucapan penutup di struk (opsional)',
                  hintText: 'Contoh: Terima kasih, semoga puas!',
                  helperText: 'Dicetak di bagian bawah struk. Biarkan kosong '
                      'untuk memakai ucapan bawaan.',
                  helperMaxLines: 3,
                  prefixIcon: Icon(Icons.receipt_long_outlined,
                      color: AppColors.textTertiary),
                ),
              ),

              // ------------------------------------------ pembayaran non-tunai
              const SizedBox(height: 28),
              const Text(
                'Pembayaran QRIS & transfer bank',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Diisi sekali saja. Saat pelanggan memilih bayar QRIS atau '
                'transfer di kasir, gambar QRIS dan nomor rekening di bawah ini '
                'otomatis muncul supaya bisa langsung ditunjukkan.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),

              // Gambar QRIS
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gambar QRIS toko',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (_qrisPath != null)
                      Center(
                        child: GestureDetector(
                          onTap: _pickingQris ? null : _pickQris,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Image.file(
                              File(_qrisPath!),
                              height: 180,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 80,
                                child: Center(
                                  child: Text(
                                    'Gambar tidak bisa dibuka',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.bgSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.qr_code_2,
                                size: 28, color: AppColors.textTertiary),
                            SizedBox(height: 6),
                            Text(
                              'Belum ada gambar QRIS',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickingQris ? null : _pickQris,
                            icon: _pickingQris
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.add_photo_alternate_outlined,
                                    size: 16),
                            label: Text(
                              _qrisPath == null
                                  ? 'Pilih gambar QRIS'
                                  : 'Ganti gambar QRIS',
                            ),
                          ),
                        ),
                        if (_qrisPath != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _removeQris,
                            child: const Text(
                              'Hapus',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Pakai gambar QRIS asli dari bank/e-wallet Anda. Pilih '
                      'gambar yang jelas supaya pelanggan mudah memindainya.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Rekening bank
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rekening bank tujuan transfer',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bankNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nama bank (opsional)',
                        hintText: 'Contoh: BCA / BRI / Mandiri',
                        prefixIcon: Icon(Icons.account_balance_outlined,
                            color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bankNumberController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nomor rekening (opsional)',
                        hintText: 'Contoh: 1234567890',
                        prefixIcon: Icon(Icons.numbers_outlined,
                            color: AppColors.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _bankHolderController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Atas nama (opsional)',
                        hintText: 'Contoh: Budi Santoso',
                        prefixIcon: Icon(Icons.person_outline,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Simpan Info Toko'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
