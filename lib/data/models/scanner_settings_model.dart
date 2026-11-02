// Pengaturan pemindai barcode.
//
// Disimpan di SharedPreferences, bukan di database, karena ini pengaturan
// **perangkat**: dua HP yang memakai akun toko yang sama boleh tersambung ke
// alat pindai berbeda — dan alat berbeda berarti kecepatan kirim yang berbeda
// pula. Menyimpannya di database akan membuat satu HP mengubah pengaturan HP
// yang lain.
//
// Catatan penting yang menentukan seluruh rancangan ini: scanner Bluetooth,
// scanner kabel USB, dan scanner nirkabel 2,4 GHz (dongle) **semuanya bekerja
// dengan cara yang sama** — ke Android ketiganya tampil sebagai keyboard.
// Tidak ada API Bluetooth, tidak ada izin USB, dan tidak ada layar "cari alat".
// Yang perlu disesuaikan hanyalah cara membaca ketikan itu: seberapa rapat
// jedanya, apa penanda akhirnya, dan sepanjang apa kodenya.

/// Apa yang dikirim alat di akhir kode.
///
/// Kebanyakan scanner dikonfigurasi mengirim Enter, sebagian Tab, dan sebagian
/// lagi tidak mengirim apa pun. Pilihan ini menentukan kapan kumpulan karakter
/// dianggap selesai — kalau salah, hasilnya "scan tidak bereaksi sama sekali"
/// padahal alatnya sehat.
enum AkhiranPindai {
  enter('enter', 'Enter'),
  tab('tab', 'Tab'),
  keduanya('keduanya', 'Enter / Tab'),
  tanpa('tanpa', 'Tanpa penanda');

  const AkhiranPindai(this.kode, this.label);

  /// Nilai yang disimpan di SharedPreferences.
  final String kode;

  /// Teks yang ditampilkan di layar pengaturan.
  final String label;

  /// Baca dari penyimpanan; nilai tak dikenal jatuh ke [keduanya].
  ///
  /// Bawaan [keduanya] dipilih supaya scanner yang belum pernah diatur tetap
  /// bekerja: hampir semua scanner mengirim Enter, dan yang mengirim Tab juga
  /// ikut tertangkap.
  static AkhiranPindai dariKode(String? kode) {
    for (final akhiran in AkhiranPindai.values) {
      if (akhiran.kode == kode) return akhiran;
    }
    return AkhiranPindai.keduanya;
  }
}

/// Jenis alat yang dipakai.
///
/// Nilainya **tidak** mengubah cara membaca kode — ketiga jenis pertama
/// mengirim sebagai keyboard dan diperlakukan sama. Yang berubah hanya panduan
/// yang ditampilkan dan kartu status USB, karena ketiganya gagal dengan cara
/// yang berbeda: Bluetooth gagal karena belum dipasangkan, USB gagal karena
/// alatnya berada di mode COM, dan dongle gagal karena tidak tercolok.
enum JenisPemindai {
  bluetooth('bluetooth', 'Bluetooth'),
  usb('usb', 'Kabel USB'),
  nirkabel('nirkabel', 'Nirkabel 2,4 GHz'),
  kamera('kamera', 'Kamera HP');

  const JenisPemindai(this.kode, this.label);

  final String kode;
  final String label;

  /// Apakah jenis ini menempel lewat kabel/dongle USB.
  ///
  /// Dipakai untuk memutuskan apakah kartu "Alat USB terdeteksi" perlu
  /// ditampilkan. Menampilkannya untuk pemakai Bluetooth hanya jadi kebisingan.
  bool get lewatUsb =>
      this == JenisPemindai.usb || this == JenisPemindai.nirkabel;

  static JenisPemindai dariKode(String? kode) {
    for (final jenis in JenisPemindai.values) {
      if (jenis.kode == kode) return jenis;
    }
    return JenisPemindai.bluetooth;
  }
}

/// Seluruh pilihan pemindai yang bisa diatur pemilik/kasir.
class ScannerSettings {
  const ScannerSettings({
    this.aktif = true,
    this.jenis = JenisPemindai.bluetooth,
    this.jedaAntarKarakter = 120,
    this.akhiran = AkhiranPindai.keduanya,
    this.panjangMinimum = 4,
    this.panjangMaksimum = 256,
    this.awalanBuang = '',
    this.akhiranBuang = '',
    this.getar = true,
    this.bunyi = false,
  });

