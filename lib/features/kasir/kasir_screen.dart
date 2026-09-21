import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../providers/sale_provider.dart';
import '../../shared/services/bluetooth_printer_service.dart';
import '../../shared/services/receipt_service.dart';
import 'barcode_scanner_screen.dart';
import 'printer_selection_screen.dart';

/// Kasir (POS) — point of sale for making transactions.
/// Fully offline: products, cart, and checkout all work without internet.
class KasirScreen extends ConsumerStatefulWidget {
  const KasirScreen({super.key});

  @override
  ConsumerState<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends ConsumerState<KasirScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleCheckout() async {
    final cart = ref.read(cartProvider);
    final authState = ref.read(authProvider);
    final user = authState.user;

    if (cart.isEmpty || user == null) return;

    // Capture items & user before clearing the cart
    final saleItems = cart.toSaleItems();

    // Show payment dialog
    final result = await showDialog<({int paid, String method})>(
      context: context,
      builder: (context) => _PaymentDialog(
        totalAmount: cart.totalAmount,
      ),
    );

    if (result == null) return;

    final saleNotifier = ref.read(saleProvider.notifier);
    final sale = await saleNotifier.checkout(
      userId: user.id!,
      items: saleItems,
      customerName: cart.customerName,
      paymentMethod: result.method,
      paidAmount: result.paid,
    );

    if (sale != null) {
      ref.read(cartProvider.notifier).clearCart();
      ref.read(productProvider.notifier).loadProducts();

      if (mounted) {
        _showReceiptDialog(sale, saleItems, user);
      }
    }
  }

  /// Scan a product barcode and add it to the cart.
  Future<void> _handleScan() async {
    final result = await Navigator.push<ProductModel>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );

    if (result == null || !mounted) return;

