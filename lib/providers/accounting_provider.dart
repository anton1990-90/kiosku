import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/report_period.dart';
import '../data/models/accounting_models.dart';
import '../data/models/cash_model.dart';
import '../data/repositories/accounting_repository.dart';
import '../data/repositories/cash_repository.dart';

/// State laporan keuangan untuk satu periode.
class AccountingState {
  final ReportPeriod period;
  final LabaRugi labaRugi;
  final PerubahanEkuitas ekuitas;
  final Neraca neraca;
  final ArusKas arusKas;
  final List<ExpenseModel> expenses;
  final List<PriveModel> priveList;
  final bool isLoading;

  const AccountingState({
    required this.period,
    this.labaRugi = const LabaRugi(),
    this.ekuitas = const PerubahanEkuitas(),
    this.neraca = const Neraca(),
    this.arusKas = const ArusKas(),
    this.expenses = const [],
    this.priveList = const [],
    this.isLoading = true,
  });

  bool get canGoNext => period.next() != null;

  AccountingState copyWith({
    ReportPeriod? period,
    LabaRugi? labaRugi,
    PerubahanEkuitas? ekuitas,
    Neraca? neraca,
    ArusKas? arusKas,
    List<ExpenseModel>? expenses,
    List<PriveModel>? priveList,
    bool? isLoading,
  }) {
    return AccountingState(
      period: period ?? this.period,
      labaRugi: labaRugi ?? this.labaRugi,
      ekuitas: ekuitas ?? this.ekuitas,
      neraca: neraca ?? this.neraca,
      arusKas: arusKas ?? this.arusKas,
      expenses: expenses ?? this.expenses,
      priveList: priveList ?? this.priveList,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier laporan keuangan — laba rugi, perubahan ekuitas, neraca,
/// dan arus kas.
class AccountingNotifier extends StateNotifier<AccountingState> {
  final AccountingRepository _repo = AccountingRepository();
  final CashRepository _cash = CashRepository();

  AccountingNotifier()
      : super(AccountingState(period: ReportPeriod.today().withType(
          ReportPeriodType.bulanan,
        ))) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    final period = state.period;

    final labaRugi = await _repo.getLabaRugi(period.start, period.end);
    final ekuitas = await _repo.getPerubahanEkuitas(period.start, period.end);
    final neraca = await _repo.getNeraca();
    final arusKas = await _repo.getArusKas(period.start, period.end);
    final expenses = await _cash.getExpenses(period.start, period.end);
    final priveList = await _cash.getPrive(period.start, period.end);

    state = state.copyWith(
      labaRugi: labaRugi,
      ekuitas: ekuitas,
      neraca: neraca,
      arusKas: arusKas,
      expenses: expenses,
      priveList: priveList,
      isLoading: false,
    );
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
    await setPeriod(ReportPeriod.today().withType(state.period.type));
  }

  /// Catat beban usaha. Beban sekaligus mengurangi kas (uang keluar).
  Future<void> addExpense({
    required String category,
    required int amount,
    String? note,
    DateTime? date,
  }) async {
    final now = date ?? DateTime.now();
    await _cash.insertExpense(
      ExpenseModel(
        category: category,
        amount: amount,
        note: note,
        date: now,
        createdAt: DateTime.now(),
      ),
    );
    await _cash.catat(
      type: CashType.keluar,
      amount: amount,
      category: CashCategory.beban,
      note: note == null || note.isEmpty ? 'Beban $category' : note,
      refType: 'expense',
      date: now,
    );
    await load();
  }

  Future<void> deleteExpense(int id) async {
    await _cash.deleteExpense(id);
    await load();
  }

  /// Catat prive — uang toko diambil pemilik. Bukan beban usaha.
  Future<void> addPrive({
    required int amount,
    String? note,
    DateTime? date,
  }) async {
    final now = date ?? DateTime.now();
    await _cash.insertPrive(
      PriveModel(
        amount: amount,
        note: note,
        date: now,
        createdAt: DateTime.now(),
      ),
    );
    await _cash.catat(
      type: CashType.keluar,
      amount: amount,
      category: CashCategory.prive,
      note: note == null || note.isEmpty ? 'Prive pemilik' : note,
      refType: 'prive',
      date: now,
    );
    await load();
  }

  Future<void> deletePrive(int id) async {
    await _cash.deletePrive(id);
    await load();
  }
}

final accountingProvider =
    StateNotifierProvider<AccountingNotifier, AccountingState>((ref) {
  return AccountingNotifier();
});
