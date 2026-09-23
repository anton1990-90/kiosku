import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/customer_model.dart';
import '../data/repositories/customer_repository.dart';

/// State daftar pelanggan.
class CustomerState {
  final List<CustomerRingkasan> pelanggan;
  final String search;
  final bool isLoading;

  const CustomerState({
    this.pelanggan = const [],
    this.search = '',
    this.isLoading = false,
  });

  CustomerState copyWith({
    List<CustomerRingkasan>? pelanggan,
    String? search,
    bool? isLoading,
  }) {
    return CustomerState(
      pelanggan: pelanggan ?? this.pelanggan,
      search: search ?? this.search,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Notifier pelanggan — CRUD buku pelanggan.
class CustomerNotifier extends StateNotifier<CustomerState> {
  final CustomerRepository _repo = CustomerRepository();

  CustomerNotifier() : super(const CustomerState(isLoading: true)) {
    loadPelanggan();
  }

  Future<void> loadPelanggan() async {
    state = state.copyWith(isLoading: true);
    final daftar = await _repo.getRingkasan(search: state.search);
    state = state.copyWith(pelanggan: daftar, isLoading: false);
  }

  Future<void> setSearch(String query) async {
    state = state.copyWith(search: query);
    await loadPelanggan();
  }

  Future<void> addCustomer(CustomerModel customer) async {
    await _repo.insert(customer);
    await loadPelanggan();
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    await _repo.update(customer);
    await loadPelanggan();
  }

  Future<void> deleteCustomer(int id) async {
    await _repo.delete(id);
    await loadPelanggan();
  }

  /// Nama pelanggan untuk saran di kasir dan form hutang.
  Future<List<String>> getNames() => _repo.getNames();
}

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) {
  return CustomerNotifier();
});
