import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Pelanggan — buku pelanggan yang bisa ditambah, diedit, dan dihapus.
///
/// Menjawab dua pertanyaan yang sebelumnya tidak bisa dijawab aplikasi ini:
/// "siapa saja yang masih berhutang?" dan "berapa nomor HP orang itu?".
/// Nama pelanggan yang dipilih di sini dipakai di kasir dan form hutang.
class CustomerScreen extends ConsumerStatefulWidget {
  const CustomerScreen({super.key});

  @override
  ConsumerState<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends ConsumerState<CustomerScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah pelanggan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(customerProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Cari pelanggan',
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
                          ref.read(customerProvider.notifier).setSearch('');
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
                : state.pelanggan.isEmpty
                    ? EmptyState(
                        icon: Icons.person_outline,
                        title: state.search.isEmpty
                            ? 'Belum ada pelanggan'
                            : 'Pelanggan tidak ditemukan',
                        subtitle: state.search.isEmpty
                            ? 'Tambahkan pelanggan supaya nama dan nomor HP-nya '
                                'tidak perlu diketik ulang, dan piutangnya bisa '
                                'dilihat per orang.'
                            : 'Coba kata kunci lain.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                        itemCount: state.pelanggan.length,
                        itemBuilder: (context, i) =>
                            _kartuPelanggan(state.pelanggan[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _kartuPelanggan(CustomerRingkasan ringkas) {
    final pelanggan = ringkas.customer;

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
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                pelanggan.initials,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
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
                  pelanggan.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                if (pelanggan.phone != null &&
                    pelanggan.phone!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Text(
                        pelanggan.phone!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (pelanggan.address != null &&
                    pelanggan.address!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppColors.textTertiary),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          pelanggan.address!,
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
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (ringkas.adaPiutang)
                      _lencana(
                        'Piutang ${Formatters.rupiah(ringkas.totalPiutang)}',
                        AppColors.dangerLight,
                        AppColors.dangerMid,
                      ),
                    if (ringkas.jumlahTransaksi > 0)
                      _lencana(
                        'Belanja ${Formatters.rupiahCompact(ringkas.totalBelanja)}'
                        ' · ${ringkas.jumlahTransaksi} nota',
                        AppColors.bgSoft,
                        AppColors.textSecondary,
                      ),
                  ],
                ),
                if (ringkas.transaksiTerakhir != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Terakhir ${Formatters.date(ringkas.transaksiTerakhir!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
                if (pelanggan.note != null && pelanggan.note!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    pelanggan.note!,
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
              if (pelanggan.phone != null && pelanggan.phone!.isNotEmpty)
                IconButton(
                  tooltip: 'Hubungi via WhatsApp',
                  onPressed: () => _openWhatsApp(pelanggan.phone!),
                  icon: const Icon(Icons.chat_outlined,
                      size: 18, color: AppColors.successMid),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppColors.textSecondary),
                onSelected: (value) {
                  if (value == 'edit') {
                    _openForm(pelanggan: pelanggan);
                  } else if (value == 'delete') {
                    _confirmDelete(pelanggan);
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

  Widget _lencana(String teks, Color latar, Color warna) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        teks,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: warna,
        ),
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

  /// Form tambah / edit pelanggan.
  Future<void> _openForm({CustomerModel? pelanggan}) async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: pelanggan?.name ?? '');
    final phoneController =
        TextEditingController(text: pelanggan?.phone ?? '');
    final addressController =
        TextEditingController(text: pelanggan?.address ?? '');
    final noteController = TextEditingController(text: pelanggan?.note ?? '');

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
                  pelanggan == null ? 'Pelanggan baru' : 'Edit pelanggan',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  autofocus: pelanggan == null,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nama pelanggan'),
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
                    hintText: 'Contoh: langganan beras, bayar tiap Jumat',
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
                      final model = CustomerModel(
                        id: pelanggan?.id,
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
                        createdAt: pelanggan?.createdAt ?? now,
                        updatedAt: now,
                      );

                      Navigator.pop(sheetContext);
                      final notifier = ref.read(customerProvider.notifier);
                      if (pelanggan == null) {
                        await notifier.addCustomer(model);
                      } else {
                        await notifier.updateCustomer(model);
                      }
                    },
                    child: Text(pelanggan == null ? 'Tambah' : 'Simpan'),
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

  Future<void> _confirmDelete(CustomerModel pelanggan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus pelanggan?'),
        content: Text(
          '"${pelanggan.name}" akan dihapus dari buku pelanggan.\n\n'
          'Riwayat penjualan dan catatan piutangnya TIDAK ikut terhapus — '
          'namanya tetap tersimpan di tiap nota dan catatan hutang.',
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
      await ref.read(customerProvider.notifier).deleteCustomer(pelanggan.id!);
    }
  }
}
