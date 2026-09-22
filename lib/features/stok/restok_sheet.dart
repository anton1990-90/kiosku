import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/cash_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/cash_repository.dart';
import '../../providers/product_provider.dart';

/// Buka panel restok untuk satu produk.
Future<void> showRestokSheet(
  BuildContext context,
  ProductModel product,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.bgCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => RestokSheet(product: product),
  );
}

/// Panel tambah stok.
///
/// Selain menambah stok, panel ini sekaligus mencatat:
///   * riwayat pergerakan stok (masuk)
///   * uang keluar di kas, sebesar yang dibayar sekarang
///   * hutang ke supplier, kalau belanjanya belum dibayar penuh
class RestokSheet extends ConsumerStatefulWidget {
  final ProductModel product;

  const RestokSheet({super.key, required this.product});

  @override
  ConsumerState<RestokSheet> createState() => _RestokSheetState();
}

class _RestokSheetState extends ConsumerState<RestokSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyController;
  late final TextEditingController _costController;
  late final TextEditingController _paidController;
  late final TextEditingController _supplierController;
  late final TextEditingController _noteController;

  bool _catatHutang = false;
  DateTime? _jatuhTempo;
  bool _menyimpan = false;

  ProductModel get product => widget.product;

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(text: '10');
    _costController = TextEditingController(text: '${product.costPrice}');
    _paidController = TextEditingController();
    _supplierController = TextEditingController(text: product.supplier ?? '');
    _noteController = TextEditingController();
    _syncPaid();
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _paidController.dispose();
    _supplierController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyController.text.trim()) ?? 0;
  int get _cost => int.tryParse(_costController.text.trim()) ?? 0;
  int get _total => _qty * _cost;
  int get _dibayar {
    if (!_catatHutang) return _total;
    final v = int.tryParse(_paidController.text.trim()) ?? 0;
    if (v < 0) return 0;
    return v > _total ? _total : v;
  }

  int get _sisa => _total - _dibayar;

  /// Saat belum ditandai hutang, jumlah dibayar selalu sama dengan total.
  void _syncPaid() {
    if (!_catatHutang) {
      _paidController.text = _total.toString();
    }
  }

  Future<void> _pilihJatuhTempo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Jatuh tempo pembayaran ke supplier',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _jatuhTempo = picked);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qty <= 0) return;

    setState(() => _menyimpan = true);

    await ref.read(productProvider.notifier).restockProduct(
          product: product,
          quantity: _qty,
          costPerUnit: _cost > 0 ? _cost : null,
          paidNow: _dibayar,
          supplierName: _supplierController.text.trim().isEmpty
              ? null
              : _supplierController.text.trim(),
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          dueDate: _catatHutang && _sisa > 0 ? _jatuhTempo : null,
        );

    if (!mounted) return;
    setState(() => _menyimpan = false);

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Stok ${product.name} bertambah $_qty pcs'
          '${_sisa > 0 ? ' · hutang ${Formatters.rupiah(_sisa)}' : ''}',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stokBaru = product.stock + _qty;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        product.emoji ?? '📦',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tambah stok',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Stok sekarang ${product.stock} pcs · minimum '
                '${product.minStock} pcs',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const Divider(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Jumlah masuk',
                        suffixText: 'pcs',
                      ),
                      onChanged: (_) => setState(_syncPaid),
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Isi jumlah';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Harga modal',
                        prefixText: 'Rp ',
                      ),
                      onChanged: (_) => setState(_syncPaid),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _supplierController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Supplier',
                  hintText: 'Nama supplier atau pemasok',
                  prefixIcon: Icon(Icons.local_shipping_outlined,
                      color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 14),

              // Total belanja
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total belanja',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          Formatters.rupiah(_total),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Stok setelah ditambah',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        Text(
                          '$stokBaru pcs',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.successMid,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Ceklist hutang
              CheckboxListTile(
                value: _catatHutang,
                onChanged: (v) => setState(() {
                  _catatHutang = v ?? false;
                  _syncPaid();
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.primary,
                title: const Text(
                  'Belanja ini belum dibayar penuh',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                subtitle: const Text(
                  'Sisanya dicatat sebagai hutang ke supplier',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),

              if (_catatHutang) ...[
                const SizedBox(height: 4),
                TextFormField(
                  controller: _paidController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Dibayar sekarang',
                    prefixText: 'Rp ',
                    helperText: 'Isi 0 kalau belum bayar sama sekali',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 0) return 'Isi jumlah yang benar';
                    if (n > _total) return 'Melebihi total belanja';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pilihJatuhTempo,
                        icon: const Icon(Icons.event, size: 16),
                        label: Text(
                          _jatuhTempo == null
                              ? 'Jatuh tempo'
                              : Formatters.date(_jatuhTempo!),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadi hutang supplier',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.dangerMid,
                        ),
                      ),
                      Text(
                        Formatters.rupiah(_sisa),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.dangerMid,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  hintText: 'Contoh: kulakan pasar pagi',
                ),
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _menyimpan ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _menyimpan || _qty <= 0 ? null : _simpan,
                      icon: _menyimpan
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Tambah stok'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel kecil berisi riwayat keluar-masuk stok satu produk.
class RiwayatStokList extends StatelessWidget {
  final int productId;
  final int limit;

  const RiwayatStokList({
    super.key,
    required this.productId,
    this.limit = 8,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StockMovement>>(
      future: CashRepository().getStockMovements(
        productId: productId,
        limit: limit,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final data = snapshot.data ?? const <StockMovement>[];
        if (data.isEmpty) {
          return const Text(
            'Belum ada pergerakan stok tercatat.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          );
        }

        return Column(
          children: data.map((m) {
            final masuk = m.isMasuk;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: masuk ? AppColors.successLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      masuk ? Icons.south_west : Icons.north_east,
                      size: 14,
                      color: masuk ? AppColors.successMid : AppColors.warningMid,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${masuk ? '+' : '-'}${m.quantity} pcs',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMain,
                          ),
                        ),
                        Text(
                          m.note ??
                              (masuk ? 'Stok masuk' : 'Terjual'),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    Formatters.dateTime(m.date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
