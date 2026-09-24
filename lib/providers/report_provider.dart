import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/report_period.dart';
import '../data/models/report_models.dart';
import '../data/repositories/report_repository.dart';

/// State laporan untuk satu periode.
class ReportState {
  final ReportPeriod period;
  final ReportSummary summary;
  final List<ReportItemDetail> items;
  final List<TopProduct> topProducts;

  /// Produk yang paling sedikit terjual pada periode terpilih — termasuk
  /// barang yang belum terjual sama sekali.
  final List<TopProduct> leastProducts;

  final List<({DateTime date, int total})> dailyTotals;

  /// Tujuh hari terakhir, **selalu tujuh baris**, terlepas dari periode yang
  /// sedang dibuka. Dipakai grafik "7 hari terakhir" supaya pemilik toko
  /// selalu bisa melihat arah penjualannya tanpa harus berpindah periode.
  final List<({DateTime date, int total})> last7Days;

  final bool isLoading;

  const ReportState({
    required this.period,
    this.summary = const ReportSummary(),
    this.items = const [],
    this.topProducts = const [],
    this.leastProducts = const [],
    this.dailyTotals = const [],
    this.last7Days = const [],
    this.isLoading = true,
  });

  /// Apakah masih ada periode yang lebih baru dari yang sedang dilihat.
  bool get canGoNext => period.next() != null;

  ReportState copyWith({
    ReportPeriod? period,
    ReportSummary? summary,
    List<ReportItemDetail>? items,
    List<TopProduct>? topProducts,
    List<TopProduct>? leastProducts,
    List<({DateTime date, int total})>? dailyTotals,
    List<({DateTime date, int total})>? last7Days,
    bool? isLoading,
  }) {
    return ReportState(
      period: period ?? this.period,
      summary: summary ?? this.summary,
      items: items ?? this.items,
      topProducts: topProducts ?? this.topProducts,
      leastProducts: leastProducts ?? this.leastProducts,
      dailyTotals: dailyTotals ?? this.dailyTotals,
      last7Days: last7Days ?? this.last7Days,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier laporan — memuat ringkasan, detail item, dan produk terlaris.
class ReportNotifier extends StateNotifier<ReportState> {
  final ReportRepository _repo = ReportRepository();

  /// Panjang grafik tren. Konstanta, bukan angka yang ditulis ulang di layar,
  /// supaya jumlah baris yang diminta dari repositori dan jumlah batang yang
  /// digambar tidak bisa berbeda.
  static const int hariGrafik = 7;

  ReportNotifier()
      : super(ReportState(period: ReportPeriod.today())) {
    loadReport();
  }

  Future<void> loadReport() async {
    state = state.copyWith(isLoading: true);
    final period = state.period;

    final summary = await _repo.getSummary(period.start, period.end);
    final items = await _repo.getItemDetails(period.start, period.end);
    final top = await _repo.getTopProducts(period.start, period.end);
    final least = await _repo.getLeastProducts(period.start, period.end);
    final daily = await _repo.getDailyTotals(period.start, period.end);
    // Tidak bergantung pada periode terpilih — selalu tujuh hari terakhir.
    final tujuhHari = await _repo.getDailyTotalsTerakhir(hariGrafik);

    state = state.copyWith(
      summary: summary,
      items: items,
      topProducts: top,
      leastProducts: least,
      dailyTotals: daily,
      last7Days: tujuhHari,
      isLoading: false,
    );
  }

  Future<void> setPeriod(ReportPeriod period) async {
    state = state.copyWith(period: period);
    await loadReport();
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

  /// Lompat ke tanggal tertentu (dipakai pemilih tanggal).
  Future<void> jumpTo(DateTime date) async {
    await setPeriod(state.period.withAnchor(date));
  }

  /// Kembali ke periode hari ini.
  Future<void> goToday() async {
    await setPeriod(ReportPeriod.today().withType(state.period.type));
  }
}

final reportProvider = StateNotifierProvider<ReportNotifier, ReportState>((ref) {
  return ReportNotifier();
});
