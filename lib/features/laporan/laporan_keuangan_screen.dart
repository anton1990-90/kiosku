import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/accounting_models.dart';
import '../../data/models/cash_model.dart';
import '../../providers/accounting_provider.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/report_export.dart';

/// Laporan keuangan lengkap sesuai standar akuntansi.
///
/// Berisi empat laporan yang saling terkait:
///   1. Laba rugi        — pendapatan, HPP, beban, laba bersih
///   2. Perubahan ekuitas — laba ditahan, laba periode, prive
///   3. Neraca           — aset, liabilitas, ekuitas
///   4. Arus kas         — mutasi kas per kategori
///
/// Beban usaha dan prive dicatat dari layar ini supaya langsung ikut
/// terhitung di semua laporan dan di kas.
class LaporanKeuanganScreen extends ConsumerStatefulWidget {
  const LaporanKeuanganScreen({super.key});

  @override
  ConsumerState<LaporanKeuanganScreen> createState() =>
      _LaporanKeuanganScreenState();
}

class _LaporanKeuanganScreenState extends ConsumerState<LaporanKeuanganScreen> {
  int _tab = 0;
  bool _mengekspor = false;

  static const _judulTab = [
    'Laba Rugi',
    'Ekuitas',
    'Neraca',
    'Arus Kas',
  ];

  LaporanKeuanganData _dataEkspor(AccountingState state) {
    return LaporanKeuanganData(
      storeName: ref.read(authProvider).user?.storeName ?? 'Toko',
      period: state.period,
      labaRugi: state.labaRugi,
      ekuitas: state.ekuitas,
      neraca: state.neraca,
      arusKas: state.arusKas,
    );
  }

