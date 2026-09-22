import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../data/models/cash_model.dart';
import '../../providers/cash_provider.dart';

/// Layar Kas — saldo, mutasi uang masuk/keluar, dan riwayat lengkapnya.
///
/// Setiap penjualan, pembayaran hutang, belanja stok, beban, dan prive
/// otomatis muncul di sini. Pengguna juga bisa mencatat mutasi manual.
class KasScreen extends ConsumerStatefulWidget {
  const KasScreen({super.key});

  @override
  ConsumerState<KasScreen> createState() => _KasScreenState();
}

class _KasScreenState extends ConsumerState<KasScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashProvider);
    final period = state.period;

    // Kelompokkan per tanggal, urut dari yang terbaru.
    final grouped = <String, List<CashTransaction>>{};
    for (final t in state.transactions) {
      final key = '${t.date.year}-${t.date.month}-${t.date.day}';
      grouped.putIfAbsent(key, () => []).add(t);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Kas'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(cashProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _bukaCatatKas,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catat kas'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(cashProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _kartuSaldo(state),
            const SizedBox(height: 14),
            _ringkasHariIni(state),
            const SizedBox(height: 18),
            _tabs(period),
            const SizedBox(height: 12),
            _navigasi(period, state.canGoNext),
            const SizedBox(height: 12),
            _filterJenis(state),
            const SizedBox(height: 16),
            if (state.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (state.transactions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.account_balance_wallet_outlined,
                        size: 52, color: AppColors.textTertiary),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada mutasi kas',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Transaksi penjualan dan pembayaran hutang akan muncul '
                      'di sini otomatis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...keys.map((key) {
                final list = grouped[key]!;
                final masuk = list
                    .where((t) => t.isMasuk)
                    .fold<int>(0, (s, t) => s + t.amount);
                final keluar = list
                    .where((t) => !t.isMasuk)
                    .fold<int>(0, (s, t) => s + t.amount);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 8, top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.bgSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              Formatters.dateWithDay(list.first.date),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                          if (masuk > 0)
                            Text(
                              '+${Formatters.rupiahCompact(masuk)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.successMid,
                              ),
                            ),
                          if (masuk > 0 && keluar > 0)
                            const SizedBox(width: 8),
                          if (keluar > 0)
                            Text(
                              '-${Formatters.rupiahCompact(keluar)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.dangerMid,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ...list.map(_barisKas),
                    const SizedBox(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- sub-bagian

  Widget _kartuSaldo(CashState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined,
                  size: 16, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                'Saldo kas',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.rupiah(state.saldo),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Uang tunai & saldo yang tercatat di aplikasi',
            style: TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _ringkasHariIni(CashState state) {
    return Row(
      children: [
        Expanded(
          child: _KotakRingkas(
            label: 'Uang masuk hari ini',
            value: state.todaySummary.masuk,
            icon: Icons.arrow_upward,
            color: AppColors.successMid,
            bgColor: AppColors.successLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _KotakRingkas(
            label: 'Uang keluar hari ini',
            value: state.todaySummary.keluar,
            icon: Icons.arrow_downward,
            color: AppColors.dangerMid,
            bgColor: AppColors.dangerLight,
          ),
        ),
      ],
    );
  }

  Widget _tabs(ReportPeriod period) {
    const tabs = [
      (ReportPeriodType.harian, 'Harian'),
      (ReportPeriodType.mingguan, 'Mingguan'),
      (ReportPeriodType.bulanan, 'Bulanan'),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: tabs.map((t) {
          final isActive = period.type == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(cashProvider.notifier).setType(t.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.bgCard : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _navigasi(ReportPeriod period, bool canGoNext) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Periode sebelumnya',
            onPressed: () => ref.read(cashProvider.notifier).goPrevious(),
            icon: const Icon(Icons.chevron_left,
                color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              period.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Periode berikutnya',
            onPressed:
                canGoNext ? () => ref.read(cashProvider.notifier).goNext() : null,
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext ? AppColors.textSecondary : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterJenis(CashState state) {
    const options = [
      ('semua', 'Semua'),
      (CashType.masuk, 'Uang masuk'),
      (CashType.keluar, 'Uang keluar'),
    ];

    return Wrap(
      spacing: 8,
      children: options.map((o) {
        final isActive = state.filterType == o.$1;
        return GestureDetector(
          onTap: () => ref.read(cashProvider.notifier).setFilterType(o.$1),
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

  Widget _barisKas(CashTransaction trx) {
    final masuk = trx.isMasuk;

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
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color:
                  masuk ? AppColors.successLight : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              masuk ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: masuk ? AppColors.successMid : AppColors.dangerMid,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trx.categoryLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  trx.note == null || trx.note!.isEmpty
                      ? Formatters.time(trx.date)
                      : '${Formatters.time(trx.date)} · ${trx.note!}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${masuk ? '+' : '-'}${Formatters.rupiah(trx.amount)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: masuk ? AppColors.successMid : AppColors.dangerMid,
            ),
          ),
          if (trx.refType == 'manual')
            IconButton(
              tooltip: 'Hapus catatan ini',
              visualDensity: VisualDensity.compact,
              onPressed: () => _konfirmasiHapus(trx),
              icon: const Icon(Icons.delete_outline,
                  size: 18, color: AppColors.textTertiary),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- aksi

  Future<void> _konfirmasiHapus(CashTransaction trx) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus catatan kas ini?'),
        content: Text(
          '${trx.categoryLabel} ${Formatters.rupiah(trx.amount)} akan dihapus '
          'dari riwayat kas.',
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

    if (yakin == true) {
      await ref.read(cashProvider.notifier).deleteTransaction(trx.id!);
    }
  }

  Future<void> _bukaCatatKas() async {
    final hasil = await showModalBottomSheet<_HasilKas>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CatatKasSheet(),
    );

    if (hasil == null || !mounted) return;

    await ref.read(cashProvider.notifier).addManual(
          type: hasil.type,
          amount: hasil.amount,
          category: hasil.category,
          note: hasil.note,
          date: hasil.date,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${hasil.type == CashType.masuk ? 'Uang masuk' : 'Uang keluar'} '
          '${Formatters.rupiah(hasil.amount)} dicatat',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ------------------------------------------------------------- sub-widgets

class _KotakRingkas extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _KotakRingkas({
    required this.label,
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
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            Formatters.rupiahCompact(value),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _HasilKas {
  final String type;
  final int amount;
  final String category;
  final String? note;
  final DateTime? date;

  const _HasilKas({
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    this.date,
  });
}

/// Panel catat mutasi kas manual.
class _CatatKasSheet extends StatefulWidget {
  const _CatatKasSheet();

  @override
  State<_CatatKasSheet> createState() => _CatatKasSheetState();
}

class _CatatKasSheetState extends State<_CatatKasSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String _type = CashType.masuk;
  String _category = CashCategory.modal;
  DateTime _tanggal = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<({String code, String label})> get _pilihanKategori {
    if (_type == CashType.masuk) {
      return const [
        (code: CashCategory.modal, label: 'Modal pemilik'),
        (code: CashCategory.lainnya, label: 'Lain-lain'),
      ];
    }
    return const [
      (code: CashCategory.lainnya, label: 'Lain-lain'),
    ];
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Tanggal mutasi kas',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) setState(() => _tanggal = picked);
  }

  @override
  Widget build(BuildContext context) {
    final isMasuk = _type == CashType.masuk;

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
              const Text(
                'Catat mutasi kas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _tombolJenis(
                      CashType.masuk,
                      'Uang masuk',
                      Icons.arrow_upward,
                      AppColors.successMid,
                      AppColors.successLight,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _tombolJenis(
                      CashType.keluar,
                      'Uang keluar',
                      Icons.arrow_downward,
                      AppColors.dangerMid,
                      AppColors.dangerLight,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Isi jumlah yang benar';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kategori'),
                items: _pilihanKategori
                    .map((k) => DropdownMenuItem(
                          value: k.code,
                          child: Text(k.label),
                        ))
                    .toList(),
                onChanged: (v) => setState(
                  () => _category = v ?? CashCategory.lainnya,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText: isMasuk
                      ? 'Contoh: setoran modal awal'
                      : 'Contoh: beli plastik kemasan',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pilihTanggal,
                icon: const Icon(Icons.event, size: 16),
                label: Text('Tanggal ${Formatters.date(_tanggal)}'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.infoLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.infoMid),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Untuk beban usaha dan prive, catat lewat Laporan '
                        'Keuangan supaya ikut terhitung di laporan laba rugi.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.infoMid,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.pop(
                          context,
                          _HasilKas(
                            type: _type,
                            amount: int.parse(_amountController.text.trim()),
                            category: _category,
                            note: _noteController.text.trim().isEmpty
                                ? null
                                : _noteController.text.trim(),
                            date: _tanggal,
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Simpan'),
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

  Widget _tombolJenis(
    String type,
    String label,
    IconData icon,
    Color color,
    Color bgColor,
  ) {
    final isActive = _type == type;
    return GestureDetector(
      onTap: () => setState(() {
        _type = type;
        _category = type == CashType.masuk
            ? CashCategory.modal
            : CashCategory.lainnya;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? bgColor : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? color : AppColors.border,
            width: isActive ? 1.4 : 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
