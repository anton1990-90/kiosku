import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/supplier_model.dart';
import '../../providers/supplier_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Supplier — data pemasok yang bisa ditambah, diedit, dan dihapus.
/// Nama supplier di sini dipakai sebagai pilihan di form produk.
class SupplierScreen extends ConsumerStatefulWidget {
  const SupplierScreen({super.key});

  @override
  ConsumerState<SupplierScreen> createState() => _SupplierScreenState();
}

class _SupplierScreenState extends ConsumerState<SupplierScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supplierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Supplier')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah supplier'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(supplierProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Cari supplier',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: state.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(supplierProvider.notifier).setSearch('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: state.isLoading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : state.suppliers.isEmpty
                    ? EmptyState(
                        icon: Icons.people_outline,
                        title: state.search.isEmpty
                            ? 'Belum ada supplier'
                            : 'Supplier tidak ditemukan',
                        subtitle: state.search.isEmpty
                            ? 'Tambahkan supplier supaya bisa dipilih saat '
                                'menambah produk.'
                            : 'Coba kata kunci lain.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: state.suppliers.length,
                        itemBuilder: (context, i) =>
                            _supplierTile(state.suppliers[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _supplierTile(SupplierModel supplier) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                supplier.initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.infoMid,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (supplier.phone != null && supplier.phone!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        supplier.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (supplier.address != null &&
                    supplier.address!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          supplier.address!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (supplier.note != null && supplier.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    supplier.note!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Column(
            children: [
              if (supplier.phone != null && supplier.phone!.isNotEmpty)
                IconButton(
                  tooltip: 'Hubungi via WhatsApp',
                  onPressed: () => _openWhatsApp(supplier.phone!),
                  icon: const Icon(Icons.chat_outlined,
                      size: 18, color: AppColors.successMid),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openForm(supplier: supplier);
                  } else if (value == 'delete') {
                    _confirmDelete(supplier);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Hapus')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsApp(String phone) async {
    // Normalisasi nomor Indonesia: 08xx -> 628xx.
    var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) {
      digits = '62${digits.substring(1)}';
    }
    try {
      await launchUrl(
        Uri.parse('https://wa.me/$digits'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak bisa membuka WhatsApp.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Form tambah / edit supplier.
  Future<void> _openForm({SupplierModel? supplier}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: supplier?.name ?? '');
    final phoneController = TextEditingController(text: supplier?.phone ?? '');
    final addressController =
        TextEditingController(text: supplier?.address ?? '');
    final noteController = TextEditingController(text: supplier?.note ?? '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
        ),
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  supplier == null ? 'Supplier baru' : 'Edit supplier',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: supplier == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nama supplier'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor HP / WhatsApp (opsional)',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: addressController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Alamat (opsional)',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: noteController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    hintText: 'Contoh: antar tiap Senin',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final now = DateTime.now();
                      final model = SupplierModel(
                        id: supplier?.id,
                        name: nameController.text.trim(),
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        address: addressController.text.trim().isEmpty
                            ? null
                            : addressController.text.trim(),
                        note: noteController.text.trim().isEmpty
                            ? null
                            : noteController.text.trim(),
                        createdAt: supplier?.createdAt ?? now,
                        updatedAt: now,
                      );

                      Navigator.pop(sheetContext);
                      final notifier = ref.read(supplierProvider.notifier);
                      if (supplier == null) {
                        await notifier.addSupplier(model);
                      } else {
                        await notifier.updateSupplier(model);
                      }
                    },
                    child: Text(supplier == null ? 'Tambah' : 'Simpan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    noteController.dispose();
  }

  Future<void> _confirmDelete(SupplierModel supplier) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus supplier?'),
        content: Text(
          '"${supplier.name}" akan dihapus.\n\n'
          'Produk yang memakai nama supplier ini tetap menyimpan namanya, dan '
          'catatan hutang yang terkait tidak ikut terhapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(supplierProvider.notifier).deleteSupplier(supplier.id!);
    }
  }
}
