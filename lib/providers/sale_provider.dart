import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/sale_item_model.dart';
import '../data/models/sale_model.dart';
import '../data/repositories/sale_repository.dart';

/// Sale state — holds recent sales for reports and history.
class SaleNotifier extends StateNotifier<AsyncValue<List<SaleModel>>> {
  final SaleRepository _repo = SaleRepository();

  SaleNotifier() : super(const AsyncValue.loading()) {
    loadSales();
  }

  Future<void> loadSales() async {
    state = const AsyncValue.loading();
    try {
      final sales = await _repo.getSales(limit: 50);
      state = AsyncValue.data(sales);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Process checkout — create a sale from a list of sale items.
  ///
  /// Kalau [isDebt] true dan pembayaran kurang dari total, repositori
  /// sekaligus membuat catatan piutang pelanggan.
  Future<SaleModel?> checkout({
    required int userId,
    required List<SaleItemModel> items,
    String? customerName,
    required String paymentMethod,
    required int paidAmount,
    bool isDebt = false,
    DateTime? dueDate,
  }) async {
    try {
      final sale = await _repo.createSale(
        userId: userId,
        items: items,
        customerName: customerName,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        isDebt: isDebt,
        dueDate: dueDate,
      );

      await loadSales();
      return sale;
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return null;
    }
  }

  /// Weekly sales data for chart (last 7 days).
  Future<List<({String day, int total})>> getWeeklySales() async {
    return await _repo.getWeeklySales();
  }

  /// Weekly summary for the report screen.
  Future<({int totalSales, int totalProfit, int transactions})>
      getWeeklySummary() async {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final sales = await _repo.getSales(
      startDate: weekAgo,
      endDate: now,
      limit: 1000,
    );
    return (
      totalSales: sales.fold(0, (sum, s) => sum + s.totalAmount),
      totalProfit: sales.fold(0, (sum, s) => sum + s.totalProfit),
      transactions: sales.length,
    );
  }
}

final saleProvider =
    StateNotifierProvider<SaleNotifier, AsyncValue<List<SaleModel>>>((ref) {
  return SaleNotifier();
});
