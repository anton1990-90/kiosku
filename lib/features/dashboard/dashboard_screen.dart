import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/app_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../providers/auth_provider.dart';
import '../../providers/backup_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/update_provider.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/widgets/update_dialog.dart';

/// Dashboard (Beranda) — overview of today's sales, quick actions, alerts.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  /// Supaya dialog pembaruan otomatis hanya muncul sekali per sesi aplikasi.
  /// Lencana di lonceng pojok kanan atas tetap tampil selama aplikasi dibuka.
  static bool _popupSudahTampil = false;

  @override
  void initState() {
    super.initState();
    // Load stats after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(dashboardProvider.notifier).loadStats();
      ref.read(productProvider.notifier).loadProducts();
      await _periksaPembaruan();
      await _cadangkanKalauWaktunya();
    });
  }

  /// Cadangan otomatis: dijalankan setiap kali beranda terbuka, tapi
  /// `jalankanOtomatis` sendiri yang memutuskan — dia langsung keluar kalau
  /// cadangan terakhir belum lewat 24 jam, atau kalau fiturnya dimatikan.
  ///
  /// Beranda dipilih sebagai pemicu karena inilah layar pertama yang muncul
  /// setelah kunci PIN dibuka, jadi tidak perlu penjadwal latar belakang yang
  /// belum tentu dijalankan Android.
  Future<void> _cadangkanKalauWaktunya() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    await ref.read(backupProvider.notifier).jalankanOtomatis(user: user);
  }

  /// Periksa pembaruan lewat server aktivasi sendiri. Gagal dengan tenang
  /// kalau tidak ada internet.
  Future<void> _periksaPembaruan({bool tampilkanPopup = true}) async {
    final info = await ref.read(updateProvider.notifier).periksa();
    if (!mounted || info == null || !tampilkanPopup) return;
    if (_popupSudahTampil) return;
    _popupSudahTampil = true;
    await showUpdateDialog(context, info);
  }

  /// Ketukan pada lonceng di pojok kanan atas.
  Future<void> _bukaNotifikasi() async {
    final state = ref.read(updateProvider);

    // Sudah ada pembaruan yang diketahui — langsung tampilkan.
    if (state.adaPembaruan) {
      await showUpdateDialog(context, state.info!);
      return;
    }

    // Belum ada pembaruan yang diketahui. Pengguna mengetuk, jadi periksa
    // ulang sungguhan (bukan sekadar membaca hasil lama).
    final info = await ref.read(updateProvider.notifier).periksa(paksa: true);
    if (!mounted) return;
    if (info != null) {
      await showUpdateDialog(context, info);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aplikasi sudah versi terbaru, atau tidak ada koneksi.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(dashboardProvider.notifier).loadStats();
    await ref.read(productProvider.notifier).loadProducts();
  }

  /// Satu sisi kartu Kas: ikon bulat, label, lalu nominalnya.
  ///
  /// Dipakai dua kali (uang keluar dan uang masuk). Sengaja satu metode dan
  /// bukan dua blok yang disalin — dua salinan seperti itu cepat menyimpang.
  Widget _blokArus({
    required IconData ikon,
    required String label,
    required String nilai,
    required Color warna,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: warna.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(ikon, size: 13, color: warna),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: warna,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final productState = ref.watch(productProvider);
    final sesiKas = ref.watch(cashSessionProvider);
    final user = authState.user;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.bgCard,
                padding: EdgeInsets.only(
                  top: topSafePadding(context, extra: 12),
                  left: 20,
                  right: 20,
                  bottom: 16,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        StoreAvatar(
                          logoPath: user?.logoPath,
                          initials: user?.initials ?? 'TS',
                          radius: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.storeName ?? 'Toko Sembako',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textMain,
                                ),
                              ),
                              Text(
                                user?.storeAddress ?? 'Selamat datang kembali',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        // Lonceng di pojok kanan atas. Kalau ada versi baru,
                        // muncul titik merah dan ketukan membuka rinciannya.
                        _TombolNotifikasi(
                          adaPembaruan:
                              ref.watch(updateProvider).adaPembaruan,
                          onTap: _bukaNotifikasi,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Peringatan: build ini belum dikunci lisensi karena server
            // aktivasi belum diisi. Sengaja ditampilkan mencolok supaya APK
            // semacam ini tidak ikut terjual.
            if (!AppConfig.isActivationConfigured)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 18, color: AppColors.dangerMid),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mode uji: lisensi belum aktif karena server aktivasi '
                          'belum diisi di app_config.dart. Jangan jual APK ini.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.dangerMid,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Kartu Kas — saldo di tengah, uang masuk di kanan bawah,
            // uang keluar di kiri bawah. Ketuk untuk melihat riwayat.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.push('/kas'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Judul di kiri, jalan ke riwayat di kanan. "Riwayat"
                          // dibungkus pil supaya jelas bisa diketuk.
                          Row(
                            children: [
                              const Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Kas',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.14),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Text(
                                      'Riwayat',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Icon(Icons.chevron_right,
                                        size: 15, color: Colors.white),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Label dulu, baru angkanya. Angka besar tanpa label
                          // di atasnya terbaca sebagai judul, bukan saldo.
                          const Text(
                            'Saldo kas sekarang',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            Formatters.rupiah(dashState.kasSaldo),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text(
                                'Arus kas hari ini',
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 10.5,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  height: 1,
                                  color: Colors.white.withOpacity(0.18),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _blokArus(
                                  ikon: Icons.arrow_downward,
                                  label: 'Uang keluar',
                                  nilai: Formatters.rupiahCompact(
                                      dashState.kasKeluarHariIni),
                                  warna: const Color(0xFFFFD9D8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _blokArus(
                                  ikon: Icons.arrow_upward,
                                  label: 'Uang masuk',
                                  nilai: Formatters.rupiahCompact(
                                      dashState.kasMasukHariIni),
                                  warna: const Color(0xFFC6F6E2),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    // Cukup untuk label dua baris seperti "Tambah Stok";
                    // label satu baris otomatis di tengah, jadi keempat
                    // tombol tetap sejajar.
                    mainAxisExtent: 108,
                  ),
                  children: [
                    QuickAction(
                      icon: Icons.receipt_long,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryLight,
                      label: 'Transaksi',
                      onTap: () => context.go('/kasir'),
                    ),
                    // Menambah stok dan membuka laporan adalah pekerjaan
                    // pemilik toko, bukan kasir. Rutenya juga ditolak router.
                    if (authState.isOwner)
                      QuickAction(
                        icon: Icons.inventory_2_outlined,
                        iconColor: AppColors.accentMid,
                        iconBgColor: AppColors.accentLight,
                        label: 'Tambah Stok',
                        onTap: () => context.go('/stok'),
                      ),
                    if (authState.isOwner)
                      QuickAction(
                        icon: Icons.bar_chart_outlined,
                        iconColor: AppColors.successMid,
                        iconBgColor: AppColors.successLight,
                        label: 'Laporan',
                        onTap: () => context.go('/laporan'),
                      ),
                    if (authState.isOwner)
                      QuickAction(
                        icon: Icons.account_balance_outlined,
                        iconColor: AppColors.infoMid,
                        iconBgColor: AppColors.infoLight,
                        label: 'Laporan Keuangan',
                        onTap: () => context.push('/laporan/keuangan'),
                      ),
                    QuickAction(
                      icon: Icons.handshake_outlined,
                      iconColor: AppColors.warningMid,
                      iconBgColor: AppColors.warningLight,
                      label: 'Hutang & Piutang',
                      onTap: () => context.push('/hutang'),
                    ),
                    QuickAction(
                      icon: Icons.print_outlined,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryLight,
                      label: 'Cetak Ulang Struk',
                      onTap: () => context.push('/transaksi'),
                    ),
                    QuickAction(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.successMid,
                      iconBgColor: AppColors.successLight,
                      label: 'Buku Kas',
                      onTap: () => context.push('/kas'),
                    ),
                    // Tutup kasir — hitung uang di laci dan cocokkan dengan
                    // catatan sistem. Bisa dipakai kasir maupun pemilik toko.
                    // Labelnya mengikuti keadaan supaya lacinya terbaca
                    // sekilas: sedang terbuka, atau belum pernah dibuka.
                    QuickAction(
                      icon: Icons.lock_outline,
                      iconColor: AppColors.warningMid,
                      iconBgColor: AppColors.warningLight,
                      label: sesiKas.adaSesiTerbuka
                          ? 'Tutup Kasir'
                          : 'Buka Kasir',
                      onTap: () => context.push('/kas/tutup'),
                    ),
                    QuickAction(
                      icon: Icons.note_alt_outlined,
                      iconColor: AppColors.dangerMid,
                      iconBgColor: AppColors.dangerLight,
                      label: 'Catatan',
                      onTap: () => context.push('/catatan'),
                    ),
                  ],
                ),
              ),
            ),
            // Stats grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // Tinggi kartu ditetapkan langsung lewat `mainAxisExtent`,
                  // bukan diturunkan dari lebar seperti `childAspectRatio`.
                  // Dengan rasio, kartu makin pendek di HP sempit sampai
                  // labelnya terpotong.
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    // Di tablet kartu statistik ditata 4 sejajar supaya tidak
                    // menyisakan ruang kosong di sisi kanan.
                    crossAxisCount: Responsive.isTablet(context) ? 4 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 128,
                  ),
                  children: [
                    // Laba adalah isi pembukuan pemilik toko, bukan angka
                    // yang perlu dilihat kasir. Kartunya disembunyikan, bukan
                    // ditampilkan bernilai nol — nol terbaca sebagai "minggu
                    // ini tidak untung".
                    if (authState.isOwner)
                      StatCard(
                        icon: Icons.trending_up,
                        iconColor: AppColors.successMid,
                        iconBgColor: AppColors.successLight,
                        value:
                            Formatters.rupiahCompact(dashState.weeklyProfit),
                        label: 'Laba minggu ini',
                        trend: '+12%',
                        isUp: true,
                      ),
                    StatCard(
                      icon: Icons.inventory_outlined,
                      iconColor: AppColors.warningMid,
                      iconBgColor: AppColors.warningLight,
                      value: '${productState.products.length}',
                      label: 'Total produk',
                    ),
                    StatCard(
                      icon: Icons.warning_amber,
                      iconColor: AppColors.dangerMid,
                      iconBgColor: AppColors.dangerLight,
                      value: '${productState.products.where((p) => p.stock <= p.minStock).length}',
                      label: 'Stok menipis',
                      onTap: () => context.push('/stok/menipis'),
                    ),
                    StatCard(
                      icon: Icons.receipt_outlined,
                      iconColor: AppColors.infoMid,
                      iconBgColor: AppColors.infoLight,
                      value: '${dashState.todayTransactions}',
                      label: 'Transaksi hari ini',
                      onTap: () => context.push('/transaksi'),
                    ),
                  ],
                ),
              ),
            ),
            // Alerts section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SectionTitle(
                      title: 'Perlu perhatian',
                      subtitle: 'Stok menipis & perlu direstok',
                    ),
                    ...productState.products
                        .where((p) => p.stock <= p.minStock)
                        .take(5)
                        .map((p) => _AlertCard(
                              icon: p.emoji ?? '📦',
                              title: p.stock == 0
                                  ? '${p.name} habis'
                                  : '${p.name} menipis',
                              subtitle:
                                  'Sisa ${p.stock} ${p.unit} dari minimum ${p.minStock}',
                              color: p.stock == 0
                                  ? AppColors.danger
                                  : AppColors.warning,
                              lightColor: p.stock == 0
                                  ? AppColors.dangerLight
                                  : AppColors.warningLight,
                              midColor: p.stock == 0
                                  ? AppColors.dangerMid
                                  : AppColors.warningMid,
                              actionLabel: 'Restok',
                              onAction: () => context.go('/stok'),
                            )),
                    if (productState.products
                        .where((p) => p.stock <= p.minStock)
                        .isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle,
                                color: AppColors.successMid, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Semua stok aman. Tidak ada perlu perhatian.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.successMid,
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
          ],
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color lightColor;
  final Color midColor;
  final String actionLabel;
  final VoidCallback onAction;

  const _AlertCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.lightColor,
    required this.midColor,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: midColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lonceng notifikasi di pojok kanan atas dashboard.
///
/// Kalau ada pembaruan aplikasi, muncul titik merah kecil sebagai penanda.
/// Ketukan pada lonceng membuka rincian pembaruan (atau memberi tahu bahwa
/// aplikasi sudah versi terbaru).
class _TombolNotifikasi extends StatelessWidget {
  final bool adaPembaruan;
  final VoidCallback onTap;

  const _TombolNotifikasi({
    required this.adaPembaruan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Kotak berwarna lembut, bukan ikon telanjang: sejajar dengan kotak aksi
    // cepat di bawahnya, dan sasaran ketuknya tetap 44 px.
    return Material(
      color: AppColors.bgSoft,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Tooltip(
          message: adaPembaruan ? 'Ada pembaruan aplikasi' : 'Notifikasi',
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  size: 22,
                  color: AppColors.textMain,
                ),
                if (adaPembaruan)
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        // Cincin sewarna tombol supaya titiknya tidak menyatu
                        // dengan ikon lonceng di belakangnya.
                        border: Border.all(color: AppColors.bgSoft, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
