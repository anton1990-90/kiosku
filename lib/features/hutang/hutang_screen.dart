import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/debt_model.dart';
import '../../providers/debt_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Halaman Hutang & Piutang.
///
/// Piutang = pelanggan berhutang ke toko. Hutang = toko berhutang ke supplier.
class HutangScreen extends ConsumerStatefulWidget {
  const HutangScreen({super.key});

  @override
  ConsumerState<HutangScreen> createState() => _HutangScreenState();
}

class _HutangScreenState extends ConsumerState<HutangScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(debtProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Hutang & Piutang'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(debtProvider.notifier).loadDebts(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/hutang/tambah'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catat hutang'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(debtProvider.notifier).loadDebts(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _summaryCards(state),
            const SizedBox(height: 16),
            _typeFilter(state),
            const SizedBox(height: 10),
            _statusFilter(state),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: (v) => ref.read(debtProvider.notifier).setSearch(v),
              decoration: InputDecoration(
                hintText: 'Cari nama pelanggan atau supplier',
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary),
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
                          ref.read(debtProvider.notifier).setSearch('');
                        },
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (state.debts.isEmpty)
              const EmptyState(
                icon: Icons.handshake_outlined,
                title: 'Belum ada catatan hutang',
                subtitle:
                    'Catat piutang pelanggan dan hutang ke supplier supaya '
                    'tidak ada yang terlewat.',
              )
            else
              ...state.debts.map((d) => _debtCard(d)),
          ],
        ),
      ),
    );
  }

  Widget _summaryCards(DebtState state) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(
            label: 'Piutang',
            sublabel: '${state.piutangCount} orang',
            value: Formatters.rupiahCompact(state.totalPiutang),
            icon: Icons.south_west,
            color: AppColors.successMid,
            bgColor: AppColors.successLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryTile(
            label: 'Hutang',
            sublabel: '${state.hutangCount} supplier',
            value: Formatters.rupiahCompact(state.totalHutang),
            icon: Icons.north_east,
            color: AppColors.dangerMid,
            bgColor: AppColors.dangerLight,
          ),
        ),
      ],
    );
  }

  Widget _typeFilter(DebtState state) {
    const options = [
      ('semua', 'Semua'),
      (DebtType.piutang, 'Piutang'),
      (DebtType.hutang, 'Hutang'),
    ];
    return Row(
      children: options.map((o) {
        final isActive = state.filterType == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => ref.read(debtProvider.notifier).setFilterType(o.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
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
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _statusFilter(DebtState state) {
    const options = [
      ('semua', 'Semua status'),
      (DebtStatus.belumLunas, 'Belum lunas'),
      (DebtStatus.lunas, 'Lunas'),
    ];
    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isActive = state.filterStatus == o.$1;
        return GestureDetector(
          onTap: () => ref.read(debtProvider.notifier).setFilterStatus(o.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primaryLight : AppColors.bgSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              o.$2,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primaryDark : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _debtCard(DebtModel debt) {
    final isPiutang = debt.isPiutang;
    final accent = isPiutang ? AppColors.successMid : AppColors.dangerMid;
    final accentLight = isPiutang ? AppColors.successLight : AppColors.dangerLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isPiutang ? Icons.south_west : Icons.north_east,
                  size: 20,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.partyName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _chip(
                          isPiutang ? 'Piutang' : 'Hutang',
                          accent,
                          accentLight,
                        ),
                        if (debt.isLunas) ...[
                          const SizedBox(width: 6),
                          _chip('Lunas', AppColors.primaryDark,
                              AppColors.primaryLight),
                        ],
                        if (debt.isOverdue) ...[
                          const SizedBox(width: 6),
                          _chip('Terlambat', AppColors.dangerMid,
                              AppColors.dangerLight),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(debt.remaining),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: debt.isLunas ? AppColors.textTertiary : accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    debt.isLunas
                        ? 'dari ${Formatters.rupiah(debt.amount)}'
                        : 'sisa dari ${Formatters.rupiah(debt.amount)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (!debt.isLunas) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: debt.paidRatio,
                minHeight: 6,
                backgroundColor: AppColors.bgSoft,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Dibayar ${Formatters.rupiah(debt.paidAmount)} '
              '(${(debt.paidRatio * 100).round()}%)',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (debt.dueDate != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  debt.isOverdue ? Icons.warning_amber_rounded : Icons.event,
                  size: 14,
                  color: debt.isOverdue
                      ? AppColors.dangerMid
                      : AppColors.textTertiary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Jatuh tempo ${Formatters.date(debt.dueDate!)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        debt.isOverdue ? FontWeight.w600 : FontWeight.w400,
                    color: debt.isOverdue
                        ? AppColors.dangerMid
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (debt.note != null && debt.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              debt.note!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!debt.isLunas)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentSheet(debt),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text('Bayar'),
                  ),
                )
              else
                const Expanded(
                  child: Text(
                    'Sudah lunas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successMid,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Riwayat pembayaran',
                onPressed: () => _showHistory(debt),
                icon: const Icon(Icons.history, color: AppColors.textSecondary),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => context.push('/hutang/edit', extra: debt),
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.textSecondary),
              ),
              IconButton(
                tooltip: 'Hapus',
                onPressed: () => _confirmDelete(debt),
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ------------------------------------------------------------- pembayaran

  Future<void> _showPaymentSheet(DebtModel debt) async {
    final amountController =
        TextEditingController(text: debt.remaining.toString());
    final noteController = TextEditingController();
    final formKey = GlobalKey<FormState>();

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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bayar — ${debt.partyName}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sisa ${Formatters.rupiah(debt.remaining)}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah dibayar',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Masukkan jumlah yang benar';
                  if (n > debt.remaining) {
                    return 'Melebihi sisa hutang';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        amountController.text = debt.remaining.toString(),
                    child: const Text('Lunasi'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => amountController.text =
                        (debt.remaining ~/ 2).toString(),
                    child: const Text('Setengah'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Catatan (opsional)',
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    final amount = int.parse(amountController.text.trim());
                    Navigator.pop(sheetContext);
                    await ref.read(debtProvider.notifier).payDebt(
                          debtId: debt.id!,
                          amount: amount,
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pembayaran ${Formatters.rupiah(amount)} dicatat',
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('Simpan pembayaran'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    amountController.dispose();
    noteController.dispose();
  }

  Future<void> _showHistory(DebtModel debt) async {
    final payments =
        await ref.read(debtProvider.notifier).getPayments(debt.id!);
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Riwayat pembayaran — ${debt.partyName}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 12),
            if (payments.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'Belum ada pembayaran.',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              )
            else
              ...payments.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline,
                          size: 18, color: AppColors.successMid),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formatters.dateTime(p.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (p.note != null && p.note!.isNotEmpty)
                              Text(
                                p.note!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        Formatters.rupiah(p.amount),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(DebtModel debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus catatan ini?'),
        content: Text(
          'Catatan ${debt.isPiutang ? 'piutang' : 'hutang'} untuk '
          '${debt.partyName} akan dihapus beserta riwayat pembayarannya. '
          'Tindakan ini tidak bisa dibatalkan.',
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
      await ref.read(debtProvider.notifier).deleteDebt(debt.id!);
    }
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _SummaryTile({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          Text(
            sublabel,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}
