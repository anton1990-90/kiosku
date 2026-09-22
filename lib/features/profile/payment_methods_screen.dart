import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/payment_method_model.dart';
import '../../providers/payment_method_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Metode pembayaran — aktifkan, ubah nama, tambah, atau hapus.
///
/// Metode yang aktif muncul sebagai pilihan di layar Kasir. Menonaktifkan
/// sebuah metode tidak menghapus riwayat transaksi yang sudah memakainya.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  /// Ubah nama metode jadi kode yang aman disimpan di database.
  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _addMethod() async {
    final name = await _promptName(
      title: 'Metode pembayaran baru',
      label: 'Nama metode',
      hint: 'Contoh: Transfer BCA',
    );
    if (name == null || name.isEmpty || !mounted) return;

    final code = _slugify(name);
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama metode tidak valid. Gunakan huruf atau angka.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final exists = ref
        .read(paymentMethodProvider)
        .methods
        .any((m) => m.code == code);
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Metode dengan nama itu sudah ada.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.warningMid,
        ),
      );
      return;
    }

    await ref
        .read(paymentMethodProvider.notifier)
        .addMethod(name: name, code: code);
  }

  Future<void> _rename(PaymentMethodModel method) async {
    final name = await _promptName(
      title: 'Ubah nama metode',
      label: 'Nama metode',
      initial: method.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    await ref.read(paymentMethodProvider.notifier).renameMethod(method, name);
  }

  Future<String?> _promptName({
    required String title,
    required String label,
    String? initial,
    String? hint,
  }) async {
    final controller = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: label, hintText: hint),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _delete(PaymentMethodModel method) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus metode ini?'),
        content: Text(
          '"${method.name}" akan dihapus dari daftar pilihan di Kasir.\n\n'
          'Transaksi lama yang memakai metode ini tetap tersimpan dan '
          'laporannya tidak berubah.',
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
      await ref.read(paymentMethodProvider.notifier).deleteMethod(method.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentMethodProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Metode Pembayaran'),
        actions: [
          IconButton(
            tooltip: 'Tambah metode',
            onPressed: _addMethod,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addMethod,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Metode yang aktif muncul sebagai pilihan pembayaran di '
                    'layar Kasir. Matikan yang tidak Anda terima supaya kasir '
                    'tidak salah pilih.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.infoMid,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (state.methods.isEmpty)
                  const EmptyState(
                    icon: Icons.payments_outlined,
                    title: 'Belum ada metode pembayaran',
                    subtitle: 'Tambahkan minimal satu, misalnya Tunai.',
                  )
                else
                  ...state.methods.map((m) => _methodTile(m)),
              ],
            ),
    );
  }

  Widget _methodTile(PaymentMethodModel method) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 14, right: 6),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: method.isActive
                ? AppColors.primaryLight
                : AppColors.bgSoft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(
            Icons.payments_outlined,
            size: 18,
            color: method.isActive
                ? AppColors.primary
                : AppColors.textTertiary,
          ),
        ),
        title: Text(
          method.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: method.isActive
                ? AppColors.textMain
                : AppColors.textTertiary,
          ),
        ),
        subtitle: Text(
          method.isActive ? 'Aktif di Kasir' : 'Tidak dipakai',
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: method.isActive,
              activeColor: AppColors.primary,
              onChanged: (v) => ref
                  .read(paymentMethodProvider.notifier)
                  .setActive(method.id!, v),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
              onSelected: (value) {
                if (value == 'rename') {
                  _rename(method);
                } else if (value == 'delete') {
                  _delete(method);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('Ubah nama')),
                PopupMenuItem(value: 'delete', child: Text('Hapus')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
