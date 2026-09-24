import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/satuan.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/product_model.dart';
import '../../data/models/supplier_model.dart';
import '../../data/repositories/product_repository.dart';
import '../../providers/product_provider.dart';
import '../../providers/supplier_provider.dart';
import '../../shared/services/product_photo_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../kasir/barcode_scanner_screen.dart';

/// Produk form — tambah atau edit produk.
/// Barcode bisa diisi manual atau diambil langsung dari hasil scan kamera.
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
  final _barcodeController = TextEditingController();

  String _category = 'Sembako';
  String _emoji = '📦';

  /// Satuan jual produk — dipakai supaya struk menulis "2 kg", bukan "2".
  String _unit = 'pcs';

  /// Path foto barang yang dipilih dari galeri. Null berarti memakai emoji.
  String? _photoPath;

  /// Nama supplier terpilih. String kosong berarti "tidak ada supplier" —
  /// dipakai sebagai penanda karena DropdownButton tidak menampilkan item
  /// yang bernilai null.
  String _supplier = '';
  bool _saving = false;

  final _categories = ['Sembako', 'Minuman', 'Snack', 'Kebutuhan', 'Lainnya'];
  final _emojis = ['📦', '🍚', '🛢️', '🧂', '🥚', '🍜', '☕', '🥛', '🧴', '🧈', '🌾', '💧'];
  final _units = [
    'pcs',
    'kg',
    'gram',
    'liter',
    'ml',
    'ikat',
    'bungkus',
    'sachet',
    'dus',
    'karton',
  ];

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
      _stockController.text = Formatters.jumlah(p.stock);
      _minStockController.text = Formatters.jumlah(p.minStock);
      _barcodeController.text = p.barcode ?? '';
      _emoji = p.emoji ?? '📦';
      _unit = p.unit;
      _photoPath = p.photoPath;
      _supplier = p.supplier ?? '';
    }
    // Pastikan daftar supplier terbaru sudah dimuat untuk dropdown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(supplierProvider.notifier).loadSuppliers();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costPriceController.dispose();
    _sellPriceController.dispose();
    _stockController.dispose();
    _minStockController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  /// Buka kamera dan isi kolom barcode dari hasil scan.
  Future<void> _scanBarcode() async {
    final code = await BarcodeScannerScreen.scanRaw(context);
    if (code == null || !mounted) return;

    _barcodeController.text = code;
    setState(() {});

    // Ingatkan kalau barcode ini sudah dipakai produk lain.
    final existing = await ProductRepository().findByBarcode(code);
    if (!mounted || existing == null) return;
    if (existing.id == widget.product?.id) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Barcode ini sudah dipakai produk "${existing.name}". '
          'Menyimpan akan membuat dua produk dengan barcode sama.',
        ),
        backgroundColor: AppColors.warningMid,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Tambah supplier baru tanpa keluar dari form produk.
  Future<void> _addSupplier() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supplier baru'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nama supplier'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Tambah'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (name == null || name.isEmpty || !mounted) return;

    final now = DateTime.now();
    await ref.read(supplierProvider.notifier).addSupplier(
          SupplierModel(name: name, createdAt: now, updatedAt: now),
        );
    if (mounted) setState(() => _supplier = name);
  }

  /// Pilih foto barang dari galeri HP.
  ///
  /// Foto lama dihapus setelah foto baru berhasil dipilih, supaya berkas tidak
  /// menumpuk di penyimpanan. Kalau pemilik membatalkan pilihan, tidak ada
  /// yang berubah.
  Future<void> _pilihFoto() async {
    final baru = await ProductPhotoService.instance.pilihDanSimpan();
    if (baru == null || !mounted) return;

    final lama = _photoPath;
    setState(() => _photoPath = baru);
    if (lama != null && lama != baru) {
      await ProductPhotoService.instance.hapus(lama);
    }
  }

  /// Hapus foto dan kembali memakai emoji sebagai ikon barang.
  Future<void> _hapusFoto() async {
    final lama = _photoPath;
    setState(() => _photoPath = null);
    await ProductPhotoService.instance.hapus(lama);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final barcode = _barcodeController.text.trim();

    // Cegah dua produk dengan barcode sama — bikin scan jadi ambigu.
    if (barcode.isNotEmpty) {
      final existing = await ProductRepository().findByBarcode(barcode);
      if (existing != null && existing.id != widget.product?.id) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Barcode $barcode sudah dipakai produk "${existing.name}". '
                'Gunakan barcode lain.',
              ),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final product = ProductModel(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      category: _category,
      costPrice: int.parse(_costPriceController.text.trim()),
      sellPrice: int.parse(_sellPriceController.text.trim()),
      stock: Satuan.baca(_stockController.text) ?? 0.0,
      minStock: Satuan.baca(_minStockController.text) ?? 5.0,
      supplier: _supplier.isEmpty ? null : _supplier,
      barcode: barcode.isEmpty ? null : barcode,
      emoji: _emoji,
      unit: _unit,
      photoPath: _photoPath,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(productProvider.notifier);
    if (isEditing) {
      await notifier.updateProduct(product);
    } else {
      await notifier.addProduct(product);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);

    // Gabungkan supplier terdaftar dengan nilai produk lama supaya pilihan
    // lama tidak hilang kalau supplier-nya sudah dihapus dari daftar.
    final supplierNames = <String>[
      ...supplierState.suppliers.map((s) => s.name),
      if (_supplier != null &&
          !supplierState.suppliers.any((s) => s.name == _supplier))
        _supplier!,
    ];

    // Satuan produk lama bisa saja di luar daftar baku (misalnya diisi dari
    // perangkat lain), jadi nilainya selalu disisipkan. Tanpa itu dropdown
    // tampil kosong, karena `DropdownButtonFormField` tidak menampilkan item
    // yang tidak ada di daftarnya.
    final satuanTersedia = <String>[
      ..._units,
      if (!_units.contains(_unit)) _unit,
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Produk' : 'Tambah Produk'),
      ),
      body: Form(
        key: _formKey,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Barcode ditaruh paling atas supaya bisa langsung scan dulu.
              const Text(
                'Barcode',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      // Barcode bisa berisi huruf (Code128/Code39), jadi jangan
                      // dikunci ke papan angka saja.
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        hintText: '8991002101234',
                        prefixIcon: Icon(Icons.qr_code,
                            color: AppColors.textTertiary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _scanBarcode,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                      label: const Text('Scan'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Ketuk "Scan" untuk memindai lewat kamera, atau ketik angkanya '
                'langsung. Kalau kamera bermasalah, di layar scan ada tombol '
                '"Masukkan manual".',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Foto barang — opsional. Kalau diisi, foto inilah yang tampil di
              // daftar barang dan di kasir. Kalau kosong, emoji yang dipakai.
              const Text('Foto & ikon produk',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductIcon(
                    photoPath: _photoPath,
                    emoji: _emoji,
                    size: 72,
                    radius: 14,
                    emojiSize: 34,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pilihFoto,
                          icon: const Icon(Icons.photo_library_outlined,
                              size: 18),
                          label: Text(
                            _photoPath == null
                                ? 'Pilih dari galeri'
                                : 'Ganti foto',
                          ),
                        ),
                        if (_photoPath != null) ...[
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: _hapusFoto,
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: AppColors.dangerMid,
                            ),
                            label: const Text(
                              'Hapus foto',
                              style: TextStyle(color: AppColors.dangerMid),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _photoPath == null
                    ? 'Belum ada foto. Barang memakai emoji di bawah — pilih '
                        'salah satu, atau ambil foto dari galeri HP.'
                    : 'Foto ini akan tampil di daftar barang, kasir, dan '
                        'peringatan stok.',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _emojis.map((e) {
                  // Emoji ditandai terpilih hanya kalau tidak ada foto, supaya
                  // pemilik tidak bingung mana yang sebenarnya berlaku.
                  final isSelected = _photoPath == null && _emoji == e;
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
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nama produk'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _category = v ?? 'Sembako'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _unit,
                      decoration: const InputDecoration(labelText: 'Satuan'),
                      items: satuanTersedia
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Satuan dipakai di struk dan laporan — misalnya "2 kg" '
                'alih-alih sekadar "2".'
                '${Satuan.bolehPecahan(_unit) ? ' Satuan ini boleh dijual '
                    'sebagian (mis. ¼ kg).' : ' Satuan ini dihitung bulat.'}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Harga modal',
                        prefixText: 'Rp ',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sellPriceController,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Harga jual',
                        prefixText: 'Rp ',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(labelText: 'Stok awal'),
                      validator: (v) {
                        final n = Satuan.baca(v);
                        if (n == null) return 'Wajib diisi';
                        if (n < 0) return 'Tidak boleh negatif';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _minStockController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Min. stok',
                        hintText: '5',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Supplier — dipilih dari data supplier yang bisa diedit di Profil.
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Supplier',
                      style:
                          TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addSupplier,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Supplier baru'),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _supplier,
                decoration: const InputDecoration(),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Tidak ada supplier'),
                  ),
                  ...supplierNames.map(
                    (name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _supplier = v ?? ''),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isEditing ? 'Simpan Perubahan' : 'Tambah Produk'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
