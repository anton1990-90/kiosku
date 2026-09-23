import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cash_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/license_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../shared/services/backup_service.dart';
import '../../shared/services/export_service.dart';
import '../../providers/update_provider.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/update_dialog.dart';

/// Profile screen — store info, settings, and logout.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _stockNotif = true;
  bool _dailyReport = true;
  bool _debtReminder = false;
  String _appVersion = '...';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
      ref.read(cashProvider.notifier).load();
    });
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      if (mounted) setState(() => _appVersion = '-');
    }
  }

  /// Cek pembaruan manual dari layar Profil.
  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final info = await ref.read(updateProvider.notifier).periksa(paksa: true);
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (info == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aplikasi sudah versi terbaru, atau tidak ada koneksi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await showUpdateDialog(context, info);
  }

  void _showLicenseDialog() {
    final license = ref.read(licenseProvider).license;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Info Lisensi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _licenseRow('Kode aktivasi', license?.code ?? '-'),
            _licenseRow('Pemilik', license?.customerName.isNotEmpty == true
                ? license!.customerName
                : '-'),
            _licenseRow('Kode perangkat', license?.deviceId ?? '-'),
            _licenseRow(
              'Tanggal aktivasi',
              license != null ? Formatters.date(license.activatedAt) : '-',
            ),
            const SizedBox(height: 8),
            const Text(
              'Lisensi ini berlaku untuk 1 HP. Kalau Anda ganti HP, hubungi '
              'penjual untuk memindahkan lisensi.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Widget _licenseRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }

  /// Backup seluruh data ke satu berkas Excel berisi banyak lembar, lalu buka
  /// menu "Bagikan" Android supaya bisa disimpan ke Drive, dikirim lewat
  /// WhatsApp, atau dipindahkan ke komputer.
  Future<void> _backupData() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final file = await BackupService.instance.createBackup(user: user);
      await ExportService.instance.share(
        file,
        subject: 'Backup data ${user.storeName}',
        text: 'Backup data TokoKu — ${Formatters.date(DateTime.now())}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat backup: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Reset semua data usaha. Wajib memasukkan password login dulu — dialognya
  /// sendiri yang memverifikasi, jadi kalau password salah tidak ada satu pun
  /// data yang terhapus.
  Future<void> _resetData() async {
    final dihapus = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DialogResetData(),
    );
    if (dihapus != true || !mounted) return;

    // Muat ulang semua daftar supaya layar langsung bersih tanpa perlu
    // menutup aplikasi lebih dulu.
    ref.read(productProvider.notifier).loadProducts();
    ref.read(cashProvider.notifier).load();
    ref.read(saleProvider.notifier).loadSales();
    ref.read(debtProvider.notifier).loadDebts();
    ref.read(noteProvider.notifier).loadNotes();
    ref.read(supplierProvider.notifier).loadSuppliers();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Semua data usaha sudah dihapus'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successMid,
      ),
    );
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar?'),
        content: const Text('Anda akan keluar dari akun. Data tetap tersimpan di perangkat ini.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final productState = ref.watch(productProvider);
    final salesAsync = ref.watch(saleProvider);
    final licenseState = ref.watch(licenseProvider);
    final debtState = ref.watch(debtProvider);
    final noteState = ref.watch(noteProvider);
    final supplierState = ref.watch(supplierProvider);
    final paymentState = ref.watch(paymentMethodProvider);
    final cashState = ref.watch(cashProvider);
    final user = authState.user;

    final totalTransactions =
        salesAsync.maybeWhen(data: (s) => s.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Responsive.centered(
        CustomScrollView(
          slivers: [
            // Profile header
            SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  topSafePadding(context, extra: 20),
                  20,
                  28,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    StoreAvatar(
                      logoPath: user?.logoPath,
                      initials: user?.initials ?? 'TS',
                      radius: 36,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                      borderColor: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.storeName ?? 'Toko Sembako',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Nama toko & email bisa panjang, jadi pil ini dibatasi
                    // satu baris dan dipangkas — tanpa itu isinya bisa meluber
                    // keluar header.
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, color: AppColors.accent, size: 14),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              user != null
                                  ? 'UMKM terdaftar sejak ${Formatters.date(user.createdAt)}'
                                  : 'Mitra UMKM',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Stats
            //
            // Jarak atasnya positif. Sebelumnya memakai margin negatif
            // (-16) supaya kartu ini "menumpuk" di atas header, tapi
            // `Container.margin` membuat widget `Padding`, dan `Padding`
            // tidak menerima nilai negatif — di build rilis kartunya
            // meleset keluar slot-nya dan menindis header.
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border, width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _StatColumn(
                        value: '${productState.products.length}', label: 'Produk'),
                    _divider(),
                    _StatColumn(
                        value: '$totalTransactions', label: 'Transaksi'),
                    _divider(),
                    _StatColumn(
                        value: '${productState.products.where((p) => p.stock <= p.minStock).length}',
                        label: 'Stok rendah'),
                  ],
                ),
              ),
            ),
            // Menu sections
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MenuGroupTitle('Toko & bisnis'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.store_outlined,
                          color: AppColors.primary,
                          title: 'Info toko',
                          subtitle: user?.storeAddress?.isNotEmpty == true
                              ? user!.storeAddress!
                              : 'Nama, alamat, telepon & logo usaha',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/profile/toko'),
                        ),
                        _MenuItem(
                          icon: Icons.payments_outlined,
                          color: AppColors.accentMid,
                          title: 'Metode pembayaran',
                          subtitle: paymentState.methods.isEmpty
                              ? 'Belum ada metode'
                              : paymentState.active
                                  .map((m) => m.name)
                                  .join(', '),
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/profile/pembayaran'),
                        ),
                        _MenuItem(
                          icon: Icons.people_outline,
                          color: AppColors.infoMid,
                          title: 'Supplier',
                          subtitle: supplierState.suppliers.isEmpty
                              ? 'Kelola data supplier'
                              : '${supplierState.suppliers.length} supplier terdaftar',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/profile/supplier'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Hutang & catatan'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.handshake_outlined,
                          color: AppColors.infoMid,
                          title: 'Hutang & piutang',
                          subtitle: debtState.totalPiutang == 0 &&
                                  debtState.totalHutang == 0
                              ? 'Belum ada hutang tercatat'
                              : 'Piutang ${Formatters.rupiahCompact(debtState.totalPiutang)} · '
                                  'Hutang ${Formatters.rupiahCompact(debtState.totalHutang)}',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/hutang'),
                        ),
                        _MenuItem(
                          icon: Icons.note_alt_outlined,
                          color: AppColors.dangerMid,
                          title: 'Catatan',
                          subtitle: noteState.notes.isEmpty
                              ? 'Tulis catatan toko'
                              : '${noteState.notes.length} catatan tersimpan',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/catatan'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Kas & laporan keuangan'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          color: AppColors.primary,
                          title: 'Kas',
                          subtitle: cashState.saldo == 0
                              ? 'Catat uang masuk & keluar'
                              : 'Saldo ${Formatters.rupiah(cashState.saldo)} · '
                                  'riwayat kas masuk & keluar',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/kas'),
                        ),
                        _MenuItem(
                          icon: Icons.account_balance_outlined,
                          color: AppColors.accentMid,
                          title: 'Laporan keuangan',
                          subtitle:
                              'Laba rugi, ekuitas, neraca, arus kas & prive',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/laporan/keuangan'),
                        ),
                        _MenuItem(
                          icon: Icons.receipt_long_outlined,
                          color: AppColors.infoMid,
                          title: 'Rincian produk terjual',
                          subtitle:
                              'Filter harian, total pendapatan & laba, ekspor',
                          trailing: Icons.chevron_right,
                          onTap: () => context.push('/laporan/rincian'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Preferensi'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.notifications_active_outlined,
                          color: AppColors.primary,
                          title: 'Notifikasi stok',
                          subtitle: 'Peringatan stok menipis',
                          trailing: null,
                          toggle: _stockNotif,
                          onToggle: (v) =>
                              setState(() => _stockNotif = v),
                        ),
                        _MenuItem(
                          icon: Icons.bar_chart_outlined,
                          color: AppColors.accentMid,
                          title: 'Laporan harian',
                          subtitle: 'Ringkasan setiap pagi',
                          trailing: null,
                          toggle: _dailyReport,
                          onToggle: (v) =>
                              setState(() => _dailyReport = v),
                        ),
                        _MenuItem(
                          icon: Icons.handshake_outlined,
                          color: AppColors.dangerMid,
                          title: 'Pengingat piutang',
                          subtitle: 'Auto-reminder ke pelanggan',
                          trailing: null,
                          toggle: _debtReminder,
                          onToggle: (v) =>
                              setState(() => _debtReminder = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Data & keamanan'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.backup_outlined,
                          color: AppColors.successMid,
                          title: 'Backup semua data',
                          subtitle: 'Simpan ke Excel, dipisah per lembar '
                              '(produk, penjualan, kas, hutang, dll.)',
                          trailing: Icons.chevron_right,
                          onTap: _backupData,
                        ),
                        _MenuItem(
                          icon: Icons.delete_forever_outlined,
                          color: AppColors.dangerMid,
                          title: 'Reset semua data',
                          subtitle: 'Hapus semua data usaha — perlu password login',
                          trailing: Icons.chevron_right,
                          onTap: _resetData,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Lisensi & aplikasi'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.verified_user_outlined,
                          color: AppColors.primary,
                          title: 'Lisensi aktif',
                          subtitle: licenseState.license?.code ?? 'Belum aktif',
                          trailing: Icons.chevron_right,
                          onTap: _showLicenseDialog,
                        ),
                        _MenuItem(
                          icon: Icons.system_update_alt,
                          color: AppColors.infoMid,
                          title: 'Cek pembaruan',
                          subtitle: _checkingUpdate
                              ? 'Memeriksa...'
                              : 'Versi $_appVersion terpasang',
                          trailing: Icons.chevron_right,
                          onTap: _checkingUpdate ? null : _checkUpdate,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _MenuGroupTitle('Bantuan'),
                    _MenuCard(
                      children: [
                        _MenuItem(
                          icon: Icons.help_outline,
                          color: AppColors.infoMid,
                          title: 'Pusat bantuan',
                          subtitle: 'FAQ, tutorial, kontak',
                          trailing: Icons.chevron_right,
                          onTap: () {},
                        ),
                        _MenuItem(
                          icon: Icons.info_outline,
                          color: Colors.grey,
                          title: 'Tentang aplikasi',
                          subtitle: 'Versi $_appVersion',
                          trailing: Icons.chevron_right,
                          onTap: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, color: AppColors.danger),
                        label: const Text('Keluar',
                            style: TextStyle(color: AppColors.danger)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 0.5,
      height: 36,
      color: AppColors.border,
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;

  const _StatColumn({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuGroupTitle extends StatelessWidget {
  final String text;
  const _MenuGroupTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<Widget> children;
  const _MenuCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final IconData? trailing;
  final bool? toggle;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.toggle,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textMain,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      trailing: toggle != null
          ? Switch(
              value: toggle!,
              onChanged: onToggle,
              activeColor: AppColors.primary,
            )
          : trailing != null
              ? const Icon(Icons.chevron_right, color: AppColors.textTertiary)
              : null,
    );
  }
}

/// Dialog konfirmasi "Reset semua data".
///
/// Sengaja meminta password login: ini tindakan yang menghapus seluruh data
/// usaha dan tidak bisa dibatalkan, jadi harus dipastikan orang yang
/// menekannya memang pemilik akun. Password diverifikasi lewat
/// `AuthNotifier.resetAllData`, yang membandingkan hash SHA-256 sama seperti
/// saat login — jadi password salah benar-benar tidak menghapus apa pun.
class _DialogResetData extends ConsumerStatefulWidget {
  const _DialogResetData();

  @override
  ConsumerState<_DialogResetData> createState() => _DialogResetDataState();
}

class _DialogResetDataState extends ConsumerState<_DialogResetData> {
  final _passwordController = TextEditingController();
  bool _memproses = false;
  bool _lihatPassword = false;
  String? _error;

  static const _akanDihapus = [
    'Produk & stok',
    'Semua transaksi penjualan',
    'Hutang, piutang & riwayat cicilannya',
    'Riwayat kas, beban & prive',
    'Catatan, supplier & riwayat stok',
  ];

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _hapus() async {
    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _error = 'Password wajib diisi');
      return;
    }

    setState(() {
      _memproses = true;
      _error = null;
    });

    final berhasil =
        await ref.read(authProvider.notifier).resetAllData(password);
    if (!mounted) return;

    if (!berhasil) {
      setState(() {
        _memproses = false;
        _error = 'Password salah';
      });
      return;
    }

    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 26),
          SizedBox(width: 8),
          Text('Reset semua data?'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Data berikut akan dihapus permanen dan tidak bisa dikembalikan:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            for (final item in _akanDihapus)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.remove_circle_outline,
                      size: 14,
                      color: AppColors.dangerMid,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Akun, profil toko, logo, QRIS, dan rekening bank tetap '
                'tersimpan. Sebaiknya lakukan backup dulu sebelum reset.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.successMid,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Masukkan password login untuk melanjutkan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              obscureText: !_lihatPassword,
              autofocus: true,
              enabled: !_memproses,
              onSubmitted: (_) => _hapus(),
              decoration: InputDecoration(
                hintText: 'Password akun Anda',
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _lihatPassword = !_lihatPassword),
                  icon: Icon(
                    _lihatPassword ? Icons.visibility_off : Icons.visibility,
                    size: 18,
                    color: AppColors.textTertiary,
                  ),
                  tooltip: _lihatPassword ? 'Sembunyikan' : 'Lihat',
                ),
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _memproses ? null : () => Navigator.pop(context, false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _memproses ? null : _hapus,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: _memproses
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Hapus semua data'),
        ),
      ],
    );
  }
}
