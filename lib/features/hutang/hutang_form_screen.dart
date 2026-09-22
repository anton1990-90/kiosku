import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../providers/supplier_provider.dart';

/// Form tambah / edit catatan hutang atau piutang.
class HutangFormScreen extends ConsumerStatefulWidget {
  /// Kalau diisi, layar ini berubah menjadi mode edit.
  final DebtModel? debt;

  const HutangFormScreen({super.key, this.debt});

  @override
  ConsumerState<HutangFormScreen> createState() => _HutangFormScreenState();
}

class _HutangFormScreenState extends ConsumerState<HutangFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = DebtType.piutang;
  DateTime? _dueDate;

  /// 0 berarti "tidak dikaitkan" — DropdownButton tidak menampilkan item
  /// yang bernilai null, jadi perlu penanda sendiri.
  int _supplierId = 0;
  bool _saving = false;

  bool get isEditing => widget.debt != null;

  @override
  void initState() {
    super.initState();
    final d = widget.debt;
    if (d != null) {
      _nameController.text = d.partyName;
      _phoneController.text = d.partyPhone ?? '';
      _amountController.text = d.amount.toString();
      _noteController.text = d.note ?? '';
      _type = d.type;
      _dueDate = d.dueDate;
      _supplierId = d.supplierId ?? 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 5),
      helpText: 'Pilih tanggal jatuh tempo',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      // Simpan sebagai tanggal saja supaya perbandingan jatuh tempo konsisten.
      setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final amount = int.parse(_amountController.text.trim());
    final existing = widget.debt;

    final debt = DebtModel(
      id: existing?.id,
      partyName: _nameController.text.trim(),
      partyPhone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      type: _type,
      amount: amount,
      // Jangan sampai nilai terbayar melebihi nilai hutang baru.
      paidAmount: existing == null
          ? 0
          : (existing.paidAmount > amount ? amount : existing.paidAmount),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      dueDate: _dueDate,
      status: existing?.status ?? DebtStatus.belumLunas,
      supplierId: _type == DebtType.hutang && _supplierId != 0
          ? _supplierId
          : null,
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final notifier = ref.read(debtProvider.notifier);
    if (isEditing) {
      await notifier.updateDebt(debt);
    } else {
      await notifier.addDebt(debt);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final supplierState = ref.watch(supplierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Catatan' : 'Catat Hutang'),
      ),
      body: Form(
        key: _formKey,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Jenis
              const Text(
                'Jenis',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _typeOption(
                      value: DebtType.piutang,
                      label: 'Piutang',
                      hint: 'Pelanggan berhutang ke toko',
                      icon: Icons.south_west,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _typeOption(
                      value: DebtType.hutang,
                      label: 'Hutang',
                      hint: 'Toko berhutang ke supplier',
                      icon: Icons.north_east,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText:
                      _type == DebtType.piutang ? 'Nama pelanggan' : 'Nama supplier',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Nomor HP (opsional)',
                  prefixIcon:
                      Icon(Icons.phone_outlined, color: AppColors.textTertiary),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nilai hutang',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Masukkan nilai yang benar';
                  return null;
                },
              ),
              // Kaitkan ke supplier terdaftar kalau jenisnya hutang.
              if (_type == DebtType.hutang) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _supplierId,
                  decoration: const InputDecoration(
                    labelText: 'Supplier terdaftar (opsional)',
                  ),
                  items: [
                    const DropdownMenuItem<int>(
                      value: 0,
                      child: Text('Tidak dikaitkan'),
                    ),
                    ...supplierState.suppliers
                        .where((s) => s.id != null)
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: s.id!,
                            child: Text(s.name),
                          ),
                        ),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v ?? 0),
                ),
              ],
              const SizedBox(height: 16),
              // Jatuh tempo
              InkWell(
                onTap: _pickDueDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Jatuh tempo (opsional)',
                    suffixIcon: _dueDate == null
                        ? const Icon(Icons.event, color: AppColors.textTertiary)
                        : IconButton(
                            tooltip: 'Hapus tanggal',
                            icon: const Icon(Icons.close,
                                color: AppColors.textTertiary),
                            onPressed: () => setState(() => _dueDate = null),
                          ),
                  ),
                  child: Text(
                    _dueDate == null
                        ? 'Tidak ditentukan'
                        : Formatters.dateWithDay(_dueDate!),
                    style: TextStyle(
                      fontSize: 14,
                      color: _dueDate == null
                          ? AppColors.textTertiary
                          : AppColors.textMain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                  alignLabelWithHint: true,
                ),
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
                      : Text(isEditing ? 'Simpan Perubahan' : 'Simpan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeOption({
    required String value,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    final isActive = _type == value;
    final isPiutang = value == DebtType.piutang;
    final color = isPiutang ? AppColors.successMid : AppColors.dangerMid;
    final bgColor = isPiutang ? AppColors.successLight : AppColors.dangerLight;

    return GestureDetector(
      onTap: () => setState(() => _type = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isActive ? bgColor : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: isActive ? color : AppColors.textTertiary),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isActive ? color : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
