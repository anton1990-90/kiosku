import 'dart:typed_data';

import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../data/models/accounting_models.dart';
import '../../data/models/cash_model.dart';
import '../../data/models/report_models.dart';
import 'export_service.dart';
import 'pdf_builder.dart';

/// Data yang dibutuhkan untuk mengekspor rincian penjualan.
class RincianPenjualanData {
  final String storeName;
  final ReportPeriod period;
  final ReportSummary summary;
  final List<ReportItemDetail> items;
  final List<({String name, int qty, int revenue, int profit})> rekap;

  const RincianPenjualanData({
    required this.storeName,
    required this.period,
    required this.summary,
    required this.items,
    required this.rekap,
  });

  String get periode => period.label;
}

/// Data yang dibutuhkan untuk mengekspor laporan keuangan.
class LaporanKeuanganData {
  final String storeName;
  final ReportPeriod period;
  final LabaRugi labaRugi;
  final PerubahanEkuitas ekuitas;
  final Neraca neraca;
  final ArusKas arusKas;

  const LaporanKeuanganData({
    required this.storeName,
    required this.period,
    required this.labaRugi,
    required this.ekuitas,
    required this.neraca,
    required this.arusKas,
  });

  String get periode => period.label;
}

/// Menyusun berkas PDF & CSV untuk laporan penjualan dan laporan keuangan.
///
/// Semua angka sudah diformat Rupiah sebelum masuk ke PDF supaya tampilannya
/// sama dengan yang dilihat di aplikasi.
class ReportExport {
  ReportExport._();

  // ------------------------------------------------ rincian produk terjual

  static List<List<String>> rincianPenjualanCsv(RincianPenjualanData data) {
    final status = _statusPerNota(data.items);

    final rows = <List<String>>[
      ['Laporan Rincian Produk Terjual'],
      [data.storeName],
      ['Periode', data.periode],
      ['Dicetak', Formatters.dateTime(DateTime.now())],
      [],
      ['RINGKASAN'],
      ['Total penjualan', data.summary.totalSales.toString()],
      ['Laba kotor', data.summary.totalProfit.toString()],
      ['Jumlah transaksi', data.summary.transactions.toString()],
      ['Produk terjual (pcs)', data.summary.itemsSold.toString()],
      [],
      ['STATUS PEMBAYARAN'],
      ['Transaksi tunai (cash)', status.tunai.toString()],
      ['Transaksi piutang belum lunas', status.piutang.toString()],
      ['Transaksi piutang sudah lunas', status.piutangLunas.toString()],
      ['Nilai piutang belum dibayar', status.sisa.toString()],
      [],
      ['REKAP PER PRODUK'],
      ['Produk', 'Jumlah terjual', 'Pendapatan', 'Laba'],
    ];

    for (final r in data.rekap) {
      rows.add([
        r.name,
        r.qty.toString(),
        r.revenue.toString(),
        r.profit.toString(),
      ]);
    }

    rows.add([]);
    rows.add(['RINCIAN TRANSAKSI']);
    rows.add([
      'Tanggal',
      'Jam',
      'Produk',
      'Jumlah',
      'Harga satuan',
      'Subtotal',
      'Laba',
      'Pelanggan',
      'No. nota',
      'Metode',
      'Status bayar',
      'Sisa piutang',
    ]);

    for (final item in data.items) {
      rows.add([
        Formatters.date(item.soldAt),
        Formatters.time(item.soldAt),
        item.productName,
        item.quantity.toString(),
        item.sellPrice.toString(),
        item.subtotal.toString(),
        item.profit.toString(),
        item.customerName ?? '-',
        item.invoiceNumber,
        item.paymentMethod,
        item.paymentStatusLabel,
        item.unpaidAmount.toString(),
      ]);
    }

    return rows;
  }

