import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/report_models.dart';
import '../../providers/report_provider.dart';

/// Laporan penjualan — harian, mingguan, dan bulanan.
///
/// Laporan harian menampilkan rincian tiap produk yang terjual lengkap dengan
/// tanggal, jam, jumlah, harga satuan, dan subtotal.
class LaporanScreen extends ConsumerStatefulWidget {
  const LaporanScreen({super.key});

  @override
  ConsumerState<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends ConsumerState<LaporanScreen> {
  Future<void> _pickDate(ReportPeriod period) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: period.anchor,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Pilih tanggal laporan',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      await ref.read(reportProvider.notifier).jumpTo(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportProvider);
    final period = state.period;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Laporan'),
        actions: [
          if (!period.isCurrent)
            TextButton(
              onPressed: () => ref.read(reportProvider.notifier).goToday(),
              child: const Text('Hari ini'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => ref.read(reportProvider.notifier).loadReport(),
        child: Responsive.centered(
          ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _periodTabs(period),
            const SizedBox(height: 14),
            _dateNavigator(period, state.canGoNext),
            const SizedBox(height: 18),
            _summaryGrid(state.summary),
            const SizedBox(height: 16),
            if (period.type == ReportPeriodType.harian)
              _hourlyChart(state.items)
            else
              _dailyChart(state.dailyTotals, period),
            const SizedBox(height: 16),
            _last7DaysChart(state.last7Days),
            const SizedBox(height: 16),
            _productBarChart(
              judul: 'Produk terlaris',
              subjudul: 'Paling banyak terjual pada periode ini',
              produk: state.topProducts,
              warnaBatang: AppColors.primary,
            ),
            const SizedBox(height: 16),
            _productBarChart(
              judul: 'Produk kurang laku',
              subjudul: state.leastProducts.any((p) => p.quantity == 0)
                  ? 'Paling sedikit terjual, termasuk barang yang belum '
                      'terjual sama sekali'
                  : 'Paling sedikit terjual pada periode ini',
              produk: state.leastProducts,
              warnaBatang: AppColors.warningMid,
            ),
            const SizedBox(height: 16),
            _itemDetailSection(state.items, period),
            const SizedBox(height: 16),
            _menuLaporan(period),
          ],
        ),
          // Sedikit lebih lebar dari halaman lain supaya grafiknya lega,
          // tapi tetap tidak melebar penuh di tablet.
          maxWidth: 900,
        ),
      ),
    );
  }

  // --------------------------------------------------- pintu laporan lanjutan

  /// Pintu masuk ke laporan lanjutan: rincian lengkap produk terjual dan
  /// laporan keuangan standar akuntansi (laba rugi, ekuitas, neraca, arus kas).
  Widget _menuLaporan(ReportPeriod period) {
    return Column(
      children: [
        _MenuLaporanTile(
          ikon: Icons.receipt_long_outlined,
          judul: 'Rincian produk terjual',
          keterangan: 'Filter harian, total pendapatan & laba, ekspor PDF/CSV',
          onTap: () => context.push('/laporan/rincian', extra: period),
        ),
        const SizedBox(height: 10),
        _MenuLaporanTile(
          ikon: Icons.account_balance_outlined,
          judul: 'Laporan keuangan',
          keterangan: 'Laba rugi, ekuitas, neraca, arus kas, dan prive',
          onTap: () => context.push('/laporan/keuangan'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------ tabs

  Widget _periodTabs(ReportPeriod period) {
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
              onTap: () =>
                  ref.read(reportProvider.notifier).setType(t.$1),
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
                    color: isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dateNavigator(ReportPeriod period, bool canGoNext) {
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
            onPressed: () => ref.read(reportProvider.notifier).goPrevious(),
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Expanded(
            child: InkWell(
              onTap: () => _pickDate(period),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(
                      period.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 11, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Text(
                          period.isCurrent
                              ? 'Periode berjalan'
                              : 'Ketuk untuk pilih tanggal',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Periode berikutnya',
            onPressed: canGoNext
                ? () => ref.read(reportProvider.notifier).goNext()
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

  // --------------------------------------------------------------- ringkasan

  Widget _summaryGrid(ReportSummary summary) {
    final cards = [
      (
        'Total penjualan',
        Formatters.rupiahCompact(summary.totalSales),
        Icons.payments_outlined,
        AppColors.primary,
        AppColors.primaryLight,
      ),
      (
        'Laba kotor',
        Formatters.rupiahCompact(summary.totalProfit),
        Icons.trending_up,
        AppColors.successMid,
        AppColors.successLight,
      ),
      (
        'Transaksi',
        '${summary.transactions}',
        Icons.receipt_long_outlined,
        AppColors.infoMid,
        AppColors.infoLight,
      ),
      (
        'Produk terjual',
        '${summary.itemsSold}',
        Icons.inventory_2_outlined,
        AppColors.accentMid,
        AppColors.accentLight,
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Di tablet keempat kartu ditata sejajar supaya tidak menyisakan
      // ruang kosong di sisi kanan.
      crossAxisCount: Responsive.isTablet(context) ? 4 : 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.7,
      children: cards
          .map((c) => _MetricCard(
                label: c.$1,
                value: c.$2,
                icon: c.$3,
                color: c.$4,
                bgColor: c.$5,
              ))
          .toList(),
    );
  }

  // ----------------------------------------------------------------- grafik

  /// Grafik per hari — dipakai untuk periode mingguan dan bulanan.
  Widget _dailyChart(
    List<({DateTime date, int total})> data,
    ReportPeriod period,
  ) {
    final maxTotal =
        data.fold<int>(0, (max, d) => d.total > max ? d.total : max);

    return _ChartCard(
      title: 'Penjualan per hari',
      subtitle: maxTotal == 0
          ? 'Belum ada penjualan pada periode ini'
          : 'Tertinggi ${Formatters.rupiahCompact(maxTotal)}',
      child: maxTotal == 0
          ? const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Tidak ada data',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ),
            )
          : SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: data.map((d) {
                  final ratio = d.total / maxTotal;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            d.total == 0
                                ? ''
                                : Formatters.rupiahCompact(d.total)
                                    .replaceAll('Rp ', ''),
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            height: (110 * ratio).clamp(4.0, 110.0).toDouble(),
                            decoration: BoxDecoration(
                              color: ratio >= 0.95
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.date.day}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  /// Grafik per jam — dipakai untuk laporan harian, dihitung dari detail item.
  Widget _hourlyChart(List<ReportItemDetail> items) {
    final totals = List<int>.filled(24, 0);
    for (final item in items) {
      totals[item.soldAt.hour] += item.subtotal;
    }

    // Hanya tampilkan jam yang masuk akal untuk toko (06:00 - 22:00).
    const startHour = 6;
    const endHour = 22;
    final visible = <({int hour, int total})>[
      for (var h = startHour; h <= endHour; h++) (hour: h, total: totals[h]),
    ];
    final maxTotal =
        visible.fold<int>(0, (max, d) => d.total > max ? d.total : max);

    return _ChartCard(
      title: 'Penjualan per jam',
      subtitle: maxTotal == 0
          ? 'Belum ada penjualan hari ini'
          : 'Tertinggi ${Formatters.rupiahCompact(maxTotal)}',
      child: maxTotal == 0
          ? const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Tidak ada data',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ),
            )
          : SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: visible.map((d) {
                  final ratio = d.total / maxTotal;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: (100 * ratio).clamp(3.0, 100.0).toDouble(),
                            decoration: BoxDecoration(
                              color: ratio >= 0.95
                                  ? AppColors.primary
                                  : AppColors.primaryLight,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          // Hanya label jam genap supaya tidak berdesakan.
                          Text(
                            d.hour.isEven ? '${d.hour}' : '',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
    );
  }

  // ------------------------------------------------- grafik batang produk

  /// Grafik batang mendatar untuk daftar produk.
  ///
  /// Dipakai dua kali — yang paling laku dan yang paling kurang laku — supaya
  /// keduanya pasti memakai ukuran dan tata letak yang sama. Kalau digambar
  /// sebagai dua potong kode terpisah, panjang batang di kedua grafik tidak
  /// bisa dibandingkan satu sama lain.
  ///
  /// Bentuknya mendatar, bukan tegak, karena nama barang sembako panjang
  /// ("Minyak Goreng Kemasan 2 Liter"). Batang tegak memaksa namanya dipotong
  /// sampai tidak lagi terbaca.
  Widget _productBarChart({
    required String judul,
    required String subjudul,
    required List<TopProduct> produk,
    required Color warnaBatang,
  }) {
    // Penyebut rasio adalah jumlah terjual terbanyak, jadi ia harus diperiksa
    // lebih dulu: kalau semua produk terjual nol, nilai ini 0 dan setiap
    // pembagian di bawah menghasilkan NaN.
    final maxQty =
        produk.fold<int>(0, (maks, p) => p.quantity > maks ? p.quantity : maks);

    return _ChartCard(
      title: judul,
      subtitle: subjudul,
      child: produk.isEmpty
          ? const SizedBox(
              height: 60,
              child: Center(
                child: Text(
                  'Tidak ada data',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
                ),
              ),
            )
          : Column(
              children: produk.map((p) {
                // Barang yang belum terjual tetap digambar — sebagai batang
                // kosong selebar minimum. Kalau barisnya dihilangkan, justru
                // informasi yang paling penting itu yang lenyap dari grafik.
                final rasio = maxQty == 0 ? 0.0 : p.quantity / maxQty;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              p.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMain,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${p.quantity} terjual',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, kotak) => Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  height: 10,
                                  // `.clamp()` mengembalikan `num`, bukan
                                  // `double`. Tanpa `.toDouble()` hasilnya tidak
                                  // bisa dipakai sebagai lebar.
                                  width: (kotak.maxWidth * rasio)
                                      .clamp(3.0, kotak.maxWidth)
                                      .toDouble(),
                                  decoration: BoxDecoration(
                                    color: warnaBatang,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 88,
                            child: Text(
                              Formatters.rupiahCompact(p.revenue),
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // -------------------------------------------------- grafik tujuh hari

  /// Singkatan nama hari, indeksnya `weekday - 1`.
  static const List<String> _namaHari = [
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab',
    'Min',
  ];

  /// Grafik batang penjualan tujuh hari terakhir.
  ///
  /// Selalu tujuh batang. Hari tanpa penjualan tetap digambar sebagai batang
  /// kosong supaya lebar grafiknya tidak berubah-ubah — kalau hanya hari yang
  /// ada penjualannya yang digambar, "seminggu" bisa tampil sebagai dua batang
  /// dan naik-turunnya tidak lagi terbaca.
  ///
  /// Batang hari ini diberi warna penuh dan harinya dicetak tebal, karena
  /// itulah yang dicari pemilik toko lebih dulu.
  Widget _last7DaysChart(List<({DateTime date, int total})> data) {
    final maxTotal =
        data.fold<int>(0, (maks, d) => d.total > maks ? d.total : maks);
    final total = data.fold<int>(0, (jumlah, d) => jumlah + d.total);
    // `data.length` tidak pernah nol — repositori selalu mengembalikan tepat
    // tujuh baris — tetapi pembagian ini tetap dijaga supaya tidak bergantung
    // pada janji itu.
    final rata = data.isEmpty ? 0 : total ~/ data.length;

    return _ChartCard(
      title: '7 hari terakhir',
      subtitle: maxTotal == 0
          ? 'Belum ada penjualan dalam tujuh hari terakhir'
          : 'Total ${Formatters.rupiahCompact(total)} · rata-rata '
              '${Formatters.rupiahCompact(rata)}/hari',
      child: SizedBox(
        height: 150,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            // Baris terakhir selalu hari ini: repositori menyusunnya urut naik.
            final iniHariIni = i == data.length - 1;
            final rasio = maxTotal == 0 ? 0.0 : d.total / maxTotal;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      d.total == 0
                          ? ''
                          : Formatters.rupiahCompact(d.total)
                              .replaceAll('Rp ', ''),
                      style: const TextStyle(
                        fontSize: 9,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      height: (110 * rasio).clamp(4.0, 110.0).toDouble(),
                      decoration: BoxDecoration(
                        color: iniHariIni
                            ? AppColors.primary
                            : AppColors.primaryLight,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _namaHari[d.date.weekday - 1],
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            iniHariIni ? FontWeight.w700 : FontWeight.w400,
                        color: iniHariIni
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }


  // ------------------------------------------------------- rincian per item

  /// Rincian tiap produk yang terjual, dikelompokkan per tanggal.
  /// Setiap baris memuat jam transaksi, jumlah, harga satuan, dan subtotal.
  ///
  /// Di beranda laporan ini hanya menampilkan **maksimal 5 baris** supaya
  /// ringkas. Kalau barisnya lebih banyak, muncul tombol "Lihat semua" yang
  /// membuka layar rincian lengkap (bisa difilter harian dan diekspor ke
  /// PDF maupun CSV).
  Widget _itemDetailSection(
    List<ReportItemDetail> items,
    ReportPeriod period,
  ) {
    const maxBaris = 5;
    final tampil = items.take(maxBaris).toList();
    final adaSisa = items.length > maxBaris;

    // Kelompokkan per hari, urut dari yang terbaru.
    final grouped = <String, List<ReportItemDetail>>{};
    for (final item in tampil) {
      final key = '${item.soldAt.year}-${item.soldAt.month}-'
          '${item.soldAt.day}';
      grouped.putIfAbsent(key, () => []).add(item);
    }
    final keys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rincian produk terjual',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  adaSisa
                      ? '${tampil.length} dari ${items.length} baris'
                      : '${items.length} baris',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            period.type == ReportPeriodType.harian
                ? 'Setiap produk yang terjual beserta jam dan harganya.'
                : 'Dikelompokkan per tanggal transaksi.',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada produk terjual pada periode ini.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            )
          else
            ...keys.map((key) {
              final dayItems = grouped[key]!;
              final dayTotal =
                  dayItems.fold<int>(0, (sum, i) => sum + i.subtotal);
              final day = dayItems.first.soldAt;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Judul hari
                  Container(
                    margin: const EdgeInsets.only(bottom: 8, top: 4),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.dateWithDay(day),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        Text(
                          Formatters.rupiah(dayTotal),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...dayItems.map(_itemRow),
                  const SizedBox(height: 10),
                ],
              );
            }),
          if (adaSisa) ...[
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () =>
                    context.push('/laporan/rincian', extra: period),
                icon: const Icon(Icons.unfold_more, size: 18),
                label: Text('Lihat semua ${items.length} baris'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary.withOpacity(0.4),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Di layar rincian kamu bisa memfilter harian, melihat total '
              'pendapatan beserta labanya, lalu mengekspor ke PDF atau CSV.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemRow(ReportItemDetail item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Jam transaksi
          Container(
            width: 46,
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
                  '${item.quantity} x ${Formatters.rupiah(item.sellPrice)}'
                  ' · ${Formatters.time(item.soldAt)}'
                  '${item.customerName != null && item.customerName!.isNotEmpty ? ' · ${item.customerName}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  item.invoiceNumber,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
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
            ],
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- sub-widgets

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _MetricCard({
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Kartu menu untuk membuka laporan lanjutan dari layar Laporan.
class _MenuLaporanTile extends StatelessWidget {
  final IconData ikon;
  final String judul;
  final String keterangan;
  final VoidCallback onTap;

  const _MenuLaporanTile({
    required this.ikon,
    required this.judul,
    required this.keterangan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(ikon, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keterangan,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
