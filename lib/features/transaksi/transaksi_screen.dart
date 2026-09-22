import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';

/// Daftar transaksi penjualan beserta rinciannya.
///
/// Dibuka dari beranda lewat kartu "Transaksi hari ini". Periodenya bisa
/// diganti ke mingguan atau bulanan untuk menelusuri transaksi lama.
class TransaksiScreen extends ConsumerStatefulWidget {
  const TransaksiScreen({super.key});

  @override
  ConsumerState<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends ConsumerState<TransaksiScreen> {
  final _repo = AccountingRepository();

  ReportPeriod _period = ReportPeriod.today();
  List<SaleWithItems> _data = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final data = await _repo.getSalesWithItems(_period.start, _period.end);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _gantiPeriode(ReportPeriod periode) async {
    setState(() => _period = periode);
    await _muat();
  }

  int get _totalPenjualan =>
      _data.fold(0, (s, t) => s + t.totalAmount);

  int get _totalLaba => _data.fold(0, (s, t) => s + t.totalProfit);

  int get _totalItem => _data.fold(0, (s, t) => s + t.totalItems);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muat,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _muat,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _tabs(),
              const SizedBox(height: 12),
              _navigasi(),
              const SizedBox(height: 16),
              _ringkasan(),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_data.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 52, color: AppColors.textTertiary),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Transaksi dari menu Kasir akan muncul di sini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._data.map(_kartuTransaksi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
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
          final isActive = _period.type == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _gantiPeriode(_period.withType(t.$1)),
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

  Widget _navigasi() {
    final canGoNext = _period.next() != null;
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
            onPressed: () => _gantiPeriode(_period.previous()),
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              _period.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () => _gantiPeriode(_period.next()!)
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext ? AppColors.textSecondary : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringkasan() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total penjualan',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_totalPenjualan),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laba kotor',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_totalLaba),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successMid,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _angka('${_data.length}', 'Transaksi'),
              ),
              Expanded(
                child: _angka('$_totalItem', 'Barang terjual'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _angka(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _kartuTransaksi(SaleWithItems trx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trx.customerName ?? 'Pelanggan umum',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.dateWithDay(trx.createdAt)} · '
                      '${Formatters.time(trx.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trx.invoiceNumber} · ${trx.paymentMethod.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(trx.totalAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'laba ${Formatters.rupiahCompact(trx.totalProfit)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.successMid,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (trx.isDebt) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined,
                      size: 14, color: AppColors.warningMid),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hutang · dibayar ${Formatters.rupiah(trx.paidAmount)} · '
                      'sisa ${Formatters.rupiah(trx.sisaBelumDibayar)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 18),
          ...trx.lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.productName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${l.quantity} x ${Formatters.rupiahCompact(l.sellPrice)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 88,
                    child: Text(
                      Formatters.rupiah(l.subtotal),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
