import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pin_provider.dart';
import '../../providers/user_provider.dart';
import '../../shared/services/pin_service.dart';

/// Pengguna — pengelolaan akun toko: pemilik dan kasir.
///
/// Hanya pemilik toko yang bisa membuka layar ini. Menunya memang tidak
/// ditampilkan untuk kasir, tetapi yang benar-benar menjaga adalah router:
/// alamat `/profile/pengguna` ditolak untuk kasir, jadi menyembunyikan menu
/// bukan satu-satunya penjagaan.
///
/// Dua aturan membentuk layar ini:
///
///   * **Akun tidak dihapus, hanya dinonaktifkan.** `sales.user_id` menunjuk ke
///     akun, jadi nota lama harus tetap punya pemiliknya. Karena itu tidak ada
///     menu "Hapus" di sini — menggantinya adalah "Nonaktifkan".
///   * **Harus selalu ada satu pemilik aktif.** Kalau pemilik aktif terakhir
///     diturunkan menjadi kasir atau dinonaktifkan, tidak ada seorang pun yang
///     bisa membuka layar ini lagi. Repositori menolaknya; layar ini
///     menampilkan jumlah pemilik aktif supaya pemilik toko tahu alasannya
///     sebelum tombolnya menolak, bukan sesudahnya.
class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({super.key});

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(userProvider);
    final sayaId = ref.watch(authProvider).user?.id;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Pengguna')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaTambah,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah akun'),
      ),
      body: state.users.isEmpty && state.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _kartuPeran(state.pemilikAktif),
                const SizedBox(height: 14),
                for (final akun in state.users) _kartuAkun(akun, sayaId),
              ],
            ),
    );
  }

  // ------------------------------------------------------------------ kartu

  /// Ringkasan peran — sekaligus peringatan.
  ///
  /// Jumlah pemilik aktif ditampilkan terus, bukan hanya saat sudah kritis:
  /// pemilik toko perlu tahu bahwa dirinya satu-satunya SEBELUM mencoba
  /// menonaktifkan diri sendiri, supaya penolakannya tidak terasa seperti
  /// kesalahan aplikasi.
  Widget _kartuPeran(int pemilikAktif) {
    final kritis = pemilikAktif <= 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kritis ? AppColors.warningLight : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                kritis ? Icons.info_outline : Icons.verified_user_outlined,
                size: 18,
                color: kritis ? AppColors.warningMid : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '$pemilikAktif pemilik aktif',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Pemilik toko melihat semuanya: laba, laporan keuangan, pengaturan, '
            'dan layar ini. Kasir melayani penjualan, mencatat hutang dan kas, '
            'tetapi tidak melihat laba maupun pengaturan toko.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          if (kritis) ...[
            const SizedBox(height: 8),
            const Text(
              'Karena hanya ada satu pemilik aktif, akun ini tidak bisa '
              'dinonaktifkan atau diturunkan menjadi kasir. Angkat pemilik lain '
              'lebih dulu kalau memang perlu.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.warningMid,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kartuAkun(UserModel akun, int? sayaId) {
    final iniSaya = akun.id != null && akun.id == sayaId;
    final punyaPin = akun.pinHash != null && akun.pinHash!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: akun.isOwner ? AppColors.primaryLight : AppColors.bgSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              akun.isOwner
                  ? Icons.verified_user_outlined
                  : Icons.point_of_sale_outlined,
              size: 20,
              color: akun.isOwner
                  ? AppColors.primaryDark
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        akun.email,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (iniSaya)
                      const Text(
                        '  (Anda)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _lencana(
                      akun.roleLabel,
                      akun.isOwner ? AppColors.primaryLight : AppColors.bgSoft,
                      akun.isOwner
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                    _lencana(
                      akun.isActive ? 'Aktif' : 'Nonaktif',
                      akun.isActive
                          ? AppColors.successLight
                          : AppColors.dangerLight,
                      akun.isActive
                          ? AppColors.successMid
                          : AppColors.dangerMid,
                    ),
                    // Status PIN ditampilkan di kartu, bukan hanya di menu:
                    // pemilik toko perlu tahu akun mana yang belum punya PIN
                    // tanpa membuka menunya satu per satu.
                    _lencana(
                      punyaPin ? 'PIN aktif' : 'Tanpa PIN',
                      punyaPin ? AppColors.infoLight : AppColors.bgSoft,
                      punyaPin ? AppColors.infoMid : AppColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Dibuat ${Formatters.date(akun.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert,
                size: 18, color: AppColors.textSecondary),
            onSelected: (nilai) => _menuAkun(nilai, akun),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'peran',
                child: Text(
                  akun.isOwner ? 'Jadikan kasir' : 'Jadikan pemilik',
                ),
              ),
              PopupMenuItem(
                value: 'aktif',
                child: Text(akun.isActive ? 'Nonaktifkan' : 'Aktifkan'),
              ),
              const PopupMenuItem(
                value: 'password',
                child: Text('Ganti password'),
              ),
              // Pemilik toko mengatur PIN kasirnya: kasir yang baru dipasangkan
              // biasanya belum sempat mengatur PIN sendiri, dan tanpa ini
              // satu-satunya jalan adalah meminjamkan HP-nya.
              PopupMenuItem(
                value: 'pin',
                child: Text(punyaPin ? 'Ganti PIN' : 'Atur PIN'),
              ),
              if (punyaPin)
                const PopupMenuItem(
                  value: 'hapus-pin',
                  child: Text('Hapus PIN'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _lencana(String teks, Color latar, Color warna) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: warna,
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ aksi

  Future<void> _menuAkun(String nilai, UserModel akun) async {
    final id = akun.id;
    if (id == null) return;

    switch (nilai) {
      case 'peran':
        final peranBaru = akun.isOwner ? UserRole.kasir : UserRole.owner;
        final yakin = await _konfirmasi(
          judul: akun.isOwner ? 'Jadikan kasir?' : 'Jadikan pemilik?',
          isi: akun.isOwner
              ? '"${akun.email}" tidak akan bisa membuka laporan, pengaturan, '
                  'dan layar Pengguna lagi.'
              : '"${akun.email}" akan melihat semuanya, termasuk laba, laporan '
                  'keuangan, dan pengelolaan akun.',
        );
        if (yakin != true) return;
        await _jalankan(
          () => ref.read(userProvider.notifier).ubahPeran(id, peranBaru),
          'Peran ${akun.email} diubah.',
        );

      case 'aktif':
        if (akun.isActive) {
          final yakin = await _konfirmasi(
            judul: 'Nonaktifkan akun?',
            isi: '"${akun.email}" tidak akan bisa masuk lagi.\n\n'
                'Akunnya TIDAK dihapus: nota dan transaksi yang pernah '
                'dibuatnya tetap tersimpan dan tetap terbaca di laporan.',
          );
          if (yakin != true) return;
        }
        await _jalankan(
          () => ref.read(userProvider.notifier).ubahStatus(id, !akun.isActive),
          akun.isActive
              ? 'Akun ${akun.email} dinonaktifkan.'
              : 'Akun ${akun.email} diaktifkan kembali.',
        );

      case 'password':
        await _bukaGantiPassword(akun);

      case 'pin':
        await _bukaAturPin(akun);

      case 'hapus-pin':
        final yakin = await _konfirmasi(
          judul: 'Hapus PIN akun ini?',
          isi: '"${akun.email}" tidak akan bisa masuk dengan PIN lagi.\n\n'
              'Akun itu tetap bisa masuk memakai email dan password.',
        );
        if (yakin != true) return;
        await ref.read(pinProvider.notifier).hapus(id);
        if (!mounted) return;
        // Daftar akun dibaca ulang supaya lencana PIN-nya ikut berubah —
        // `pinHash` disalin saat daftar dimuat, jadi tanpa ini kartunya masih
        // menampilkan "PIN aktif" untuk akun yang PIN-nya baru saja dihapus.
        await ref.read(userProvider.notifier).muat();
        if (!mounted) return;
        _pesan('PIN ${akun.email} dihapus.');
    }
  }

  /// Menjalankan aksi lalu menampilkan pesannya.
  ///
  /// Pesan penolakan datang dari repositori — misalnya "harus selalu ada satu
  /// pemilik aktif" — dan sudah ditulis dalam bahasa Indonesia, jadi
  /// ditampilkan apa adanya. Menggantinya dengan "gagal" akan menyembunyikan
  /// satu-satunya penjelasan yang berguna bagi pemilik toko.
  Future<void> _jalankan(
    Future<bool> Function() aksi,
    String pesanSukses,
  ) async {
    final berhasil = await aksi();
    if (!mounted) return;

    final pesan = berhasil
        ? pesanSukses
        : (ref.read(userProvider).error ?? 'Perubahan tidak tersimpan.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pesan),
        behavior: SnackBarBehavior.floating,
        backgroundColor: berhasil ? null : AppColors.danger,
      ),
    );
  }

  Future<bool?> _konfirmasi({required String judul, required String isi}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(judul),
        content: Text(isi),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjut'),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaTambah() async {
    final formKey = GlobalKey<FormState>();
    final email = TextEditingController();
    final password = TextEditingController();
    var peran = UserRole.kasir;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Akun baru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: email,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email untuk masuk',
                    ),
                    validator: (v) {
                      final teks = (v ?? '').trim();
                      if (teks.isEmpty) return 'Wajib diisi';
                      if (!teks.contains('@')) return 'Email belum lengkap';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password (minimal 6 karakter)',
                    ),
                    validator: (v) =>
                        (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    value: peran,
                    decoration: const InputDecoration(labelText: 'Peran'),
                    items: const [
                      DropdownMenuItem(
                        value: UserRole.kasir,
                        child: Text('Kasir — penjualan & kas'),
                      ),
                      DropdownMenuItem(
                        value: UserRole.owner,
                        child: Text('Pemilik — akses penuh'),
                      ),
                    ],
                    onChanged: (v) =>
                        setSheetState(() => peran = v ?? UserRole.kasir),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Akun baru memakai nama toko, logo, dan rekening yang sama '
                    'dengan toko ini.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        // Dibaca SEBELUM sheet ditutup: sesudah pop, controller
                        // di bawah sudah dibuang dan membacanya akan melempar.
                        final surel = email.text.trim();
                        final sandi = password.text;
                        Navigator.pop(sheetContext);
                        await _jalankan(
                          () => ref.read(userProvider.notifier).tambah(
                                email: surel,
                                password: sandi,
                                role: peran,
                              ),
                          'Akun $surel dibuat.',
                        );
                      },
                      child: const Text('Tambah'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    email.dispose();
    password.dispose();
  }

  Future<void> _bukaGantiPassword(UserModel akun) async {
    final id = akun.id;
    if (id == null) return;

    final formKey = GlobalKey<FormState>();
    final baru = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Ganti password ${akun.email}'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: baru,
            autofocus: true,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password baru (minimal 6 karakter)',
            ),
            validator: (v) =>
                (v ?? '').length < 6 ? 'Minimal 6 karakter' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final sandi = baru.text;
              Navigator.pop(dialogContext);
              await _jalankan(
                () => ref.read(userProvider.notifier).resetPassword(id, sandi),
                'Password ${akun.email} diganti.',
              );
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    baru.dispose();
  }

  /// Atur atau ganti PIN milik sebuah akun.
  ///
  /// Pemilik toko boleh mengatur PIN kasirnya — kasir yang baru dipasangkan
  /// biasanya belum sempat mengatur PIN-nya sendiri, dan tanpa ini satu-satunya
  /// jalan adalah meminjamkan HP pemilik.
  Future<void> _bukaAturPin(UserModel akun) async {
    final id = akun.id;
    if (id == null) return;

    final controller = TextEditingController();
    final ulangi = TextEditingController();
    String? masalah;
    String? pinSiap;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('PIN untuk ${akun.email}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PIN dipakai akun ini untuk masuk ke aplikasi, jadi pemakainya '
                'tidak perlu mengetik email dan password setiap hari.\n\n'
                '4–6 angka, dan tidak boleh sama dengan PIN akun lain.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: PinService.panjangMaks,
                decoration: const InputDecoration(
                  labelText: 'PIN baru',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ulangi,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: PinService.panjangMaks,
                decoration: const InputDecoration(
                  labelText: 'Ulangi PIN',
                  counterText: '',
                ),
              ),
              if (masalah != null) ...[
                const SizedBox(height: 10),
                Text(
                  masalah!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                final pin = controller.text.trim();
                final lagi = ulangi.text.trim();
                final keluhan = PinService.periksa(pin) ??
                    (pin != lagi ? 'Ulangi PIN tidak sama.' : null);
                if (keluhan != null) {
                  setDialogState(() => masalah = keluhan);
                  return;
                }
                pinSiap = pin;
                Navigator.pop(dialogContext);
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    controller.dispose();
    ulangi.dispose();

    if (pinSiap == null || !mounted) return;

    final keluhan = await ref.read(pinProvider.notifier).pasang(id, pinSiap!);
    if (!mounted) return;

    if (keluhan != null) {
      _pesan(keluhan, gagal: true);
      return;
    }
    // Daftar akun dibaca ulang supaya lencana PIN-nya ikut berubah.
    await ref.read(userProvider.notifier).muat();
    if (!mounted) return;
    _pesan('PIN ${akun.email} dipasang.');
  }

  /// Pesan singkat di bawah layar.
  void _pesan(String teks, {bool gagal = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        behavior: SnackBarBehavior.floating,
        backgroundColor: gagal ? AppColors.danger : null,
      ),
    );
  }
}
