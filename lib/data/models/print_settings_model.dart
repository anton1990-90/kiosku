// Pengaturan cetak struk.
//
// Disimpan di SharedPreferences, bukan di database, karena ini pengaturan
// **perangkat**: dua HP yang memakai akun toko yang sama boleh tersambung ke
// printer berbeda — dan printer berbeda berarti ukuran kertas berbeda.
// Menyimpannya di database akan membuat satu HP mengubah ukuran kertas HP
// yang lain.

/// Gaya baris TOTAL di struk.
///
/// [normal] mencetak "TOTAL ... Rp 30.000" dalam satu baris. [besar] mencetak
/// label TOTAL lalu angkanya di baris berikutnya dengan huruf dua kali lipat.
///
/// Gaya [besar] sengaja **tidak** menaruh label dan angka dalam satu baris:
/// huruf dua kali lipat hanya menyisakan 16 karakter per baris di kertas
/// 58 mm, sedangkan "TOTAL" + "Rp 1.250.000" butuh lebih dari itu — dan
/// printer memotong sisanya, bukan membungkusnya. Itu persis yang membuat
/// "Rp 30.000" pernah tercetak "Rp 30.0".
enum GayaTotal {
  normal('normal', 'Satu baris'),
  besar('besar', 'Angka besar');

  const GayaTotal(this.kode, this.label);

  /// Nilai yang disimpan di SharedPreferences.
  final String kode;

  /// Teks yang ditampilkan di layar pengaturan.
  final String label;

  /// Baca dari penyimpanan; nilai tak dikenal jatuh ke [besar].
  static GayaTotal dariKode(String? kode) {
    for (final gaya in GayaTotal.values) {
      if (gaya.kode == kode) return gaya;
    }
    return GayaTotal.besar;
  }
}

/// Seluruh pilihan cetak yang bisa diatur pemilik/kasir.
class PrintSettings {
  const PrintSettings({
    this.lebarKertas = 58,
    this.gayaTotal = GayaTotal.besar,
    this.cetakLogo = true,
    this.cetakQris = true,
    this.barisKosong = 3,
    this.ingatPrinter = false,
    this.printerId,
    this.printerNama,
    this.printerJenis = 'klasik',
  });

  /// 58 atau 80 (mm). Nilai lain dianggap 58 oleh [ReceiptService].
  final int lebarKertas;

  final GayaTotal gayaTotal;

  /// Cetak logo usaha di kepala struk. Dimatikan kalau printer lambat atau
  /// gambar kerap gagal.
  final bool cetakLogo;

  /// Cetak gambar QRIS di struk. Hanya berlaku untuk pembayaran QRIS.
  final bool cetakQris;

  /// Baris kosong sebelum kertas dipotong — memberi ruang sobek.
  final int barisKosong;

  /// Sambung otomatis ke printer terakhir tanpa menampilkan layar pilih.
  final bool ingatPrinter;

  final String? printerId;
  final String? printerNama;

  /// 'klasik' (Bluetooth Classic SPP) atau 'ble'.
  final String printerJenis;

  bool get adaPrinterTersimpan => (printerId ?? '').trim().isNotEmpty;

  PrintSettings copyWith({
    int? lebarKertas,
    GayaTotal? gayaTotal,
    bool? cetakLogo,
    bool? cetakQris,
    int? barisKosong,
    bool? ingatPrinter,
    String? printerId,
    String? printerNama,
    String? printerJenis,
  }) {
    return PrintSettings(
      lebarKertas: lebarKertas ?? this.lebarKertas,
      gayaTotal: gayaTotal ?? this.gayaTotal,
      cetakLogo: cetakLogo ?? this.cetakLogo,
      cetakQris: cetakQris ?? this.cetakQris,
      barisKosong: barisKosong ?? this.barisKosong,
      ingatPrinter: ingatPrinter ?? this.ingatPrinter,
      printerId: printerId ?? this.printerId,
      printerNama: printerNama ?? this.printerNama,
      printerJenis: printerJenis ?? this.printerJenis,
    );
  }

  /// Salinan tanpa printer tersimpan.
  ///
  /// Dipisah dari [copyWith] karena `copyWith` tidak bisa mengosongkan nilai:
  /// parameter `null` di sana berarti "jangan diubah".
  PrintSettings tanpaPrinter() {
    return PrintSettings(
      lebarKertas: lebarKertas,
      gayaTotal: gayaTotal,
      cetakLogo: cetakLogo,
      cetakQris: cetakQris,
      barisKosong: barisKosong,
      ingatPrinter: ingatPrinter,
      printerId: null,
      printerNama: null,
      printerJenis: 'klasik',
    );
  }
}