  /// Penerima ketikan scanner menyala.
  ///
  /// Boleh dimatikan kalau pemilik tidak memakai scanner sama sekali: tanpa
  /// saklar ini, ketikan cepat di papan ketik fisik bisa terbaca sebagai kode.
  final bool aktif;

  final JenisPemindai jenis;

  /// Jeda paling longgar antar karakter yang masih dianggap satu kode (ms).
  ///
  /// Inilah satu-satunya pembeda antara "hasil scan" dan "ketikan manusia".
  /// Manusia mengetik dengan jeda ratusan milidetik; scanner jauh lebih rapat.
  /// Scanner lambat (Bluetooth murah, atau alat yang mengirim lewat adaptor)
  /// bisa berjeda sampai 200 ms — karena itu nilainya bisa dinaikkan. Tapi
  /// menaikkannya terlalu tinggi membuat ketikan manusia ikut terbaca, jadi
  /// ada batas atasnya.
  final int jedaAntarKarakter;

  final AkhiranPindai akhiran;

  /// Panjang kode paling pendek yang masih masuk akal.
  final int panjangMinimum;

  /// Panjang kode paling panjang yang masih diterima.
  ///
  /// Bawaannya 256, bukan 64 seperti versi lama. Barcode 1D paling panjang
  /// (Code 128) hanya 20–30 karakter, tetapi kode 2D seperti QR, Data Matrix,
  /// PDF417, dan Aztec bisa berisi ratusan karakter — dan memotongnya di
  /// tengah membuat kode itu tidak pernah cocok dengan data mana pun. QR berisi
  /// alamat web sudah melewati 128 karakter, jadi angka itu terlalu ketat
  /// untuk dijadikan bawaan.
  final int panjangMaksimum;

  /// Teks yang dibuang dari awal kode, mis. penanda AIM seperti `]C1`.
  final String awalanBuang;

  /// Teks yang dibuang dari akhir kode.
  final String akhiranBuang;

  /// Getarkan HP sekali setiap ada kode yang berhasil dibaca.
  ///
  /// Umpan balik ini bukan hiasan: kasir sering memindai tanpa melihat layar,
  /// dan getaran kecil memberitahu bahwa kodenya masuk tanpa perlu menoleh.
  final bool getar;

  /// Bunyikan nada klik setiap ada kode yang berhasil dibaca.
  final bool bunyi;

  /// Jeda diam yang menutup kumpulan kalau alat tidak mengirim penanda akhir.
  ///
  /// Tidak diatur pengguna, melainkan **diturunkan** dari
  /// [jedaAntarKarakter]: harus lebih longgar daripada jeda antar karakter,
  /// kalau tidak kumpulan ditutup di tengah-tengah scanner yang sedang
  /// mengirim. Menjadikannya pengaturan terpisah hanya menambah satu cara
  /// untuk salah atur tanpa menambah kemampuan apa pun.
  Duration get jedaDiam =>
      Duration(milliseconds: jedaAntarKarakter + 130);

  /// Panjang minimum saat kumpulan ditutup karena diam, bukan karena penanda.
  ///
  /// Lebih ketat daripada [panjangMinimum] karena buktinya lebih lemah: tanpa
  /// penanda akhir, hanya kumpulan yang mustahil diketik manusia yang boleh
  /// dipercaya.
  int get panjangMinimumDiam =>
      panjangMinimum < 6 ? 6 : panjangMinimum;

  ScannerSettings copyWith({
    bool? aktif,
    JenisPemindai? jenis,
    int? jedaAntarKarakter,
    AkhiranPindai? akhiran,
    int? panjangMinimum,
    int? panjangMaksimum,
    String? awalanBuang,
    String? akhiranBuang,
    bool? getar,
    bool? bunyi,
  }) {
    return ScannerSettings(
      aktif: aktif ?? this.aktif,
      jenis: jenis ?? this.jenis,
      jedaAntarKarakter: jedaAntarKarakter ?? this.jedaAntarKarakter,
      akhiran: akhiran ?? this.akhiran,
      panjangMinimum: panjangMinimum ?? this.panjangMinimum,
      panjangMaksimum: panjangMaksimum ?? this.panjangMaksimum,
      awalanBuang: awalanBuang ?? this.awalanBuang,
      akhiranBuang: akhiranBuang ?? this.akhiranBuang,
      getar: getar ?? this.getar,
      bunyi: bunyi ?? this.bunyi,
    );
  }
}
