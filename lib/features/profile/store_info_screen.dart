import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/store_logo_service.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Info toko — nama, alamat, telepon, dan logo usaha.
///
/// Logo yang dipilih dari galeri disalin ke penyimpanan aplikasi, jadi tetap
/// ada walaupun foto aslinya dihapus dari galeri. Logo ini otomatis muncul di
/// header beranda dan profil, serta dipakai pada struk.
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

  String? _logoPath;
  bool _saving = false;
  bool _pickingLogo = false;
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
    _logoPath = user.logoPath;
    _initialized = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
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
            storeName: _nameController.text.trim().isEmpty
                ? (ref.read(authProvider).user?.storeName ?? 'Toko Saya')
                : _nameController.text.trim(),
            storeAddress: _addressController.text,
            storePhone: _phoneController.text,
            logoPath: path,
          );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memuat gambar. Coba pilih gambar lain.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _pickingLogo = false);
    }
  }

  Future<void> _removeLogo() async {
    await StoreLogoService.instance.deleteLogo();
    await ref.read(authProvider.notifier).updateStore(
          storeName: _nameController.text.trim().isEmpty
              ? (ref.read(authProvider).user?.storeName ?? 'Toko Saya')
              : _nameController.text.trim(),
          storeAddress: _addressController.text,
          storePhone: _phoneController.text,
          logoPath: '',
        );
    if (mounted) setState(() => _logoPath = null);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final ok = await ref.read(authProvider.notifier).updateStore(
          storeName: _nameController.text.trim(),
          storeAddress: _addressController.text,
          storePhone: _phoneController.text,
          logoPath: _logoPath,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Info toko disimpan' : 'Gagal menyimpan info toko'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: ok ? AppColors.successMid : AppColors.danger,
      ),
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
        child: ListView(
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
    );
  }
}
