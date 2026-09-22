import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/report_period.dart';
import '../data/models/cash_model.dart';
import '../data/repositories/cash_repository.dart';

/// State kas — saldo, ringkasan hari ini, dan riwayat mutasi.
class CashState {
  final ReportPeriod period;
  final int saldo;
  final CashSummary todaySummary;
  final List<CashTransaction> transactions;
  final String filterType; // 'semua' | CashType.masuk | CashType.keluar
  final bool isLoading;

  const CashState({
    required this.period,
    this.saldo = 0,
    this.todaySummary = const CashSummary(),
    this.transactions = const [],
    this.filterType = 'semua',
    this.isLoading = true,
  });

  CashSummary get periodSummary {
    var masuk = 0;
    var keluar = 0;
    for (final t in transactions) {
      if (t.isMasuk) {
        masuk += t.amount;
      } else {
        keluar += t.amount;
      }
    }
    return CashSummary(masuk: masuk, keluar: keluar);
  }

  bool get canGoNext => period.next() != null;

  CashState copyWith({
    ReportPeriod? period,
    int? saldo,
    CashSummary? todaySummary,
    List<CashTransaction>? transactions,
    String? filterType,
    bool? isLoading,
  }) {
    return CashState(
      period: period ?? this.period,
      saldo: saldo ?? this.saldo,
      todaySummary: todaySummary ?? this.todaySummary,
      transactions: transactions ?? this.transactions,
      filterType: filterType ?? this.filterType,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier kas — memuat saldo, ringkasan harian, dan riwayat mutasi.
class CashNotifier extends StateNotifier<CashState> {
  final CashRepository _repo = CashRepository();

  CashNotifier()
      : super(CashState(period: ReportPeriod.today().withType(
          ReportPeriodType.bulanan,
        ))) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final period = state.period;

    final saldo = await _repo.getSaldo();

    final now = DateTime.now();
    final awalHari = DateTime(now.year, now.month, now.day);
    final todaySummary = await _repo.getSummary(
      awalHari,
      awalHari.add(const Duration(days: 1)),
    );

    final transactions = await _repo.getAll(
      start: period.start,
      end: period.end,
      type: state.filterType,
      limit: 500,
    );

    state = state.copyWith(
      saldo: saldo,
      todaySummary: todaySummary,
      transactions: transactions,
      isLoading: false,
    );
  }

  Future<void> setFilterType(String type) async {
    state = state.copyWith(filterType: type);
    await load();
  }

  Future<void> setPeriod(ReportPeriod period) async {
    state = state.copyWith(period: period);
    await load();
  }

  Future<void> setType(ReportPeriodType type) async {
    await setPeriod(state.period.withType(type));
  }

  Future<void> goPrevious() async {
    await setPeriod(state.period.previous());
  }

  Future<void> goNext() async {
    final next = state.period.next();
    if (next == null) return;
    await setPeriod(next);
  }

  Future<void> goToday() async {
    await setPeriod(
      ReportPeriod.today().withType(state.period.type),
    );
  }

  /// Catat mutasi kas manual dari layar Kas.
  Future<void> addManual({
    required String type,
    required int amount,
    required String category,
    String? note,
    DateTime? date,
  }) async {
    await _repo.catat(
      type: type,
      amount: amount,
      category: category,
      note: note,
      refType: 'manual',
      date: date,
    );
    await load();
  }

  Future<void> deleteTransaction(int id) async {
    await _repo.delete(id);
    await load();
  }
}

final cashProvider = StateNotifierProvider<CashNotifier, CashState>((ref) {
  return CashNotifier();
});
