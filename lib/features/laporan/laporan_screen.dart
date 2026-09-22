import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/sale_model.dart';
import '../../providers/sale_provider.dart';

/// Laporan screen — sales reports, weekly chart, top products.
class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen> {
  String _period = 'Mingguan';
  List<({String day, int total})> _weeklyData = [];
  ({int totalSales, int totalProfit, int transactions})? _summary;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final saleNotifier = ref.read(saleProvider.notifier);
    final weekly = await saleNotifier.getWeeklySales();
    final summary = await saleNotifier.getWeeklySummary();
    if (mounted) {
      setState(() {
        _weeklyData = weekly;
        _summary = summary;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final salesAsync = ref.watch(saleProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Laporan',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Period tabs
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.bgSoft,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: ['Harian', 'Mingguan', 'Bulanan'].map((p) {
                  final isActive = _period == p;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _period = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.bgCard : null,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          p,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Summary cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _SummaryCard(
                    label: 'Total penjualan',
                    value: _summary != null
                        ? Formatters.rupiahCompact(_summary!.totalSales)
                        : '...',
                    color: AppColors.primary,
                    trend: '+18%',
                    isUp: true,
                  ),
                  _SummaryCard(
                    label: 'Total laba',
                    value: _summary != null
                        ? Formatters.rupiahCompact(_summary!.totalProfit)
                        : '...',
                    color: AppColors.successMid,
                    trend: '+12%',
                    isUp: true,
                  ),
                  _SummaryCard(
                    label: 'Transaksi',
                    value: _summary != null ? '${_summary!.transactions}' : '...',
                    color: AppColors.infoMid,
                    trend: '+8%',
                    isUp: true,
                  ),
                  _SummaryCard(
                    label: 'Rata-rata/Transaksi',
                    value: _summary != null && _summary!.transactions > 0
                        ? Formatters.rupiahCompact(
                            (_summary!.totalSales / _summary!.transactions).round())
                        : '...',
                    color: AppColors.accentMid,
                    trend: '+3%',
                    isUp: true,
                  ),
                ],
              ),
            ),
          ),
          // Chart
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Penjualan mingguan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 140,
                    child: _weeklyData.isEmpty
                        ? const Center(
                            child: Text('Memuat data...',
                                style: TextStyle(color: AppColors.textTertiary)))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: _buildChartBars(),
                          ),
                  ),
                ],
              ),
            ),
          ),
          // Recent transactions
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transaksi terbaru',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  salesAsync.when(
                    data: (sales) => sales.isEmpty
                        ? const Text('Belum ada transaksi',
                            style: TextStyle(color: AppColors.textTertiary))
                        : Column(
                            children: sales.take(8).map((s) => _saleRow(s)).toList(),
                          ),
                    loading: () => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, __) => const Text('Gagal memuat data'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildChartBars() {
    final maxTotal = _weeklyData.fold<int>(
        0, (max, d) => d.total > max ? d.total : max);
    if (maxTotal == 0) return [];

    return _weeklyData.map((d) {
      final heightPercent = d.total / maxTotal;
      final isHighlight = heightPercent >= 0.95;
      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 24,
              height: (100 * heightPercent).clamp(4.0, 100.0).toDouble(),
              decoration: BoxDecoration(
                color: isHighlight
                    ? AppColors.primary
                    : AppColors.primaryLight,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
                border: Border(
                  top: BorderSide(
                    color: AppColors.primary,
                    width: 3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              d.day,
              style: TextStyle(
                fontSize: 10,
                color: isHighlight
                    ? AppColors.primary
                    : AppColors.textTertiary,
                fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _saleRow(SaleModel sale) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sale.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  '${sale.totalItems} item · ${sale.paymentMethod.toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Formatters.rupiah(sale.totalAmount),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final String trend;
  final bool isUp;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.trend,
    required this.isUp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            '$trend dari minggu lalu',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isUp ? AppColors.successMid : AppColors.dangerMid,
            ),
          ),
        ],
      ),
    );
  }
}
