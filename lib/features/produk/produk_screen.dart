import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/product_model.dart';
import '../../providers/product_provider.dart';
import '../../shared/widgets/shared_widgets.dart';
import 'produk_form_screen.dart';

/// Produk screen — manage products, search, filter by category.
class ProdukScreen extends ConsumerStatefulWidget {
  const ProdukScreen({super.key});

  @override
  ConsumerState<ProdukScreen> createState() => _ProdukScreenState();
}

class _ProdukScreenState extends ConsumerState<ProdukScreen> {
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

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final products = productState.filtered;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text(
          'Produk',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ElevatedButton.icon(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final showService = prefs.getBool('show_service_option') ?? true;
                
                bool? isService = false;
                if (showService) {
                  isService = await showModalBottomSheet<bool>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const ListTile(
                            title: Text('Tambah Produk', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          ListTile(
                            leading: const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
                            title: const Text('Barang Fisik'),
                            subtitle: const Text('Barang yang memiliki stok fisik (contoh: minuman, beras)'),
                            onTap: () => Navigator.pop(ctx, false),
                          ),
                          ListTile(
                            leading: const Icon(Icons.handyman_outlined, color: AppColors.success),
                            title: const Text('Jasa / Layanan'),
                            subtitle: const Text('Tidak memiliki stok fisik (contoh: servis, cuci, paket)'),
                            onTap: () => Navigator.pop(ctx, true),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                if (isService == null || !mounted) return;

                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProdukFormScreen(isService: isService),
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Tambah'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                minimumSize: const Size(0, 36),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) async {
              if (val == 'toggle_jasa') {
                final prefs = await SharedPreferences.getInstance();
                final current = prefs.getBool('show_service_option') ?? true;
                await prefs.setBool('show_service_option', !current);
                if (mounted) setState(() {});
              }
            },
            itemBuilder: (ctx) {
              return [
                PopupMenuItem(
                  value: 'toggle_jasa',
                  child: FutureBuilder<SharedPreferences>(
                    future: SharedPreferences.getInstance(),
                    builder: (context, snapshot) {
                      final show = snapshot.data?.getBool('show_service_option') ?? true;
                      return Text(show ? 'Sembunyikan Opsi Jasa' : 'Tampilkan Opsi Jasa');
                    }
                  ),
                )
              ];
            }
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(productProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgSoft,
                hintText: 'Cari produk...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          // Category filters
          SizedBox(
            height: 44,
            child: Center(
              child: ListView.builder(
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryLight
                            : AppColors.bgCard,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Product list
          Expanded(
            child: productState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                    ? const EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'Belum ada produk',
                        subtitle: 'Tambahkan produk pertama Anda',
                      )
                    // Di tablet daftarnya dibatasi lebarnya supaya barisnya
                    // tidak melebar penuh dan tetap enak dibaca.
                    : Responsive.centered(
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final p = products[index];
                            return _ProductCard(
                              product: p,
                              onEdit: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ProdukFormScreen(product: p),
                                  ),
                                );
                              },
                              onDelete: () => _confirmDelete(context, p),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus produk?'),
        content: Text('Yakin ingin menghapus "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(productProvider.notifier).deleteProduct(product.id!);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  bool get _isExpiringSoon {
    if (product.expiredDate == null) return false;
    try {
      final date = DateTime.parse(product.expiredDate!);
      final diff = date.difference(DateTime.now()).inDays;
      return diff <= 30 && diff >= 0;
    } catch (_) {
      return false;
    }
  }

  bool get _hasExpired {
    if (product.expiredDate == null) return false;
    try {
      final date = DateTime.parse(product.expiredDate!);
      final today = DateTime.now();
      return date.isBefore(DateTime(today.year, today.month, today.day));
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          ProductIcon(
            photoPath: product.photoPath,
            emoji: product.emoji,
            size: 48,
            radius: 8,
            emojiSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      Formatters.rupiah(product.sellPrice),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Text(' · ',
                        style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
                    Text(
                      'Stok ${Formatters.jumlah(product.stock)} ${product.unit}',
                      style: TextStyle(
                        fontSize: 12,
                        color: product.stock <= product.minStock
                            ? AppColors.warningMid
                            : AppColors.textSecondary,
                        fontWeight: product.stock <= product.minStock
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                if (_hasExpired || _isExpiringSoon) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _hasExpired ? AppColors.dangerLight : AppColors.warningLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _hasExpired ? 'Sudah Kedaluwarsa' : 'Akan Kedaluwarsa',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _hasExpired ? AppColors.danger : AppColors.warningMid,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _actionButton(Icons.edit_outlined, AppColors.infoMid, onEdit),
          const SizedBox(width: 6),
          _actionButton(Icons.delete_outline, AppColors.dangerMid, onDelete),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
