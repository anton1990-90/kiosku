import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';
import '../data/repositories/product_repository.dart';

/// Product state.
class ProductState {
  final List<ProductModel> products;
  final List<String> categories;
  final String? selectedCategory;
  final String? searchQuery;
  final bool isLoading;

  const ProductState({
    this.products = const [],
    this.categories = const ['Semua'],
    this.selectedCategory = 'Semua',
    this.searchQuery,
    this.isLoading = false,
  });

  List<ProductModel> get filtered {
    var result = products;
    if (selectedCategory != null && selectedCategory != 'Semua') {
      result = result.where((p) => p.category == selectedCategory).toList();
    }
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      result = result
          .where((p) =>
              p.name.toLowerCase().contains(searchQuery!.toLowerCase()))
          .toList();
    }
    return result;
  }

  ProductState copyWith({
    List<ProductModel>? products,
    List<String>? categories,
    String? selectedCategory,
    String? searchQuery,
    bool? isLoading,
    bool clearSearch = false,
  }) {
    return ProductState(
      products: products ?? this.products,
      categories: categories ?? this.categories,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Product notifier — manages product list, filtering, CRUD.
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductRepository _repo = ProductRepository();

  ProductNotifier() : super(const ProductState(isLoading: true)) {
    loadProducts();
  }

  Future<void> loadProducts() async {
    state = state.copyWith(isLoading: true);
    final products = await _repo.getAll();
    final categories = ['Semua', ...await _repo.getCategories()];
    state = state.copyWith(
      products: products,
      categories: categories,
      isLoading: false,
    );
  }

  void setCategory(String category) {
    state = state.copyWith(selectedCategory: category);
  }

  void setSearch(String query) {
    state = state.copyWith(searchQuery: query, clearSearch: query.isEmpty);
  }

  Future<void> addProduct(ProductModel product) async {
    await _repo.insert(product);
    await loadProducts();
  }

  Future<void> updateProduct(ProductModel product) async {
    await _repo.update(product);
    await loadProducts();
  }

  Future<void> deleteProduct(int id) async {
    await _repo.delete(id);
    await loadProducts();
  }

  Future<void> restock(int productId, double quantity) async {
    await _repo.addStock(productId, quantity);
    await loadProducts();
  }

  /// Restok lengkap — mencatat riwayat stok, kas keluar, dan hutang supplier
  /// kalau belanjanya belum dibayar penuh.
  Future<void> restockProduct({
    required ProductModel product,
    required double quantity,
    int? costPerUnit,
    int paidNow = 0,
    String? supplierName,
    String? note,
    DateTime? dueDate,
  }) async {
    await _repo.restockProduct(
      product: product,
      quantity: quantity,
      costPerUnit: costPerUnit,
      paidNow: paidNow,
      supplierName: supplierName,
      note: note,
      dueDate: dueDate,
    );
    await loadProducts();
  }

  Future<List<ProductModel>> getLowStock() async {
    return await _repo.getLowStock();
  }

  Future<({int ok, int low, int out})> getStockSummary() async {
    return await _repo.getStockSummary();
  }
}

final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  return ProductNotifier();
});
