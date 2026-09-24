import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/report_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/report_export.dart';

/// Rincian lengkap produk yang terjual pada satu periode.
///
/// Layar ini bisa difilter harian, mingguan, atau bulanan, menampilkan total
/// pendapatan beserta labanya, dan bisa diekspor ke PDF maupun CSV.
class RincianPenjualanScreen extends ConsumerStatefulWidget {
  const RincianPenjualanScreen({super.key, this.initialPeriod});

  /// Periode awal — diisi dari layar Laporan supaya filternya nyambung.
  final ReportPeriod? initialPeriod;

  @override
  ConsumerState<RincianPenjualanScreen> createState() =>
      _RincianPenjualanScreenState();
}

class _RincianPenjualanScreenState
    extends ConsumerState<RincianPenjualanScreen> {
  final _reportRepo = ReportRepository();
  final _accountingRepo = AccountingRepository();

  late ReportPeriod _period;
  ReportSummary _summary = const ReportSummary();
  List<ReportItemDetail> _items = const [];
  List<({String name, int qty, int revenue, int profit})> _rekap = const [];
  bool _loading = true;
  bool _mengekspor = false;

  @override
  void initState() {
    super.initState();
    _period = widget.initialPeriod ?? ReportPeriod.today();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final summary = await _reportRepo.getSummary(_period.start, _period.end);
    final items = await _reportRepo.getItemDetails(
      _period.start,
      _period.end,
      limit: 2000,
    );
    final rekap = await _accountingRepo.getRekapProduk(
      _period.start,
      _period.end,
    );

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _items = items;
      _rekap = rekap;
      _loading = false;
    });
  }

  Future<void> _gantiPeriode(ReportPeriod periode) async {
    setState(() => _period = periode);
    await _muat();
  }

  Future<void> _pilihTanggal() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _period.anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      await _gantiPeriode(_period.withAnchor(picked));
    }
  }

  RincianPenjualanData _dataEkspor() {
    return RincianPenjualanData(
      storeName: ref.read(authProvider).user?.storeName ?? 'Toko',
      period: _period,
      summary: _summary,
      items: _items,
      rekap: _rekap,
    );
  }

  Future<void> _ekspor({required bool pdf}) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Belum ada data untuk diekspor pada periode ini.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _mengekspor = true);
    try {
      final data = _dataEkspor();
      if (pdf) {
        await ReportExport.shareRincianPenjualanPdf(data);
      } else {
        await ReportExport.shareRincianPenjualanCsv(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _mengekspor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Kelompokkan per hari, urut dari yang terbaru.
    final grouped = <String, List<ReportItemDetail>>{};
    for (final item in _items) {
      final key =
          '${item.soldAt.year}-${item.soldAt.month}-${item.soldAt.day}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Rincian Produk Terjual'),
        actions: [
          if (_mengekspor)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: 'Ekspor',
              icon: const Icon(Icons.ios_share),
              onSelected: (v) => _ekspor(pdf: v == 'pdf'),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined,
                        color: AppColors.danger),
                    title: Text('Ekspor PDF'),
                  ),
                ),
                PopupMenuItem(
                  value: 'csv',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.table_chart_outlined,
                        color: AppColors.successMid),
                    title: Text('Ekspor CSV (Excel)'),
                  ),
                ),
              ],
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
            const SizedBox(height: 12),
            _tombolEkspor(),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (_items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inventory_2_outlined,
                        size: 52, color: AppColors.textTertiary),
                    SizedBox(height: 12),
                    Text(
                      'Belum ada produk terjual',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Coba pilih periode lain.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              if (_rekap.isNotEmpty) ...[
                _rekapProduk(),
                const SizedBox(height: 16),
              ],
              ...keys.map((key) {
                final list = grouped[key]!;
                final total = list.fold<int>(0, (s, i) => s + i.subtotal);
                final laba = list.fold<int>(0, (s, i) => s + i.profit);

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
                              Formatters.dateWithDay(list.first.soldAt),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                          Text(
                            '${Formatters.rupiah(total)} · laba '
                            '${Formatters.rupiahCompact(laba)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...list.map(_barisItem),
                    const SizedBox(height: 8),
                  ],
                );
              }),
            ],
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
            tooltip: 'Periode sebelumnya',
            onPressed: () => _gantiPeriode(_period.previous()),
            icon: const Icon(Icons.chevron_left,
                color: AppColors.textSecondary),
          ),
          Expanded(
            child: InkWell(
              onTap: _pilihTanggal,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      _period.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Ketuk untuk pilih tanggal',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Periode berikutnya',
            onPressed: canGoNext ? () => _gantiPeriode(_period.next()!) : null,
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
                'Total pendapatan',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_summary.totalSales),
                style: const TextStyle(
                  fontSize: 17,
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
                'Total laba',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_summary.totalProfit),
                style: const TextStyle(
                  fontSize: 15,
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
                child: _angka('${_summary.transactions}', 'Transaksi'),
              ),
              Expanded(
                child: _angka(
                    Formatters.jumlah(_summary.itemsSold), 'Barang terjual'),
              ),
              Expanded(
                child: _angka('${_items.length}', 'Baris rincian'),
              ),
            ],
          ),
          if (_items.isNotEmpty) ...[
            const Divider(height: 20),
            _ringkasanStatus(),
          ],
        ],
      ),
    );
  }

  /// Ringkasan status pembayaran **per nota**. Satu nota bisa berisi beberapa
  /// barang, jadi dihitung sekali saja per nomor nota — kalau tidak, nota
  /// dengan 5 barang akan terhitung sebagai 5 transaksi piutang.
  Widget _ringkasanStatus() {
    final sudahDihitung = <String>{};
    var tunai = 0;
    var piutang = 0;
    var piutangLunas = 0;
    var sisa = 0;

    for (final item in _items) {
      if (!sudahDihitung.add(item.invoiceNumber)) continue;
      if (!item.isDebt) {
        tunai++;
      } else if (item.unpaidAmount > 0) {
        piutang++;
        sisa += item.unpaidAmount;
      } else {
        piutangLunas++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Status pembayaran (per nota)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _angkaStatus('$tunai', 'Cash', AppColors.successMid),
            ),
            Expanded(
              child: _angkaStatus('$piutang', 'Piutang', AppColors.dangerMid),
            ),
            Expanded(
              child: _angkaStatus('$piutangLunas', 'Lunas', AppColors.infoMid),
            ),
          ],
        ),
        if (sisa > 0) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Sisa piutang belum dibayar: ${Formatters.rupiah(sisa)}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.dangerMid,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _angkaStatus(String value, String label, Color warna) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: warna,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _angka(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _tombolEkspor() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _mengekspor ? null : () => _ekspor(pdf: true),
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
            label: const Text('Ekspor PDF'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _mengekspor ? null : () => _ekspor(pdf: false),
            icon: const Icon(Icons.table_chart_outlined, size: 18),
            label: const Text('Ekspor CSV'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rekapProduk() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rekap per produk',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 12),
          ..._rekap.asMap().entries.map((entry) {
            final i = entry.key;
            final r = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: i == 0 ? AppColors.accentLight : AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: i == 0
                              ? AppColors.accentMid
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Formatters.rupiah(r.revenue),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                        ),
                      ),
                      Text(
                        '${r.qty} pcs · laba ${Formatters.rupiahCompact(r.profit)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.successMid,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _barisItem(ReportItemDetail item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              Formatters.time(item.soldAt),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.jumlah(item.quantity)} x '
                  '${Formatters.rupiah(item.sellPrice)}'
                  '${item.customerName != null && item.customerName!.isNotEmpty ? ' · ${item.customerName}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${item.invoiceNumber} · ${item.paymentMethod}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _badgeStatus(item),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formatters.rupiah(item.subtotal),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                'laba ${Formatters.rupiahCompact(item.profit)}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.successMid,
                ),
              ),
              if (item.isPiutang) ...[
                const SizedBox(height: 1),
                Text(
                  'sisa ${Formatters.rupiahCompact(item.unpaidAmount)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dangerMid,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Badge status pembayaran satu baris rincian. Tujuannya supaya jelas
  /// transaksi ini cash, piutang yang belum dibayar, atau piutang yang sudah
  /// lunas — tanpa harus membuka detail nota.
  Widget _badgeStatus(ReportItemDetail item) {
    late final Color warna;
    late final Color latar;
    late final IconData ikon;

    if (!item.isDebt) {
      warna = AppColors.successMid;
      latar = AppColors.successLight;
      ikon = Icons.payments_outlined;
    } else if (item.unpaidAmount > 0) {
      warna = AppColors.dangerMid;
      latar = AppColors.dangerLight;
      ikon = Icons.schedule;
    } else {
      warna = AppColors.infoMid;
      latar = AppColors.infoLight;
      ikon = Icons.verified_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ikon, size: 10, color: warna),
          const SizedBox(width: 3),
          Text(
            item.paymentStatusLabel,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: warna,
            ),
          ),
        ],
      ),
    );
  }
}
