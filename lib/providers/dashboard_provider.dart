import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/cash_repository.dart';
import '../data/repositories/sale_repository.dart';

/// Dashboard state — holds today's stats for the Beranda screen.
class DashboardState {
  final int todaySales;
  final int todayTransactions;
  final int weeklyProfit;

  /// Kas: saldo terkini dan mutasi hari ini.
  final int kasSaldo;
  final int kasMasukHariIni;
  final int kasKeluarHariIni;

  final bool isLoading;

  const DashboardState({
    this.todaySales = 0,
    this.todayTransactions = 0,
    this.weeklyProfit = 0,
    this.kasSaldo = 0,
    this.kasMasukHariIni = 0,
    this.kasKeluarHariIni = 0,
    this.isLoading = false,
  });

  DashboardState copyWith({
    int? todaySales,
    int? todayTransactions,
    int? weeklyProfit,
    int? kasSaldo,
    int? kasMasukHariIni,
    int? kasKeluarHariIni,
    bool? isLoading,
  }) {
    return DashboardState(
      todaySales: todaySales ?? this.todaySales,
      todayTransactions: todayTransactions ?? this.todayTransactions,
      weeklyProfit: weeklyProfit ?? this.weeklyProfit,
      kasSaldo: kasSaldo ?? this.kasSaldo,
      kasMasukHariIni: kasMasukHariIni ?? this.kasMasukHariIni,
      kasKeluarHariIni: kasKeluarHariIni ?? this.kasKeluarHariIni,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Dashboard notifier — loads today's sales, weekly profit, and cash.
class DashboardNotifier extends StateNotifier<DashboardState> {
  final SaleRepository _saleRepo = SaleRepository();
  final CashRepository _cashRepo = CashRepository();

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

    // Kas — saldo keseluruhan dan mutasi hari ini.
    final kasSaldo = await _cashRepo.getSaldo();
    final awalHari = DateTime(now.year, now.month, now.day);
    final kasHariIni = await _cashRepo.getSummary(
      awalHari,
      awalHari.add(const Duration(days: 1)),
    );

    state = state.copyWith(
      todaySales: todaySales,
      todayTransactions: todayCount,
      weeklyProfit: weeklyProfit,
      kasSaldo: kasSaldo,
      kasMasukHariIni: kasHariIni.masuk,
      kasKeluarHariIni: kasHariIni.keluar,
      isLoading: false,
    );
  }
}

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier();
});