  /// Ringkasan status pembayaran, dihitung **per nomor nota**.
  ///
  /// Satu nota bisa berisi beberapa produk, jadi kalau dihitung per baris
  /// barang jumlahnya jadi berlipat. Dipakai CSV maupun PDF supaya keduanya
  /// menampilkan angka yang sama.
  static ({int tunai, int piutang, int piutangLunas, int sisa}) _statusPerNota(
    List<ReportItemDetail> items,
  ) {
    final sudahDihitung = <String>{};
    var tunai = 0;
    var piutang = 0;
    var piutangLunas = 0;
    var sisa = 0;

    for (final item in items) {
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

    return (
      tunai: tunai,
      piutang: piutang,
      piutangLunas: piutangLunas,
      sisa: sisa,
    );
  }

  static Uint8List rincianPenjualanPdf(RincianPenjualanData data) {
    final pdf = SimplePdf(footerTitle: 'TokoKu - Rincian Produk Terjual');

    pdf.heading('LAPORAN RINCIAN PRODUK TERJUAL');
    pdf.text(data.storeName, size: 11, bold: true);
    pdf.text('Periode: ${data.periode}', gray: 110);
    pdf.text('Dicetak: ${Formatters.dateTime(DateTime.now())}', gray: 110, size: 8.5);

    pdf.subheading('Ringkasan');
    pdf.keyValue('Total penjualan', Formatters.rupiah(data.summary.totalSales), bold: true);
    pdf.keyValue('Laba kotor', Formatters.rupiah(data.summary.totalProfit));
    pdf.keyValue('Jumlah transaksi', '${data.summary.transactions}');
    pdf.keyValue('Produk terjual', '${data.summary.itemsSold} pcs');
    pdf.keyValue(
      'Rata-rata per transaksi',
      Formatters.rupiah(data.summary.averagePerTransaction),
      topRule: true,
    );

    // Status pembayaran — supaya jelas berapa transaksi yang tunai dan berapa
    // yang masih menjadi piutang, dihitung per nota.
    final status = _statusPerNota(data.items);
    pdf.space(4);
    pdf.text('Status pembayaran', size: 9, gray: 110);
    pdf.keyValue('Transaksi tunai (cash)', '${status.tunai}', indent: true);
    pdf.keyValue(
      'Transaksi piutang belum lunas',
      '${status.piutang}',
      indent: true,
    );
    pdf.keyValue(
      'Transaksi piutang sudah lunas',
      '${status.piutangLunas}',
      indent: true,
    );
    pdf.keyValue(
      'Nilai piutang belum dibayar',
      Formatters.rupiah(status.sisa),
      indent: true,
      topRule: true,
    );

    pdf.subheading('Rekap per produk');
    if (data.rekap.isEmpty) {
      pdf.text('Belum ada produk terjual pada periode ini.', gray: 130);
    } else {
      pdf.row(
        const ['Produk', 'Terjual', 'Pendapatan', 'Laba'],
        weights: const [3, 1, 2, 2],
        bold: true,
        shade: true,
        alignLastRight: false,
      );
      for (final r in data.rekap) {
        pdf.row(
          [
            r.name,
            '${r.qty} pcs',
            Formatters.rupiah(r.revenue),
            Formatters.rupiah(r.profit),
          ],
          weights: const [3, 1, 2, 2],
          alignLastRight: false,
          rule: true,
        );
      }
    }

    pdf.subheading('Rincian transaksi');
    if (data.items.isEmpty) {
      pdf.text('Belum ada transaksi pada periode ini.', gray: 130);
    } else {
      pdf.row(
        const ['Tanggal', 'Jam', 'Produk', 'Qty', 'Harga', 'Subtotal', 'Laba'],
        weights: const [1.5, 0.9, 3, 0.7, 1.5, 1.7, 1.5],
        bold: true,
        shade: true,
        alignLastRight: false,
      );
      for (final item in data.items) {
        pdf.row(
          [
            Formatters.date(item.soldAt),
            Formatters.time(item.soldAt),
            item.productName,
            '${item.quantity}',
            Formatters.rupiah(item.sellPrice),
            Formatters.rupiah(item.subtotal),
            Formatters.rupiah(item.profit),
          ],
          weights: const [1.5, 0.9, 3, 0.7, 1.5, 1.7, 1.5],
          alignLastRight: false,
          size: 8.5,
          rule: true,
        );
      }
    }

    pdf.divider(topGap: 10, gray: 90);
    pdf.keyValue(
      'TOTAL PENJUALAN',
      Formatters.rupiah(data.summary.totalSales),
      bold: true,
      size: 11,
    );
    pdf.keyValue(
      'TOTAL LABA',
      Formatters.rupiah(data.summary.totalProfit),
      bold: true,
      size: 11,
    );

    pdf.space(10);
    pdf.note(
      'Laba dihitung dari selisih harga jual dan harga modal saat transaksi '
      'terjadi, dikali jumlah barang.',
    );

    return pdf.build();
  }

  // --------------------------------------------------------- laporan keuangan

  static List<List<String>> laporanKeuanganCsv(LaporanKeuanganData data) {
    final rows = <List<String>>[
      ['LAPORAN KEUANGAN'],
      [data.storeName],
      ['Periode', data.periode],
      ['Dicetak', Formatters.dateTime(DateTime.now())],
      [],
      ['A. LAPORAN LABA RUGI'],
      ['Pendapatan penjualan', data.labaRugi.pendapatan.toString()],
      ['Harga pokok penjualan', data.labaRugi.hpp.toString()],
      ['Laba kotor', data.labaRugi.labaKotor.toString()],
      ['Beban operasional', data.labaRugi.totalBeban.toString()],
      ['Laba bersih', data.labaRugi.labaBersih.toString()],
      [],
      ['Rincian beban'],
      ['Kategori', 'Jumlah'],
    ];
    for (final b in data.labaRugi.beban) {
      rows.add([b.category, b.amount.toString()]);
    }

    rows.add([]);
    rows.add(['B. LAPORAN PERUBAHAN EKUITAS']);
    rows.add(['Laba ditahan awal periode', data.ekuitas.modalAwal.toString()]);
    rows.add(['Laba bersih periode ini', data.ekuitas.labaBersih.toString()]);
    rows.add(['Setoran modal pemilik', data.ekuitas.modalDisetor.toString()]);
    rows.add(['Prive', data.ekuitas.prive.toString()]);
    rows.add(['Ekuitas akhir periode', data.ekuitas.modalAkhir.toString()]);

    rows.add([]);
    rows.add(['C. LAPORAN POSISI KEUANGAN (NERACA)']);
    rows.add(['ASET', '']);
    rows.add(['Kas', data.neraca.kas.toString()]);
    rows.add(['Persediaan barang', data.neraca.persediaan.toString()]);
    rows.add(['Piutang pelanggan', data.neraca.piutang.toString()]);
    rows.add(['Total aset', data.neraca.totalAset.toString()]);
    rows.add(['LIABILITAS', '']);
    rows.add(['Hutang usaha', data.neraca.hutangUsaha.toString()]);
    rows.add(['Total liabilitas', data.neraca.totalLiabilitas.toString()]);
    rows.add(['EKUITAS', '']);
    rows.add(['Modal disetor', data.neraca.modalDisetor.toString()]);
    rows.add(['Laba ditahan', data.neraca.labaDitahan.toString()]);
    rows.add([
      'Modal awal & penyesuaian',
      data.neraca.modalAwalPenyesuaian.toString(),
    ]);
    rows.add(['Total ekuitas', data.neraca.totalEkuitas.toString()]);
    rows.add([
      'Total liabilitas + ekuitas',
      (data.neraca.totalLiabilitas + data.neraca.totalEkuitas).toString(),
    ]);

    rows.add([]);
    rows.add(['D. LAPORAN ARUS KAS']);
    rows.add(['Saldo kas awal', data.arusKas.saldoAwal.toString()]);
    rows.add(['Kategori', 'Uang masuk', 'Uang keluar', 'Selisih']);
    for (final a in data.arusKas.rincian) {
      rows.add([
        CashCategory.label(a.category),
        a.masuk.toString(),
        a.keluar.toString(),
        a.selisih.toString(),
      ]);
    }
    rows.add([
      'Total',
      data.arusKas.totalMasuk.toString(),
      data.arusKas.totalKeluar.toString(),
      data.arusKas.kenaikanKas.toString(),
    ]);
    rows.add(['Saldo kas akhir', data.arusKas.saldoAkhir.toString()]);

    return rows;
  }

  static Uint8List laporanKeuanganPdf(LaporanKeuanganData data) {
    final pdf = SimplePdf(footerTitle: 'TokoKu - Laporan Keuangan');

    pdf.heading('LAPORAN KEUANGAN');
    pdf.text(data.storeName, size: 11, bold: true);
    pdf.text('Periode: ${data.periode}', gray: 110);
    pdf.text('Dicetak: ${Formatters.dateTime(DateTime.now())}', gray: 110, size: 8.5);

    // ------------------------------------------------------------ laba rugi
    pdf.subheading('A. Laporan Laba Rugi', topGap: 14);
    pdf.keyValue(
      'Pendapatan penjualan',
      Formatters.rupiah(data.labaRugi.pendapatan),
    );
    pdf.keyValue(
      'Harga pokok penjualan (HPP)',
      '(${Formatters.rupiah(data.labaRugi.hpp)})',
      indent: true,
    );
    pdf.keyValue(
      'LABA KOTOR',
      Formatters.rupiah(data.labaRugi.labaKotor),
      bold: true,
      topRule: true,
    );

    pdf.space(4);
    pdf.text('Beban operasional:', size: 9, gray: 110);
    if (data.labaRugi.beban.isEmpty) {
      pdf.text('(belum ada beban tercatat)', size: 9, gray: 140);
    } else {
      for (final b in data.labaRugi.beban) {
        pdf.keyValue(b.category, Formatters.rupiah(b.amount), indent: true, size: 9);
      }
    }
    pdf.keyValue(
      'Total beban operasional',
      '(${Formatters.rupiah(data.labaRugi.totalBeban)})',
      indent: true,
      topRule: true,
    );
    pdf.keyValue(
      'LABA BERSIH',
      Formatters.rupiah(data.labaRugi.labaBersih),
      bold: true,
      size: 11,
      topRule: true,
      bottomRule: true,
    );
    if (data.labaRugi.pendapatan > 0) {
      pdf.note(
        'Margin kotor ${(data.labaRugi.marginKotor * 100).toStringAsFixed(1)}%  -  '
        'margin bersih ${(data.labaRugi.marginBersih * 100).toStringAsFixed(1)}%',
      );
    }

    // -------------------------------------------------- perubahan ekuitas
    pdf.subheading('B. Laporan Perubahan Ekuitas');
    pdf.keyValue(
      'Laba ditahan awal periode',
      Formatters.rupiah(data.ekuitas.modalAwal),
    );
    pdf.keyValue(
      'Laba bersih periode ini',
      Formatters.rupiah(data.ekuitas.labaBersih),
      indent: true,
    );
    if (data.ekuitas.modalDisetor > 0) {
      pdf.keyValue(
        'Setoran modal pemilik',
        Formatters.rupiah(data.ekuitas.modalDisetor),
        indent: true,
      );
    }
    pdf.keyValue(
      'Prive (pengambilan pemilik)',
      '(${Formatters.rupiah(data.ekuitas.prive)})',
      indent: true,
    );
    pdf.keyValue(
      'EKUITAS AKHIR PERIODE',
      Formatters.rupiah(data.ekuitas.modalAkhir),
      bold: true,
      topRule: true,
      bottomRule: true,
    );

    // -------------------------------------------------------------- neraca
    pdf.subheading('C. Laporan Posisi Keuangan (Neraca)');
    pdf.text('ASET', size: 9.5, bold: true, gray: 110);
    pdf.keyValue('Kas', Formatters.rupiah(data.neraca.kas), indent: true);
    pdf.keyValue(
      'Persediaan barang',
      Formatters.rupiah(data.neraca.persediaan),
      indent: true,
    );
    pdf.keyValue(
      'Piutang pelanggan',
      Formatters.rupiah(data.neraca.piutang),
      indent: true,
    );
    pdf.keyValue(
      'TOTAL ASET',
      Formatters.rupiah(data.neraca.totalAset),
      bold: true,
      topRule: true,
    );

    pdf.space(6);
    pdf.text('LIABILITAS', size: 9.5, bold: true, gray: 110);
    pdf.keyValue(
      'Hutang usaha (supplier)',
      Formatters.rupiah(data.neraca.hutangUsaha),
      indent: true,
    );
    pdf.keyValue(
      'TOTAL LIABILITAS',
      Formatters.rupiah(data.neraca.totalLiabilitas),
      bold: true,
      topRule: true,
    );

    pdf.space(6);
    pdf.text('EKUITAS', size: 9.5, bold: true, gray: 110);
    pdf.keyValue(
      'Modal disetor pemilik',
      Formatters.rupiah(data.neraca.modalDisetor),
      indent: true,
    );
    pdf.keyValue(
      'Laba ditahan',
      Formatters.rupiah(data.neraca.labaDitahan),
      indent: true,
    );
    pdf.keyValue(
      'Modal awal & penyesuaian',
      Formatters.rupiah(data.neraca.modalAwalPenyesuaian),
      indent: true,
    );
    pdf.keyValue(
      'TOTAL EKUITAS',
      Formatters.rupiah(data.neraca.totalEkuitas),
      bold: true,
      topRule: true,
    );
    pdf.keyValue(
      'TOTAL LIABILITAS + EKUITAS',
      Formatters.rupiah(
        data.neraca.totalLiabilitas + data.neraca.totalEkuitas,
      ),
      bold: true,
      size: 11,
      topRule: true,
      bottomRule: true,
    );
    pdf.note(
      'Neraca memakai nilai terkini untuk kas, persediaan, piutang, dan '
      'hutang. Baris "Modal awal & penyesuaian" menampung stok serta uang '
      'yang sudah ada sebelum aplikasi dipakai, supaya neraca tetap seimbang.',
    );

    // ------------------------------------------------------------ arus kas
    pdf.subheading('D. Laporan Arus Kas');
    pdf.keyValue('Saldo kas awal periode', Formatters.rupiah(data.arusKas.saldoAwal));

    pdf.space(4);
    if (data.arusKas.rincian.isEmpty) {
      pdf.text('Belum ada mutasi kas pada periode ini.', gray: 130);
    } else {
      pdf.row(
        const ['Kategori', 'Masuk', 'Keluar', 'Selisih'],
        weights: const [2.2, 1.6, 1.6, 1.6],
        bold: true,
        shade: true,
        alignLastRight: false,
      );
      for (final a in data.arusKas.rincian) {
        pdf.row(
          [
            CashCategory.label(a.category),
            a.masuk == 0 ? '-' : Formatters.rupiah(a.masuk),
            a.keluar == 0 ? '-' : Formatters.rupiah(a.keluar),
            Formatters.rupiah(a.selisih),
          ],
          weights: const [2.2, 1.6, 1.6, 1.6],
          alignLastRight: false,
          size: 9,
          rule: true,
        );
      }
      pdf.row(
        [
          'TOTAL',
          Formatters.rupiah(data.arusKas.totalMasuk),
          Formatters.rupiah(data.arusKas.totalKeluar),
          Formatters.rupiah(data.arusKas.kenaikanKas),
        ],
        weights: const [2.2, 1.6, 1.6, 1.6],
        alignLastRight: false,
        bold: true,
      );
    }

    pdf.keyValue(
      'KENAIKAN / PENURUNAN KAS',
      Formatters.rupiah(data.arusKas.kenaikanKas),
      topRule: true,
      bold: true,
    );
    pdf.keyValue(
      'SALDO KAS AKHIR PERIODE',
      Formatters.rupiah(data.arusKas.saldoAkhir),
      bold: true,
      size: 11,
      topRule: true,
      bottomRule: true,
    );

    pdf.space(10);
    pdf.note(
      'Laporan disusun dari transaksi yang tercatat di aplikasi: penjualan, '
      'beban, prive, belanja stok, dan pembayaran hutang/piutang.',
    );

    return pdf.build();
  }

  // --------------------------------------------------------------- helpers

  /// Simpan + bagikan rincian penjualan dalam format PDF.
  static Future<void> shareRincianPenjualanPdf(RincianPenjualanData data) async {
    final file = await ExportService.instance.writePdf(
      filename:
          'rincian-penjualan-${ExportService.safeName(data.periode)}',
      bytes: rincianPenjualanPdf(data),
    );
    await ExportService.instance.share(
      file,
      subject: 'Rincian produk terjual - ${data.periode}',
      text: 'Rincian produk terjual ${data.periode}',
    );
  }

  /// Simpan + bagikan rincian penjualan dalam format CSV.
  static Future<void> shareRincianPenjualanCsv(RincianPenjualanData data) async {
    final file = await ExportService.instance.writeCsv(
      filename:
          'rincian-penjualan-${ExportService.safeName(data.periode)}',
      rows: rincianPenjualanCsv(data),
    );
    await ExportService.instance.share(
      file,
      subject: 'Rincian produk terjual - ${data.periode}',
      text: 'Rincian produk terjual ${data.periode}',
    );
  }

  static Future<void> shareLaporanKeuanganPdf(LaporanKeuanganData data) async {
    final file = await ExportService.instance.writePdf(
      filename: 'laporan-keuangan-${ExportService.safeName(data.periode)}',
      bytes: laporanKeuanganPdf(data),
    );
    await ExportService.instance.share(
      file,
      subject: 'Laporan keuangan - ${data.periode}',
      text: 'Laporan keuangan ${data.periode}',
    );
  }

  static Future<void> shareLaporanKeuanganCsv(LaporanKeuanganData data) async {
    final file = await ExportService.instance.writeCsv(
      filename: 'laporan-keuangan-${ExportService.safeName(data.periode)}',
      rows: laporanKeuanganCsv(data),
    );
    await ExportService.instance.share(
      file,
      subject: 'Laporan keuangan - ${data.periode}',
      text: 'Laporan keuangan ${data.periode}',
    );
  }
}
