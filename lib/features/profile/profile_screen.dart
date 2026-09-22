import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/license_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../shared/services/update_service.dart';
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
    final info = await UpdateService.instance.checkForUpdate();
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
            _licenseRow('Kode lisensi', license?.code ?? '-'),
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
    final user = authState.user;

    final totalTransactions =
        salesAsync.maybeWhen(data: (s) => s.length, orElse: () => 0);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: CustomScrollView(
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                        Text(
                          user != null
                              ? 'UMKM terdaftar sejak ${Formatters.date(user.createdAt)}'
                              : 'Mitra UMKM',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, -16, 16, 0),
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
