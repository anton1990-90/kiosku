import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/product_model.dart';
import '../../providers/product_provider.dart';
import 'restok_sheet.dart';

/// Daftar lengkap produk yang stoknya menipis atau sudah habis.
///
/// Dibuka dari beranda lewat kartu "Stok menipis". Setiap baris bisa diketuk
/// untuk langsung menambah stok.
class StokMenipisScreen extends ConsumerStatefulWidget {
  const StokMenipisScreen({super.key});

  @override
  ConsumerState<StokMenipisScreen> createState() => _StokMenipisScreenState();
}

class _StokMenipisScreenState extends ConsumerState<StokMenipisScreen> {
  /// 'semua' | 'habis' | 'menipis'
  String _filter = 'semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productProvider.notifier).loadProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);

    final semua = productState.products
        .where((p) => p.stock <= p.minStock)
        .toList()
      ..sort((a, b) => a.stock.compareTo(b.stock));

    final habis = semua.where((p) => p.stock == 0).toList();
    final menipis = semua.where((p) => p.stock > 0).toList();

    final tampil = switch (_filter) {
      'habis' => habis,
      'menipis' => menipis,
      _ => semua,
    };

    // Uang selalu bulat: selisih stok boleh pecahan, rupiahnya tidak.
    final nilaiBelanja = semua
        .fold<double>(0, (s, p) => s + (p.minStock * 3 - p.stock) * p.costPrice)
        .round();

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Stok Menipis'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(productProvider.notifier).loadProducts(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(productProvider.notifier).loadProducts(),
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _ringkasan(semua.length, habis.length, menipis.length, nilaiBelanja),
              const SizedBox(height: 16),
              _filterChips(semua.length, habis.length, menipis.length),
              const SizedBox(height: 16),
              if (tampil.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 52, color: AppColors.successMid),
                      SizedBox(height: 12),
                      Text(
                        'Semua stok aman',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successMid,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Tidak ada produk yang perlu direstok.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...tampil.map(_kartuProduk),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ringkasan(int total, int habis, int menipis, int nilaiBelanja) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _angka('$total', 'Perlu perhatian', AppColors.dangerMid),
              ),
              Expanded(
                child: _angka('$habis', 'Habis', AppColors.dangerMid),
              ),
              Expanded(
                child: _angka('$menipis', 'Menipis', AppColors.warningMid),
              ),
            ],
          ),
          const Divider(height: 22),
          Row(
            children: [
              const Icon(Icons.shopping_cart_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Perkiraan modal untuk mengisi ulang sampai 3x minimum',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                Formatters.rupiahCompact(nilaiBelanja),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _angka(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _filterChips(int semua, int habis, int menipis) {
    final options = [
      ('semua', 'Semua ($semua)'),
      ('habis', 'Habis ($habis)'),
      ('menipis', 'Menipis ($menipis)'),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isActive = _filter == o.$1;
        return GestureDetector(
          onTap: () => setState(() => _filter = o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.bgCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Text(
              o.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _kartuProduk(ProductModel p) {
    final habis = p.stock == 0;
    final kurang = p.minStock - p.stock;
    // `1.0`, bukan `1`: kalau satu cabang `double` dan satu `int`, tipe hasil
    // percabangan ini adalah `num` — dan `Formatters.jumlah` menuntut `double`.
    final saran = kurang > 0 ? kurang : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: habis ? AppColors.danger : AppColors.warning,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(p.emoji ?? '📦',
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.category} · ${p.supplier ?? 'Tanpa supplier'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: habis
                      ? AppColors.dangerLight
                      : AppColors.warningLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  habis ? 'HABIS' : 'SISA ${Formatters.jumlah(p.stock)}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: habis ? AppColors.dangerMid : AppColors.warningMid,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _baris('Stok sekarang',
              '${Formatters.jumlah(p.stock)} ${p.unit}'),
          _baris('Batas minimum',
              '${Formatters.jumlah(p.minStock)} ${p.unit}'),
          _baris('Harga modal', Formatters.rupiah(p.costPrice)),
          _baris('Harga jual', Formatters.rupiah(p.sellPrice)),
          _baris('Nilai stok tersisa',
              Formatters.rupiah((p.stock * p.costPrice).round())),
          if (p.barcode != null && p.barcode!.isNotEmpty)
            _baris('Barcode', p.barcode!),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 14, color: AppColors.infoMid),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Saran restok ${Formatters.jumlah(saran)} ${p.unit} '
                          '(${Formatters.rupiahCompact((saran * p.costPrice).round())})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.infoMid,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => showRestokSheet(context, p),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Restok'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _baris(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textTertiary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
