import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/supplier_model.dart';
import '../data/repositories/supplier_repository.dart';

/// State daftar supplier.
class SupplierState {
  final List<SupplierModel> suppliers;
  final String search;
  final bool isLoading;

  const SupplierState({
    this.suppliers = const [],
    this.search = '',
    this.isLoading = false,
  });

  SupplierState copyWith({
    List<SupplierModel>? suppliers,
    String? search,
    bool? isLoading,
  }) {
    return SupplierState(
      suppliers: suppliers ?? this.suppliers,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier supplier — CRUD data pemasok.
class SupplierNotifier extends StateNotifier<SupplierState> {
  final SupplierRepository _repo = SupplierRepository();

  SupplierNotifier() : super(const SupplierState(isLoading: true)) {
    loadSuppliers();
  }

  Future<void> loadSuppliers() async {
    state = state.copyWith(isLoading: true);
    final suppliers = await _repo.getAll(search: state.search);
    state = state.copyWith(suppliers: suppliers, isLoading: false);
  }

  Future<void> setSearch(String query) async {
    state = state.copyWith(search: query);
    await loadSuppliers();
  }

  Future<void> addSupplier(SupplierModel supplier) async {
    await _repo.insert(supplier);
    await loadSuppliers();
  }

  Future<void> updateSupplier(SupplierModel supplier) async {
    await _repo.update(supplier);
    await loadSuppliers();
  }

  Future<void> deleteSupplier(int id) async {
    await _repo.delete(id);
    await loadSuppliers();
  }

  /// Nama supplier untuk dropdown di form produk.
  Future<List<String>> getNames() => _repo.getNames();
}

final supplierProvider =
    StateNotifierProvider<SupplierNotifier, SupplierState>((ref) {
  return SupplierNotifier();
});
