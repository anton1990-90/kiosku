import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/sale_repository.dart';

/// Dashboard state — holds today's stats for the Beranda screen.
class DashboardState {
  final int todaySales;
  final int todayTransactions;
  final int weeklyProfit;
  final bool isLoading;

  const DashboardState({
    this.todaySales = 0,
    this.todayTransactions = 0,
    this.weeklyProfit = 0,
    this.isLoading = false,
  });

  DashboardState copyWith({
    int? todaySales,
    int? todayTransactions,
    int? weeklyProfit,
    bool? isLoading,
  }) {
    return DashboardState(
      todaySales: todaySales ?? this.todaySales,
      todayTransactions: todayTransactions ?? this.todayTransactions,
      weeklyProfit: weeklyProfit ?? this.weeklyProfit,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Dashboard notifier — loads today's sales and weekly profit.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final SaleRepository _saleRepo = SaleRepository();

  DashboardNotifier() : super(const DashboardState());

  Future<void> loadStats() async {
    state = state.copyWith(isLoading: true);

    final todaySales = await _saleRepo.getTodaySalesTotal();
    final todayCount = await _saleRepo.getTodayTransactionCount();

    // Weekly profit (last 7 days)
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final weeklySales = await _saleRepo.getSales(
      startDate: weekAgo,
      endDate: now,
      limit: 1000,
    );
    final weeklyProfit =
        weeklySales.fold(0, (sum, s) => sum + s.totalProfit);

    state = state.copyWith(
      todaySales: todaySales,
      todayTransactions: todayCount,
      weeklyProfit: weeklyProfit,
      isLoading: false,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
