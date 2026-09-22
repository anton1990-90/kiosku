import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/debt_model.dart';
import '../data/repositories/debt_repository.dart';

/// State daftar hutang / piutang.
class DebtState {
  final List<DebtModel> debts;
  final String filterType; // 'semua' | piutang | hutang
  final String filterStatus; // 'semua' | belum_lunas | lunas
  final String search;
  final bool isLoading;
  final int totalPiutang;
  final int totalHutang;
  final int piutangCount;
  final int hutangCount;
  final int overdueCount;

  const DebtState({
    this.debts = const [],
    this.filterType = 'semua',
    this.filterStatus = 'semua',
    this.search = '',
    this.isLoading = false,
    this.totalPiutang = 0,
    this.totalHutang = 0,
    this.piutangCount = 0,
    this.hutangCount = 0,
    this.overdueCount = 0,
  });

  DebtState copyWith({
    List<DebtModel>? debts,
    String? filterType,
    String? filterStatus,
    String? search,
    bool? isLoading,
    int? totalPiutang,
    int? totalHutang,
    int? piutangCount,
    int? hutangCount,
    int? overdueCount,
  }) {
    return DebtState(
      debts: debts ?? this.debts,
      filterType: filterType ?? this.filterType,
      filterStatus: filterStatus ?? this.filterStatus,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
      totalPiutang: totalPiutang ?? this.totalPiutang,
      totalHutang: totalHutang ?? this.totalHutang,
      piutangCount: piutangCount ?? this.piutangCount,
      hutangCount: hutangCount ?? this.hutangCount,
      overdueCount: overdueCount ?? this.overdueCount,
    );
  }
}

/// Notifier hutang — memuat daftar, filter, CRUD, dan pembayaran cicilan.
class DebtNotifier extends StateNotifier<DebtState> {
  final DebtRepository _repo = DebtRepository();

  DebtNotifier() : super(const DebtState(isLoading: true)) {
    loadDebts();
  }

  Future<void> loadDebts() async {
    state = state.copyWith(isLoading: true);
    final debts = await _repo.getAll(
      type: state.filterType,
      status: state.filterStatus,
      search: state.search,
    );
    final summary = await _repo.getSummary();
    final overdue = await _repo.getOverdueCount();

    state = state.copyWith(
      debts: debts,
      isLoading: false,
      totalPiutang: summary.piutang,
      totalHutang: summary.hutang,
      piutangCount: summary.piutangCount,
      hutangCount: summary.hutangCount,
      overdueCount: overdue,
    );
  }

  Future<void> setFilterType(String type) async {
    state = state.copyWith(filterType: type);
    await loadDebts();
  }

  Future<void> setFilterStatus(String status) async {
    state = state.copyWith(filterStatus: status);
    await loadDebts();
  }

  Future<void> setSearch(String query) async {
    state = state.copyWith(search: query);
    await loadDebts();
  }

  Future<void> addDebt(DebtModel debt) async {
    await _repo.insert(debt);
    await loadDebts();
  }

  Future<void> updateDebt(DebtModel debt) async {
    await _repo.update(debt);
    await loadDebts();
  }

  Future<void> deleteDebt(int id) async {
    await _repo.delete(id);
    await loadDebts();
  }

  /// Catat pembayaran (bisa sebagian).
  Future<void> payDebt({
    required int debtId,
    required int amount,
    String? note,
  }) async {
    await _repo.addPayment(debtId: debtId, amount: amount, note: note);
    await loadDebts();
  }

  Future<List<DebtPaymentModel>> getPayments(int debtId) {
    return _repo.getPayments(debtId);
  }
}

final debtProvider = StateNotifierProvider<DebtNotifier, DebtState>((ref) {
  return DebtNotifier();
});
