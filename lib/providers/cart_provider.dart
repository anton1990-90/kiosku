import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';
import '../data/models/sale_item_model.dart';

/// Cart item — a product added to the POS cart with quantity.
class CartItem {
  final ProductModel product;
  final int quantity;

  CartItem({required this.product, required this.quantity});

  int get subtotal => product.sellPrice * quantity;
}

/// Cart state for the Kasir (POS) screen.
class CartState {
  final List<CartItem> items;
  final String? customerName;
  final String paymentMethod;

  const CartState({
    this.items = const [],
    this.customerName,
    this.paymentMethod = 'tunai',
  });

  int get totalAmount => items.fold(0, (sum, i) => sum + i.subtotal);
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);
  bool get isEmpty => items.isEmpty;

  /// Convert cart items to sale items.
  /// saleId is a placeholder (0) — it is overwritten during the DB transaction.
  List<SaleItemModel> toSaleItems() {
    return items
        .map((i) => SaleItemModel(
              saleId: 0,
              productId: i.product.id!,
              productName: i.product.name,
              costPrice: i.product.costPrice,
              sellPrice: i.product.sellPrice,
              quantity: i.quantity,
              subtotal: i.subtotal,
            ))
        .toList();
  }

  CartState copyWith({
    List<CartItem>? items,
    String? customerName,
    String? paymentMethod,
  }) {
    return CartState(
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }
}

/// Cart notifier — manages the shopping cart in the POS screen.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  void addToCart(ProductModel product) {
    final items = List<CartItem>.from(state.items);
    final existing = items.indexWhere((i) => i.product.id == product.id);
    if (existing >= 0) {
      final item = items[existing];
      if (item.quantity < product.stock) {
        items[existing] =
            CartItem(product: product, quantity: item.quantity + 1);
      }
    } else {
      if (product.stock > 0) {
        items.add(CartItem(product: product, quantity: 1));
      }
    }
    state = state.copyWith(items: items);
  }

  void removeFromCart(int productId) {
    final items =
        state.items.where((i) => i.product.id != productId).toList();
    state = state.copyWith(items: items);
  }

  void incrementQuantity(int productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      final item = items[index];
      if (item.quantity < item.product.stock) {
        items[index] =
            CartItem(product: item.product, quantity: item.quantity + 1);
      }
    }
    state = state.copyWith(items: items);
  }

  void decrementQuantity(int productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      final item = items[index];
      if (item.quantity > 1) {
        items[index] =
            CartItem(product: item.product, quantity: item.quantity - 1);
      } else {
        items.removeAt(index);
      }
    }
    state = state.copyWith(items: items);
  }

  void setCustomerName(String? name) {
    state = state.copyWith(customerName: name);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier();
});
