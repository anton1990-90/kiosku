import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/product_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/payment_method_provider.dart';
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

    // Dialog pembayaran — termasuk ceklist "apakah hutang?".
    final result = await showDialog<_HasilBayar>(
      context: context,
      builder: (context) => _PaymentDialog(
        totalAmount: cart.totalAmount,
        initialCustomer: cart.customerName,
      ),
    );

    if (result == null) return;

    final saleNotifier = ref.read(saleProvider.notifier);
    final sale = await saleNotifier.checkout(
      userId: user.id!,
      items: saleItems,
      customerName: result.customerName,
      paymentMethod: result.method,
      paidAmount: result.paid,
      isDebt: result.isDebt,
      dueDate: result.dueDate,
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
        storePhone: user.storePhone,
        logoPath: user.logoPath,
        qrisPath: user.qrisPath,
        bankName: user.bankName,
        bankAccountNumber: user.bankAccountNumber,
        bankAccountName: user.bankAccountName,
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                // Di tablet kolomnya ditambah supaya kartu produk tidak
                // membengkak jadi sangat besar.
                crossAxisCount: Responsive.gridColumns(context),
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
                                style: TextStyle(fontSize: 11, color: product.stock == 0
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

/// Hasil dialog pembayaran.
class _HasilBayar {
  final int paid;
  final String method;
  final bool isDebt;
  final String? customerName;
  final DateTime? dueDate;

  const _HasilBayar({
    required this.paid,
    required this.method,
    this.isDebt = false,
    this.customerName,
    this.dueDate,
  });
}

/// Payment dialog — pilih metode, isi jumlah dibayar, dan tandai apakah
/// transaksi ini hutang.
///
/// Ceklist "Transaksi ini hutang" inilah yang membuat sisa pembayaran
/// otomatis tercatat sebagai piutang pelanggan, terhubung ke nota dan
/// produk yang dibeli. Pilihan metode diambil dari pengaturan
/// "Metode pembayaran" di Profil.
class _PaymentDialog extends ConsumerStatefulWidget {
  final int totalAmount;
  final String? initialCustomer;

  const _PaymentDialog({
    required this.totalAmount,
    this.initialCustomer,
  });

  @override
  ConsumerState<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends ConsumerState<_PaymentDialog> {
  String _method = 'tunai';
  final _paidController = TextEditingController();
  late final TextEditingController _customerController;
  bool _isDebt = false;
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _paidController.text = widget.totalAmount.toString();
    _customerController =
        TextEditingController(text: widget.initialCustomer ?? '');
    // Muat metode terbaru, lalu pilih yang pertama sebagai default.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(paymentMethodProvider.notifier).loadMethods();
      if (!mounted) return;
      final active = ref.read(paymentMethodProvider).active;
      if (active.isNotEmpty) {
        setState(() => _method = active.first.code);
      }
    });
  }

  @override
  void dispose() {
    _paidController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  int get _paid => int.tryParse(_paidController.text.trim()) ?? 0;

  int get _sisa {
    final s = widget.totalAmount - _paid;
    return s < 0 ? 0 : s;
  }

  int get _kembalian =>
      _paid > widget.totalAmount ? _paid - widget.totalAmount : 0;

  /// Nama pelanggan wajib diisi kalau ada sisa yang jadi piutang.
  bool get _namaWajib => _isDebt && _sisa > 0;

  bool get _bolehBayar {
    if (_isDebt) {
      if (_paid < 0 || _paid > widget.totalAmount) return false;
      if (_namaWajib && _customerController.text.trim().isEmpty) return false;
      return true;
    }
    return _paid >= widget.totalAmount;
  }

  void _ubahHutang(bool value) {
    setState(() {
      _isDebt = value;
      // Kalau ditandai hutang, pembayaran dimulai dari 0 supaya jelas
      // berapa sisanya.
      _paidController.text = value ? '0' : widget.totalAmount.toString();
    });
  }

  Future<void> _pilihJatuhTempo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Jatuh tempo pembayaran',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Pembayaran'),
      content: SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 14),

            // Nama pelanggan — wajib kalau transaksinya hutang.
            Text(
              _namaWajib ? 'Nama pelanggan (wajib)' : 'Nama pelanggan',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _customerController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Contoh: Bu Sri',
                prefixIcon: const Icon(Icons.person_outline,
                    color: AppColors.textTertiary),
                errorText: _namaWajib &&
                        _customerController.text.trim().isEmpty
                    ? 'Wajib diisi untuk transaksi hutang'
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            const Text('Metode pembayaran',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final methods = ref.watch(paymentMethodProvider).active;
              // Kalau pengguna belum mengatur metode apa pun, sediakan Tunai
              // supaya transaksi tetap bisa diselesaikan.
              final List<({String code, String name})> choices =
                  methods.isEmpty
                      ? <({String code, String name})>[
                          (code: 'tunai', name: 'Tunai'),
                        ]
                      : methods.map((m) => (code: m.code, name: m.name)).toList();

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    choices.map((c) => _methodChip(c.code, c.name)).toList(),
              );
            }),
            const SizedBox(height: 10),

            // Info cara bayar — muncul begitu metode QRIS atau transfer
            // dipilih, supaya bisa langsung ditunjukkan ke pelanggan.
            // Gambar QRIS dan data rekening diambil dari Profil › Info toko.
            Builder(builder: (context) {
              if (_method != 'qris' && _method != 'transfer') {
                return const SizedBox.shrink();
              }

              final user = ref.watch(authProvider).user;
              final qrisPath = (user?.qrisPath ?? '').trim();
              final namaBank = (user?.bankName ?? '').trim();
              final nomorRek = (user?.bankAccountNumber ?? '').trim();
              final pemilikRek = (user?.bankAccountName ?? '').trim();

              final tampilkanQris = _method == 'qris' && qrisPath.isNotEmpty;
              final tampilkanBank =
                  _method == 'transfer' && nomorRek.isNotEmpty;
              if (!tampilkanQris && !tampilkanBank) {
                return const SizedBox.shrink();
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tampilkanQris) ...[
                      const Text(
                        'Tunjukkan QRIS ini ke pelanggan',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.infoMid,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Image.file(
                            File(qrisPath),
                            height: 190,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Text(
                              'Gambar QRIS tidak bisa dibuka',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (tampilkanBank) ...[
                      const Text(
                        'Pelanggan transfer ke rekening toko',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.infoMid,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (namaBank.isNotEmpty)
                        Text(
                          'Bank: $namaBank',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                      Text(
                        'No. rekening: $nomorRek',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      if (pemilikRek.isNotEmpty)
                        Text(
                          'a.n. $pemilikRek',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMain,
                          ),
                        ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 10),

            // ---- Ceklist hutang ----
            Container(
              decoration: BoxDecoration(
                color: _isDebt ? AppColors.warningLight : AppColors.bgSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isDebt ? AppColors.accent : AppColors.border,
                ),
              ),
              child: CheckboxListTile(
                value: _isDebt,
                onChanged: (v) => _ubahHutang(v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: const Text(
                  'Transaksi ini hutang?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                subtitle: const Text(
                  'Centang kalau pelanggan belum bayar penuh. Sisanya '
                  'tercatat sebagai piutang dan muncul di menu Hutang.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ),
            const SizedBox(height: 14),

            TextField(
              controller: _paidController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _isDebt ? 'Dibayar sekarang' : 'Jumlah dibayar',
                prefixText: 'Rp ',
                helperText: _isDebt
                    ? 'Isi 0 kalau pelanggan belum bayar sama sekali'
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Quick amount buttons
            Wrap(
              spacing: 8,
              children: [
                _quickAmount(widget.totalAmount),
                _quickAmount((widget.totalAmount / 50000).ceil() * 50000),
                _quickAmount((widget.totalAmount / 100000).ceil() * 100000),
              ],
            ),

            // Kembalian — hanya untuk pembayaran penuh.
            if (!_isDebt && _kembalian > 0) ...[
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
                      Formatters.rupiah(_kembalian),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.successMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Sisa piutang + jatuh tempo.
            if (_isDebt && _sisa > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jadi piutang pelanggan',
                        style: TextStyle(color: AppColors.dangerMid)),
                    Text(
                      Formatters.rupiah(_sisa),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.dangerMid,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pilihJatuhTempo,
                icon: const Icon(Icons.event, size: 16),
                label: Text(
                  _dueDate == null
                      ? 'Tentukan jatuh tempo (opsional)'
                      : 'Jatuh tempo ${Formatters.date(_dueDate!)}',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _bolehBayar
              ? () => Navigator.pop(
                    context,
                    _HasilBayar(
                      paid: _isDebt ? _paid : widget.totalAmount,
                      method: _method,
                      isDebt: _isDebt && _sisa > 0,
                      customerName: _customerController.text.trim().isEmpty
                          ? null
                          : _customerController.text.trim(),
                      dueDate: _dueDate,
                    ),
                  )
              : null,
          child: Text(_isDebt ? 'Simpan sebagai hutang' : 'Bayar'),
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
