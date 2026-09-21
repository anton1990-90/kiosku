import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/product_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Dashboard (Beranda) — overview of today's sales, quick actions, alerts.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Load stats after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dashboardProvider.notifier).loadStats();
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  Future<void> _refresh() async {
    await ref.read(dashboardProvider.notifier).loadStats();
    await ref.read(productProvider.notifier).loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final dashState = ref.watch(dashboardProvider);
    final productState = ref.watch(productProvider);
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
                padding: const EdgeInsets.only(
                    top: 8, left: 20, right: 20, bottom: 16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AppColors.primary,
                          child: Text(
                            (user?.storeName.isNotEmpty == true)
                                ? user!.storeName.substring(0, 2).toUpperCase()
                                : 'TS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
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
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.notifications_outlined,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Revenue hero card
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penjualan hari ini',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      Formatters.rupiah(dashState.todaySales),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '+18%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${dashState.todayTransactions} transaksi',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Quick actions
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.8,
                  children: [
                    QuickAction(
                      icon: Icons.receipt_long,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryLight,
                      label: 'Transaksi',
                      onTap: () => context.go('/kasir'),
                    ),
                    QuickAction(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.accentMid,
                      iconBgColor: AppColors.accentLight,
                      label: 'Tambah Stok',
                      onTap: () => context.go('/stok'),
                    ),
                    QuickAction(
                      icon: Icons.handshake_outlined,
                      iconColor: AppColors.infoMid,
                      iconBgColor: AppColors.infoLight,
                      label: 'Hutang',
                      onTap: () {},
                    ),
                    QuickAction(
                      icon: Icons.note_add_outlined,
                      iconColor: AppColors.dangerMid,
                      iconBgColor: AppColors.dangerLight,
                      label: 'Catatan',
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
            // Stats grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                child: GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    StatCard(
                      icon: Icons.trending_up,
                      iconColor: AppColors.successMid,
                      iconBgColor: AppColors.successLight,
                      value: Formatters.rupiahCompact(dashState.weeklyProfit),
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
                    ),
                    StatCard(
                      icon: Icons.receipt_outlined,
                      iconColor: AppColors.infoMid,
                      iconBgColor: AppColors.infoLight,
                      value: '${dashState.todayTransactions}',
                      label: 'Transaksi hari ini',
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
                                  'Sisa ${p.stock} pcs dari minimum ${p.minStock}',
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