  Future<void> _ekspor({required bool pdf}) async {
    final state = ref.read(accountingProvider);
    if (state.labaRugi.isEmpty && state.arusKas.isEmpty) {
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
      final data = _dataEkspor(state);
      if (pdf) {
        await ReportExport.shareLaporanKeuanganPdf(data);
      } else {
        await ReportExport.shareLaporanKeuanganCsv(data);
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
    final state = ref.watch(accountingProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
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
        onRefresh: () => ref.read(accountingProvider.notifier).load(),
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _navigasiPeriode(state.period),
              const SizedBox(height: 14),
              _tabBar(),
              const SizedBox(height: 16),
              if (state.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else
                switch (_tab) {
                  0 => _tabLabaRugi(state),
                  1 => _tabEkuitas(state),
                  2 => _tabNeraca(state),
                  _ => _tabArusKas(state),
                },
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- navigasi

  Widget _navigasiPeriode(ReportPeriod period) {
    final canGoNext = period.next() != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Periode sebelumnya',
                onPressed: () =>
                    ref.read(accountingProvider.notifier).goPrevious(),
                icon: const Icon(Icons.chevron_left,
                    color: AppColors.textSecondary),
              ),
              Expanded(
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Periode berikutnya',
                onPressed: canGoNext
                    ? () => ref.read(accountingProvider.notifier).goNext()
                    : null,
                icon: Icon(
                  Icons.chevron_right,
                  color:
                      canGoNext ? AppColors.textSecondary : AppColors.border,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final t in ReportPeriodType.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () =>
                          ref.read(accountingProvider.notifier).setType(t),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: period.type == t
                              ? AppColors.primaryLight
                              : AppColors.bgSoft,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          switch (t) {
                            ReportPeriodType.harian => 'Harian',
                            ReportPeriodType.mingguan => 'Mingguan',
                            ReportPeriodType.bulanan => 'Bulanan',
                          },
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: period.type == t
                                ? AppColors.primaryDark
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: List.generate(_judulTab.length, (i) {
          final isActive = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.bgCard : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _judulTab[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color:
                        isActive ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ------------------------------------------------------------- laba rugi

  Widget _tabLabaRugi(AccountingState state) {
    final lr = state.labaRugi;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kartu(
          judul: 'Laporan Laba Rugi',
          subjudul: 'Pendapatan dikurangi HPP dan beban usaha',
          children: [
            _baris('Pendapatan penjualan', Formatters.rupiah(lr.pendapatan)),
            _baris(
              'Harga pokok penjualan (HPP)',
              '(${Formatters.rupiah(lr.hpp)})',
              indent: true,
              warna: AppColors.dangerMid,
            ),
            _baris(
              'LABA KOTOR',
              Formatters.rupiah(lr.labaKotor),
              tebal: true,
              garisAtas: true,
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Beban operasional',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (lr.beban.isEmpty)
              const Padding(
                padding: EdgeInsets.only(left: 12, bottom: 4),
                child: Text(
                  'Belum ada beban tercatat pada periode ini.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textTertiary),
                ),
              )
            else
              ...lr.beban.map(
                (b) => _baris(
                  b.category,
                  Formatters.rupiah(b.amount),
                  indent: true,
                ),
              ),
            _baris(
              'Total beban operasional',
              '(${Formatters.rupiah(lr.totalBeban)})',
              indent: true,
              tebal: true,
              garisAtas: true,
              warna: AppColors.dangerMid,
            ),
            _baris(
              'LABA BERSIH',
              Formatters.rupiah(lr.labaBersih),
              tebal: true,
              garisAtas: true,
              garisBawah: true,
              warna: lr.labaBersih >= 0
                  ? AppColors.successMid
                  : AppColors.dangerMid,
            ),
            if (lr.pendapatan > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _lencana(
                      'Margin kotor',
                      '${(lr.marginKotor * 100).toStringAsFixed(1)}%',
                      AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _lencana(
                      'Margin bersih',
                      '${(lr.marginBersih * 100).toStringAsFixed(1)}%',
                      lr.labaBersih >= 0
                          ? AppColors.successMid
                          : AppColors.dangerMid,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _tombolTambah(
          label: 'Catat beban usaha',
          icon: Icons.receipt_outlined,
          onTap: _bukaTambahBeban,
        ),
        if (state.expenses.isNotEmpty) ...[
          const SizedBox(height: 16),
          _kartu(
            judul: 'Rincian beban periode ini',
            children: state.expenses
                .map(
                  (e) => _barisHapus(
                    title: e.category,
                    subtitle:
                        '${Formatters.date(e.date)}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                    value: Formatters.rupiah(e.amount),
                    warna: AppColors.dangerMid,
                    onHapus: () => _konfirmasiHapus(
                      judul: 'Hapus beban ini?',
                      pesan:
                          '${e.category} ${Formatters.rupiah(e.amount)} akan dihapus dari laporan dan kas.',
                      aksi: () => ref
                          .read(accountingProvider.notifier)
                          .deleteExpense(e.id!),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------- ekuitas

  Widget _tabEkuitas(AccountingState state) {
    final ek = state.ekuitas;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kartu(
          judul: 'Laporan Perubahan Ekuitas',
          subjudul: 'Modal pemilik dan laba yang ditahan di toko',
          children: [
            _baris('Laba ditahan awal periode', Formatters.rupiah(ek.modalAwal)),
            _baris(
              'Laba bersih periode ini',
              Formatters.rupiah(ek.labaBersih),
              indent: true,
              warna: AppColors.successMid,
            ),
            if (ek.modalDisetor > 0)
              _baris(
                'Setoran modal pemilik',
                Formatters.rupiah(ek.modalDisetor),
                indent: true,
              ),
            _baris(
              'Prive (pengambilan pemilik)',
              '(${Formatters.rupiah(ek.prive)})',
              indent: true,
              warna: AppColors.dangerMid,
            ),
            _baris(
              'EKUITAS AKHIR PERIODE',
              Formatters.rupiah(ek.modalAkhir),
              tebal: true,
              garisAtas: true,
              garisBawah: true,
            ),
            const SizedBox(height: 8),
            const Text(
              'Prive bukan beban usaha, jadi tidak mengurangi laba — '
              'prive mengurangi ekuitas pemilik.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
                height: 1.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _tombolTambah(
          label: 'Catat prive (ambil uang toko)',
          icon: Icons.savings_outlined,
          onTap: _bukaTambahPrive,
        ),
        if (state.priveList.isNotEmpty) ...[
          const SizedBox(height: 16),
          _kartu(
            judul: 'Rincian prive periode ini',
            children: state.priveList
                .map(
                  (p) => _barisHapus(
                    title: p.note == null || p.note!.isEmpty
                        ? 'Prive pemilik'
                        : p.note!,
                    subtitle: Formatters.date(p.date),
                    value: Formatters.rupiah(p.amount),
                    warna: AppColors.dangerMid,
                    onHapus: () => _konfirmasiHapus(
                      judul: 'Hapus prive ini?',
                      pesan:
                          'Prive ${Formatters.rupiah(p.amount)} akan dihapus dari laporan dan kas.',
                      aksi: () => ref
                          .read(accountingProvider.notifier)
                          .deletePrive(p.id!),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- neraca

  Widget _tabNeraca(AccountingState state) {
    final n = state.neraca;

    return _kartu(
      judul: 'Laporan Posisi Keuangan (Neraca)',
      subjudul: 'Posisi terkini: aset, liabilitas, dan ekuitas',
      children: [
        _subJudul('ASET'),
        _baris('Kas', Formatters.rupiah(n.kas), indent: true),
        _baris('Persediaan barang', Formatters.rupiah(n.persediaan), indent: true),
        _baris('Piutang pelanggan', Formatters.rupiah(n.piutang), indent: true),
        _baris(
          'TOTAL ASET',
          Formatters.rupiah(n.totalAset),
          tebal: true,
          garisAtas: true,
          warna: AppColors.primary,
        ),
        const SizedBox(height: 10),
        _subJudul('LIABILITAS'),
        _baris(
          'Hutang usaha (ke supplier)',
          Formatters.rupiah(n.hutangUsaha),
          indent: true,
        ),
        _baris(
          'TOTAL LIABILITAS',
          Formatters.rupiah(n.totalLiabilitas),
          tebal: true,
          garisAtas: true,
          warna: AppColors.dangerMid,
        ),
        const SizedBox(height: 10),
        _subJudul('EKUITAS'),
        _baris(
          'Modal disetor pemilik',
          Formatters.rupiah(n.modalDisetor),
          indent: true,
        ),
        _baris('Laba ditahan', Formatters.rupiah(n.labaDitahan), indent: true),
        _baris(
          'Modal awal & penyesuaian',
          Formatters.rupiah(n.modalAwalPenyesuaian),
          indent: true,
        ),
        _baris(
          'TOTAL EKUITAS',
          Formatters.rupiah(n.totalEkuitas),
          tebal: true,
          garisAtas: true,
          warna: AppColors.successMid,
        ),
        const SizedBox(height: 6),
        _baris(
          'TOTAL LIABILITAS + EKUITAS',
          Formatters.rupiah(n.totalLiabilitas + n.totalEkuitas),
          tebal: true,
          garisAtas: true,
          garisBawah: true,
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: n.seimbang
                ? AppColors.successLight
                : AppColors.warningLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                n.seimbang ? Icons.check_circle_outline : Icons.info_outline,
                size: 16,
                color:
                    n.seimbang ? AppColors.successMid : AppColors.warningMid,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  n.seimbang
                      ? 'Neraca seimbang: total aset sama dengan total '
                          'liabilitas ditambah ekuitas.'
                      : 'Neraca belum seimbang. Periksa kembali catatan kas, '
                          'beban, dan prive.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: n.seimbang
                        ? AppColors.successMid
                        : AppColors.warningMid,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Neraca memakai nilai terkini untuk kas, persediaan, piutang, dan '
          'hutang. Baris "Modal awal & penyesuaian" menampung stok serta uang '
          'yang sudah ada sebelum aplikasi dipakai, supaya neraca tetap '
          'seimbang.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary,
            height: 1.45,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- arus kas

  Widget _tabArusKas(AccountingState state) {
    final ak = state.arusKas;

    return _kartu(
      judul: 'Laporan Arus Kas',
      subjudul: 'Uang masuk dan keluar dikelompokkan per kategori',
      children: [
        _baris('Saldo kas awal periode', Formatters.rupiah(ak.saldoAwal)),
        const SizedBox(height: 8),
        if (ak.rincian.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Belum ada mutasi kas pada periode ini.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.bgSoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Kategori', style: _gayaJudul)),
                Expanded(
                  flex: 3,
                  child: Text('Masuk',
                      textAlign: TextAlign.right, style: _gayaJudul),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Keluar',
                      textAlign: TextAlign.right, style: _gayaJudul),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ...ak.rincian.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      CashCategory.label(a.category),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      a.masuk == 0 ? '-' : Formatters.rupiahCompact(a.masuk),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.successMid,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      a.keluar == 0 ? '-' : Formatters.rupiahCompact(a.keluar),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.dangerMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          Row(
            children: [
              const Expanded(
                flex: 4,
                child: Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  Formatters.rupiahCompact(ak.totalMasuk),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successMid,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  Formatters.rupiahCompact(ak.totalKeluar),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dangerMid,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _baris(
          'Kenaikan / penurunan kas',
          Formatters.rupiah(ak.kenaikanKas),
          tebal: true,
          garisAtas: true,
          warna: ak.kenaikanKas >= 0
              ? AppColors.successMid
              : AppColors.dangerMid,
        ),
        _baris(
          'SALDO KAS AKHIR PERIODE',
          Formatters.rupiah(ak.saldoAkhir),
          tebal: true,
          garisAtas: true,
          garisBawah: true,
          warna: AppColors.primary,
        ),
      ],
    );
  }

  // ------------------------------------------------------------- komponen

  static const _gayaJudul = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
  );

  Widget _kartu({
    required String judul,
    String? subjudul,
    required List<Widget> children,
  }) {
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
            judul,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          if (subjudul != null) ...[
            const SizedBox(height: 2),
            Text(
              subjudul,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary,
              ),
            ),
          ],
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _subJudul(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _baris(
    String label,
    String value, {
    bool tebal = false,
    bool indent = false,
    bool garisAtas = false,
    bool garisBawah = false,
    Color? warna,
  }) {
    return Column(
      children: [
        if (garisAtas)
          const Divider(height: 12, color: AppColors.border),
        Padding(
          padding: EdgeInsets.only(
            left: indent ? 12 : 0,
            top: 4,
            bottom: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: tebal ? 13 : 12.5,
                    fontWeight: tebal ? FontWeight.w800 : FontWeight.w400,
                    color: warna ?? AppColors.textMain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                value,
                style: TextStyle(
                  fontSize: tebal ? 13.5 : 12.5,
                  fontWeight: tebal ? FontWeight.w800 : FontWeight.w600,
                  color: warna ?? AppColors.textMain,
                ),
              ),
            ],
          ),
        ),
        if (garisBawah)
          const Divider(height: 12, color: AppColors.border),
      ],
    );
  }

  Widget _lencana(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisHapus({
    required String title,
    required String subtitle,
    required String value,
    required Color warna,
    required VoidCallback onHapus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMain,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: warna,
            ),
          ),
          IconButton(
            tooltip: 'Hapus',
            visualDensity: VisualDensity.compact,
            onPressed: onHapus,
            icon: const Icon(Icons.delete_outline,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _tombolTambah({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ tambah data

  Future<void> _bukaTambahBeban() async {
    final hasil = await showModalBottomSheet<_BebanBaru>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TambahBebanSheet(),
    );
    if (hasil == null || !mounted) return;

    await ref.read(accountingProvider.notifier).addExpense(
          category: hasil.category,
          amount: hasil.amount,
          note: hasil.note,
          date: hasil.date,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Beban ${hasil.category} dicatat'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _bukaTambahPrive() async {
    final hasil = await showModalBottomSheet<_PriveBaru>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TambahPriveSheet(),
    );
    if (hasil == null || !mounted) return;

    await ref.read(accountingProvider.notifier).addPrive(
          amount: hasil.amount,
          note: hasil.note,
          date: hasil.date,
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prive ${Formatters.rupiah(hasil.amount)} dicatat'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _konfirmasiHapus({
    required String judul,
    required String pesan,
    required Future<void> Function() aksi,
  }) async {
    final yakin = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(judul),
        content: Text(pesan),
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

    if (yakin == true) await aksi();
  }
}

// ------------------------------------------------------------- panel tambah

class _BebanBaru {
  final String category;
  final int amount;
  final String? note;
  final DateTime? date;

  const _BebanBaru({
    required this.category,
    required this.amount,
    this.note,
    this.date,
  });
}

class _PriveBaru {
  final int amount;
  final String? note;
  final DateTime? date;

  const _PriveBaru({required this.amount, this.note, this.date});
}

class _TambahBebanSheet extends StatefulWidget {
  const _TambahBebanSheet();

  @override
  State<_TambahBebanSheet> createState() => _TambahBebanSheetState();
}

class _TambahBebanSheetState extends State<_TambahBebanSheet> {
  static const _kategori = [
    'Listrik & air',
    'Sewa tempat',
    'Gaji karyawan',
    'Transport & bensin',
    'Perlengkapan toko',
    'Promosi',
    'Perawatan & perbaikan',
    'Lain-lain',
  ];

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _category = _kategori.first;
  DateTime _tanggal = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                'Catat beban usaha',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Beban otomatis mengurangi kas dan masuk ke laporan laba rugi.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Kategori beban'),
                items: _kategori
                    .map((k) => DropdownMenuItem(value: k, child: Text(k)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v ?? _kategori.first),
              ),
              const SizedBox(height: 14),
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
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tanggal,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    helpText: 'Tanggal beban',
                    cancelText: 'Batal',
                    confirmText: 'Pilih',
                  );
                  if (picked != null) setState(() => _tanggal = picked);
                },
                icon: const Icon(Icons.event, size: 16),
                label: Text('Tanggal ${Formatters.date(_tanggal)}'),
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
                          _BebanBaru(
                            category: _category,
                            amount: int.parse(_amountController.text.trim()),
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
}

class _TambahPriveSheet extends StatefulWidget {
  const _TambahPriveSheet();

  @override
  State<_TambahPriveSheet> createState() => _TambahPriveSheetState();
}

class _TambahPriveSheetState extends State<_TambahPriveSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _tanggal = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                'Catat prive',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Prive = uang toko yang diambil pemilik untuk keperluan '
                'pribadi. Bukan beban usaha, tapi mengurangi ekuitas.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Jumlah prive',
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Isi jumlah yang benar';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  hintText: 'Contoh: keperluan sekolah anak',
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _tanggal,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    helpText: 'Tanggal prive',
                    cancelText: 'Batal',
                    confirmText: 'Pilih',
                  );
                  if (picked != null) setState(() => _tanggal = picked);
                },
                icon: const Icon(Icons.event, size: 16),
                label: Text('Tanggal ${Formatters.date(_tanggal)}'),
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
                          _PriveBaru(
                            amount: int.parse(_amountController.text.trim()),
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
}