    if (result.stock > 0) {
      ref.read(cartProvider.notifier).addToCart(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} ditambahkan'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.name} stok habis'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Print the receipt to a Bluetooth thermal printer.
  Future<void> _printReceipt(
    SaleModel sale,
    List<SaleItemModel> items,
    UserModel user,
  ) async {
    // Show printer selection
    final device = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
    );

    if (device == null || !mounted) return;

    try {
      final bytes = await ReceiptService.instance.generateReceipt(
        sale: sale,
        items: items,
        storeName: user.storeName,
        storeAddress: user.storeAddress,
      );
      await BluetoothPrinterService.instance.printBytes(device, bytes);
      await BluetoothPrinterService.instance.disconnect(device);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Struk berhasil dicetak'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencetak: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showReceiptDialog(
    SaleModel sale,
    List<SaleItemModel> items,
    UserModel user,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 28),
            SizedBox(width: 8),
            Text('Transaksi Berhasil'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${sale.invoiceNumber}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(
              Formatters.rupiah(sale.totalAmount),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 4),
            Text('${sale.totalItems} item · ${sale.paymentMethod.toUpperCase()}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (sale.changeAmount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian',
                        style: TextStyle(color: AppColors.successMid)),
                    Text(
                      Formatters.rupiah(sale.changeAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.successMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Selesai'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _printReceipt(sale, items, user);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Cetak Struk'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final cart = ref.watch(cartProvider);

    final filteredProducts = productState.products.where((p) {
      if (productState.selectedCategory != 'Semua' &&
          p.category != productState.selectedCategory) {
        return false;
      }
      if (productState.searchQuery != null &&
          productState.searchQuery!.isNotEmpty) {
        return p.name
            .toLowerCase()
            .contains(productState.searchQuery!.toLowerCase());
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          // Header
          Container(
            color: AppColors.bgCard,
            padding: const EdgeInsets.only(top: 8, left: 20, right: 20, bottom: 16),
            child: Column(
              children: [
                const Row(
                  children: [
                    Text(
                      'Kasir',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      ref.read(productProvider.notifier).setSearch(v),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.bgSoft,
                    hintText: 'Cari produk atau scan barcode...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                    suffixIcon: IconButton(
                      onPressed: _handleScan,
                      icon: const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                      tooltip: 'Scan barcode',
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ),
          // Categories
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: productState.categories.length,
              itemBuilder: (context, index) {
                final cat = productState.categories[index];
                final isActive = productState.selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        ref.read(productProvider.notifier).setCategory(cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.primary : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Product grid
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(16, 8, 16, cart.isEmpty ? 100 : 280),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return GestureDetector(
                  onTap: () {
                    if (product.stock > 0) {
                      ref.read(cartProvider.notifier).addToCart(product);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} stok habis'),
                          backgroundColor: AppColors.danger,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            color: AppColors.bgSoft,
                            child: Center(
                              child: Text(
                                product.emoji ?? '📦',
                                style: const TextStyle(fontSize: 36),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMain,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                Formatters.rupiah(product.sellPrice),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Stok: ${product.stock} pcs',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: product.stock == 0
                                      ? AppColors.dangerMid
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      // Cart panel
      bottomSheet: cart.isEmpty
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.08),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Keranjang (${cart.items.length} item)',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              ref.read(cartProvider.notifier).clearCart(),
                          child: const Text(
                            'Kosongkan',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 100),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: cart.items.length,
                        itemBuilder: (context, index) {
                          final item = cart.items[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item.product.name,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMain),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _qtyButton(
                                        Icons.remove,
                                        () => ref
                                            .read(cartProvider.notifier)
                                            .decrementQuantity(item.product.id!),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        child: Text(
                                          '${item.quantity}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textMain,
                                          ),
                                        ),
                                      ),
                                      _qtyButton(
                                        Icons.add,
                                        () => ref
                                            .read(cartProvider.notifier)
                                            .incrementQuantity(item.product.id!),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    Formatters.rupiah(item.subtotal),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textMain,
                                    ),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total bayar',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          Formatters.rupiah(cart.totalAmount),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleCheckout,
                        icon: const Icon(Icons.payment, size: 18),
                        label: const Text('Proses Pembayaran'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }
}

/// Payment dialog — choose payment method and enter paid amount.
class _PaymentDialog extends StatefulWidget {
  final int totalAmount;

  const _PaymentDialog({required this.totalAmount});

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  String _method = 'tunai';
  final _paidController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _paidController.text = widget.totalAmount.toString();
  }

  @override
  void dispose() {
    _paidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paid = int.tryParse(_paidController.text) ?? 0;
    final change = paid - widget.totalAmount;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Pembayaran'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total: ${Formatters.rupiah(widget.totalAmount)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 16),
          const Text('Metode pembayaran',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _methodChip('tunai', 'Tunai'),
              const SizedBox(width: 8),
              _methodChip('qris', 'QRIS'),
              const SizedBox(width: 8),
              _methodChip('ewallet', 'E-Wallet'),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _paidController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Jumlah dibayar',
              prefixText: 'Rp ',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          // Quick amount buttons
          Wrap(
            spacing: 8,
            children: [
              _quickAmount(widget.totalAmount),
              _quickAmount((widget.totalAmount / 50000).ceil() * 50000),
              _quickAmount((widget.totalAmount / 100000).ceil() * 100000),
            ],
          ),
          if (change >= 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian',
                      style: TextStyle(color: AppColors.successMid)),
                  Text(
                    Formatters.rupiah(change),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.successMid,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: paid < widget.totalAmount
              ? null
              : () => Navigator.pop(
                    context,
                    (paid: paid, method: _method),
                  ),
          child: const Text('Bayar'),
        ),
      ],
    );
  }

  Widget _methodChip(String value, String label) {
    final isActive = _method == value;
    return GestureDetector(
      onTap: () => setState(() => _method = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _quickAmount(int amount) {
    return GestureDetector(
      onTap: () {
        _paidController.text = amount.toString();
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(
          Formatters.rupiahCompact(amount),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
