import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/payment_method_model.dart';
import '../data/repositories/payment_method_repository.dart';

/// State daftar metode pembayaran.
class PaymentMethodState {
  final List<PaymentMethodModel> methods;
  final bool isLoading;

  const PaymentMethodState({
    this.methods = const [],
    this.isLoading = false,
  });

  /// Hanya yang aktif — dipakai layar Kasir.
  List<PaymentMethodModel> get active =>
      methods.where((m) => m.isActive).toList();

  PaymentMethodState copyWith({
    List<PaymentMethodModel>? methods,
    bool? isLoading,
  }) {
    return PaymentMethodState(
      methods: methods ?? this.methods,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier metode pembayaran — tambah, ubah nama, aktif/nonaktif, hapus.
class PaymentMethodNotifier extends StateNotifier<PaymentMethodState> {
  final PaymentMethodRepository _repo = PaymentMethodRepository();

  PaymentMethodNotifier() : super(const PaymentMethodState(isLoading: true)) {
    loadMethods();
  }

  Future<void> loadMethods() async {
    state = state.copyWith(isLoading: true);
    final methods = await _repo.getAll();
    state = state.copyWith(methods: methods, isLoading: false);
  }

  Future<void> addMethod({required String name, required String code}) async {
    final nextOrder = state.methods.isEmpty
        ? 1
        : state.methods
                .map((m) => m.sortOrder)
                .reduce((a, b) => a > b ? a : b) +
            1;
    await _repo.insert(
      PaymentMethodModel(code: code, name: name, sortOrder: nextOrder),
    );
    await loadMethods();
  }

  Future<void> renameMethod(PaymentMethodModel method, String newName) async {
    await _repo.update(method.copyWith(name: newName));
    await loadMethods();
  }

  Future<void> setActive(int id, bool isActive) async {
    await _repo.setActive(id, isActive);
    await loadMethods();
  }

  Future<void> deleteMethod(int id) async {
    await _repo.delete(id);
    await loadMethods();
  }

  /// Kode yang aktif, dipakai layar Kasir.
  Future<List<String>> getActiveCodes() => _repo.getActiveCodes();
}

final paymentMethodProvider =
    StateNotifierProvider<PaymentMethodNotifier, PaymentMethodState>((ref) {
  return PaymentMethodNotifier();
});
