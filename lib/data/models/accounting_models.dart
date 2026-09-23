/// Model laporan keuangan standar akuntansi.
///
/// Semua angka dihitung dari transaksi yang sudah tercatat (penjualan, beban,
/// prive, kas, hutang). Aplikasi tidak memakai jurnal umum dua sisi — laporan
/// disusun secara turunan, cara yang lazim untuk aplikasi kasir UMKM.

/// Satu baris kelompok beban pada laporan laba rugi.
class BebanItem {
  final String category;
  final int amount;

  const BebanItem({required this.category, required this.amount});
}

/// Laporan Laba Rugi (income statement).
class LabaRugi {
  final int pendapatan; // penjualan bruto
  final int hpp; // harga pokok penjualan
  final List<BebanItem> beban;
  final int totalBeban;

  const LabaRugi({
    this.pendapatan = 0,
    this.hpp = 0,
    this.beban = const [],
    this.totalBeban = 0,
  });

  int get labaKotor => pendapatan - hpp;

  int get labaBersih => labaKotor - totalBeban;

  /// Margin kotor dalam persen (0 kalau belum ada penjualan).
  double get marginKotor => pendapatan == 0 ? 0 : labaKotor / pendapatan;

  /// Margin bersih dalam persen.
  double get marginBersih => pendapatan == 0 ? 0 : labaBersih / pendapatan;

  bool get isEmpty => pendapatan == 0 && totalBeban == 0;
}

/// Laporan Perubahan Ekuitas.
class PerubahanEkuitas {
  final int modalAwal; // akumulasi laba ditahan sebelum periode
  final int labaBersih; // laba periode ini
  final int prive; // pengambilan pemilik pada periode ini
  final int modalDisetor; // setoran modal pada periode ini

  const PerubahanEkuitas({
    this.modalAwal = 0,
    this.labaBersih = 0,
    this.prive = 0,
    this.modalDisetor = 0,
  });

  /// Ekuitas akhir = modal awal + laba bersih + setoran modal - prive.
  int get modalAkhir => modalAwal + labaBersih + modalDisetor - prive;
}

/// Laporan Posisi Keuangan (neraca).
class Neraca {
  // Aset
  final int kas;
  final int persediaan;
  final int piutang;
  // Liabilitas
  final int hutangUsaha;
  // Ekuitas
  final int modalDisetor;
  final int labaDitahan; // akumulasi laba bersih - prive, sebelum periode
  final int labaBersihPeriode;
  final int privePeriode;

  const Neraca({
    this.kas = 0,
    this.persediaan = 0,
    this.piutang = 0,
    this.hutangUsaha = 0,
    this.modalDisetor = 0,
    this.labaDitahan = 0,
    this.labaBersihPeriode = 0,
    this.privePeriode = 0,
  });

  int get totalAset => kas + persediaan + piutang;

  int get totalLiabilitas => hutangUsaha;

  /// Ekuitas yang benar-benar berasal dari transaksi yang tercatat.
  int get ekuitasTercatat =>
      modalDisetor + labaDitahan + labaBersihPeriode - privePeriode;

  /// Modal awal & penyesuaian.
  ///
  /// Stok dan uang yang sudah ada sebelum aplikasi dipakai tidak punya
  /// transaksi pencatatan. Supaya neraca tetap seimbang, selisihnya
  /// ditampilkan sebagai satu baris tersendiri — bukan disembunyikan.
  int get modalAwalPenyesuaian =>
      totalAset - totalLiabilitas - ekuitasTercatat;

  int get totalEkuitas => ekuitasTercatat + modalAwalPenyesuaian;

  /// Neraca seimbang kalau aset = liabilitas + ekuitas.
  bool get seimbang => totalAset == totalLiabilitas + totalEkuitas;
}

/// Satu kelompok arus kas.
class ArusKasItem {
  final String category;
  final int masuk;
  final int keluar;

  const ArusKasItem({
    required this.category,
    this.masuk = 0,
    this.keluar = 0,
  });

  int get selisih => masuk - keluar;
}

/// Laporan Arus Kas (metode langsung, dikelompokkan per kategori).
class ArusKas {
  final int saldoAwal;
  final List<ArusKasItem> rincian;

  const ArusKas({this.saldoAwal = 0, this.rincian = const []});

  int get totalMasuk => rincian.fold(0, (s, i) => s + i.masuk);

  int get totalKeluar => rincian.fold(0, (s, i) => s + i.keluar);

  int get kenaikanKas => totalMasuk - totalKeluar;

  int get saldoAkhir => saldoAwal + kenaikanKas;

  bool get isEmpty => rincian.isEmpty;
}

/// Satu transaksi penjualan beserta rincian itemnya — untuk daftar
/// "transaksi hari ini" dan ekspor.
class SaleWithItems {
  final int saleId;
  final String invoiceNumber;
  final String? customerName;
  final String paymentMethod;
  final int totalAmount;
  final int totalProfit;
  final int totalItems;
  final int paidAmount;
  final int changeAmount;
  final bool isDebt;
  /// Potongan untuk seluruh nota, di luar potongan per baris. Dalam rupiah.
  final int discount;
  final DateTime createdAt;
  final List<SaleLine> lines;

  const SaleWithItems({
    required this.saleId,
    required this.invoiceNumber,
    this.customerName,
    required this.paymentMethod,
    required this.totalAmount,
    required this.totalProfit,
    required this.totalItems,
    required this.paidAmount,
    required this.changeAmount,
    this.isDebt = false,
    this.discount = 0,
    required this.createdAt,
    this.lines = const [],
  });

  /// Semua potongan yang berlaku pada nota ini: potongan per baris ditambah
  /// potongan nota.
  int get totalDiscount =>
      lines.fold(0, (s, l) => s + l.discount) + discount;

  int get sisaBelumDibayar {
    final sisa = totalAmount - paidAmount;
    return sisa < 0 ? 0 : sisa;
  }
}

/// Satu baris item di dalam transaksi.
class SaleLine {
  final String productName;
  final int quantity;
  final int sellPrice;
  final int costPrice;
  /// Harga baris setelah potongan baris dikurangi.
  final int subtotal;
  /// Potongan untuk baris ini, dalam rupiah.
  final int discount;

  const SaleLine({
    required this.productName,
    required this.quantity,
    required this.sellPrice,
    required this.costPrice,
    required this.subtotal,
    this.discount = 0,
  });

  /// Laba baris ini, dihitung dari uang yang benar-benar dibayar.
  int get profit => subtotal - costPrice * quantity;
}
