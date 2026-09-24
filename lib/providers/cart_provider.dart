import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/product_model.dart';
import '../data/models/sale_item_model.dart';
import '../core/utils/satuan.dart';

/// Cart item — a product added to the POS cart with quantity.
class CartItem {
  final ProductModel product;
  final double quantity;

  /// Potongan harga untuk baris ini, dalam rupiah.
  final int discount;

  CartItem({
    required this.product,
    required this.quantity,
    this.discount = 0,
  });

  /// Harga sebelum potongan.
  int get grossSubtotal => (product.sellPrice * quantity).round();

  /// Potongan yang benar-benar berlaku.
  ///
  /// Dibatasi harga barangnya: potongan tidak boleh melebihi harga, supaya
  /// baris ini tidak pernah bernilai negatif walau kasir salah mengetik.
  int get potongan {
    final kotor = grossSubtotal;
    return discount > kotor ? kotor : discount;
  }

  /// Harga yang dibayar pelanggan untuk baris ini.
  int get subtotal => grossSubtotal - potongan;
}

/// Cart state for the Kasir (POS) screen.
class CartState {
  final List<CartItem> items;
  final String? customerName;
  final String paymentMethod;

  /// Potongan untuk seluruh nota, di luar potongan per baris.
  final int discount;

  const CartState({
    this.items = const [],
    this.customerName,
    this.paymentMethod = 'tunai',
    this.discount = 0,
  });

  /// Jumlah harga semua barang setelah potongan per baris.
  int get subtotal => items.fold(0, (sum, i) => sum + i.subtotal);

  /// Potongan nota yang benar-benar berlaku, dibatasi harga barang.
  int get potonganNota {
    final kotor = subtotal;
    return discount > kotor ? kotor : discount;
  }

  /// Total yang harus dibayar pelanggan.
  int get totalAmount => subtotal - potonganNota;

  /// Semua potongan yang berlaku — per baris ditambah potongan nota.
  int get totalDiscount =>
      items.fold(0, (sum, i) => sum + i.potongan) + potonganNota;

  double get totalItems => items.fold(0.0, (sum, i) => sum + i.quantity);
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
              discount: i.potongan,
              unit: i.product.unit,
            ))
        .toList();
  }

  CartState copyWith({
    List<CartItem>? items,
    String? customerName,
    String? paymentMethod,
    int? discount,
  }) {
    return CartState(
      items: items ?? this.items,
      customerName: customerName ?? this.customerName,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      discount: discount ?? this.discount,
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
        // Potongan baris ikut dipertahankan — kalau tidak, menambah jumlah
        // diam-diam menghapus potongan yang sudah diketik kasir.
        items[existing] = CartItem(
          product: product,
          quantity: Satuan.batasi(
            item.quantity + 1,
            product.unit,
            product.stock,
          ),
          discount: item.discount,
        );
      }
    } else {
      if (product.stock > 0) {
        items.add(CartItem(product: product, quantity: 1.0));
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
        // Berhenti di stok yang tersedia, bukan menolak diam-diam: kalau
        // sisanya 1,5 kg sedangkan keranjang baru 1 kg, menekan + harus
        // jadi 1,5 — bukan tidak terjadi apa-apa.
        items[index] = CartItem(
          product: item.product,
          quantity: Satuan.batasi(
            item.quantity + 1,
            item.product.unit,
            item.product.stock,
          ),
          discount: item.discount,
        );
      }
    }
    state = state.copyWith(items: items);
  }

  void decrementQuantity(int productId) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index >= 0) {
      final item = items[index];
      final sisa = Satuan.rapikan(item.quantity - 1);
      if (sisa >= Satuan.langkahTerkecil(item.product.unit)) {
        // Sama seperti menambah jumlah: potongan baris jangan ikut terhapus.
        // Kalau potongan jadi melebihi harga, getter `potongan` yang membatasi.
        items[index] = CartItem(
          product: item.product,
          quantity: sisa,
          discount: item.discount,
        );
      } else {
        items.removeAt(index);
      }
    }
    state = state.copyWith(items: items);
  }

  /// Atur jumlah satu baris keranjang.
  ///
  /// Dipakai tombol cepat (¼, ½) dan isian manual di layar kasir.
  /// Nilainya dibatasi [Satuan.batasi]: kasir tidak bisa menjual lebih banyak
  /// daripada stok di rak, dan tidak bisa menyisakan jumlah nol yang membuat
  /// barisnya tak terlihat tetapi tetap ikut terhitung di nota.
  void setQuantity(int productId, double quantity) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    final item = items[index];
    items[index] = CartItem(
      product: item.product,
      quantity: Satuan.batasi(
        quantity,
        item.product.unit,
        item.product.stock,
      ),
      discount: item.discount,
    );
    state = state.copyWith(items: items);
  }

  void setCustomerName(String? name) {
    state = state.copyWith(customerName: name);
  }

  /// Atur potongan untuk satu baris keranjang, dalam rupiah.
  ///
  /// Nilai yang melebihi harga baris tetap disimpan apa adanya; yang membatasi
  /// adalah getter [CartItem.potongan], supaya angka yang diketik kasir tidak
  /// hilang diam-diam saat jumlah barangnya berubah.
  void setItemDiscount(int productId, int discount) {
    final items = List<CartItem>.from(state.items);
    final index = items.indexWhere((i) => i.product.id == productId);
    if (index < 0) return;
    final item = items[index];
    items[index] = CartItem(
      product: item.product,
      quantity: item.quantity,
      discount: discount < 0 ? 0 : discount,
    );
    state = state.copyWith(items: items);
  }

  /// Atur potongan untuk seluruh nota, dalam rupiah.
  void setDiscount(int discount) {
    state = state.copyWith(discount: discount < 0 ? 0 : discount);
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
