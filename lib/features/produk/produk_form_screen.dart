import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/product_model.dart';
import '../../providers/product_provider.dart';

/// Produk form — add or edit a product.
class ProdukFormScreen extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProdukFormScreen({super.key, this.product});

  @override
  ConsumerState<ProdukFormScreen> createState() => _ProdukFormScreenState();
}

class _ProdukFormScreenState extends ConsumerState<ProdukFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _minStockController = TextEditingController();
  final _supplierController = TextEditingController();
  final _barcodeController = TextEditingController();
  String _category = 'Sembako';
  String _emoji = '📦';

  final _categories = ['Sembako', 'Minuman', 'Snack', 'Kebutuhan', 'Lainnya'];
  final _emojis = ['📦', '🍚', '🛢️', '🧂', '🥚', '🍜', '☕', '🥛', '🧴', '🧈', '🌾', '💧'];

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      final p = widget.product!;
      _nameController.text = p.name;
      _category = p.category;
      _costPriceController.text = p.costPrice.toString();
      _sellPriceController.text = p.sellPrice.toString();
      _stockController.text = p.stock.toString();
      _minStockController.text = p.minStock.toString();
      _supplierController.text = p.supplier ?? '';
      _barcodeController.text = p.barcode ?? '';
      _emoji = p.emoji ?? '📦';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _supplierController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final product = ProductModel(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      category: _category,
      costPrice: int.parse(_costPriceController.text),
      sellPrice: int.parse(_sellPriceController.text),
      stock: int.parse(_stockController.text),
      minStock: int.parse(_minStockController.text.isEmpty ? '5' : _minStockController.text),
      supplier: _supplierController.text.trim().isEmpty
          ? null
          : _supplierController.text.trim(),
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      emoji: _emoji,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    if (isEditing) {
      await ref.read(productProvider.notifier).updateProduct(product);
    } else {
      await ref.read(productProvider.notifier).addProduct(product);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Emoji picker
            const Text('Ikon produk',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _emojis.map((e) {
                final isSelected = _emoji == e;
                return GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryLight
                          : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 20)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nama produk'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 16),
            // Category dropdown
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Kategori'),
              items: _categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? 'Sembako'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _costPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga modal',
                      prefixText: 'Rp ',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellPriceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Harga jual',
                      prefixText: 'Rp ',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Wajib diisi' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Profit preview
            if (_costPriceController.text.isNotEmpty &&
                _sellPriceController.text.isNotEmpty)
              Builder(builder: (context) {
                final cost = int.tryParse(_costPriceController.text) ?? 0;
                final sell = int.tryParse(_sellPriceController.text) ?? 0;
                final profit = sell - cost;
                return Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    'Laba per unit: ${Formatters.rupiah(profit)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: profit > 0
                          ? AppColors.successMid
                          : AppColors.dangerMid,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stok awal'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Wajib diisi' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min. stok',
                      hintText: '5',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier (opsional)',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _barcodeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Barcode (opsional)',
                hintText: 'Contoh: 8991002101234',
                prefixIcon: Icon(Icons.qr_code, color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(isEditing ? 'Simpan Perubahan' : 'Tambah Produk'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
