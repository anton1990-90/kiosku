import 'formatters.dart';

/// Aturan satuan barang dan kuantitas pecahan.
///
/// Satu tempat saja. Dipakai oleh keranjang, tombol cepat di kasir, dan
/// formulir produk — supaya aturannya tidak bercabang antar layar.
///
/// Satuannya datang dari kolom `products.unit` dan dipilih pemilik toko saat
/// membuat barang. Barang yang dijual per kilo/liter/ikat boleh dijual
/// sebagian; yang dijual per biji atau per dus tidak. Aturan itu diturunkan
/// dari satuan, bukan disimpan sebagai kolom baru — jadi tidak perlu migrasi,
/// dan menambah satu barang pecahan cukup dengan mengganti satuannya.
///
/// Kalau nanti pemilik toko perlu saklar per produk (mis. gula boleh pecahan,
/// telur tidak, padahal keduanya "kg"), cukup ubah [bolehPecahan] — seluruh
/// aplikasi ikut, karena tidak ada layar yang memutuskan sendiri.
class Satuan {
  Satuan._();

  /// Satuan yang **tidak** bisa dipecah.
  ///
  /// Selain daftar ini dianggap bisa dijual sebagian. Sengaja "boleh kalau
  /// tidak terdaftar": satuan buatan pemilik toko ("ember", "karung", "pak")
  /// tidak mungkin didaftar semuanya, dan menolak pecahan untuk satuan tak
  /// dikenal akan membuat fitur ini tidak berguna justru bagi yang butuh.
  static const List<String> satuanBulat = [
    'pcs',
    'buah',
    'biji',
    'butir',
    'lembar',
    'batang',
    'bungkus',
    'sachet',
    'dus',
    'karton',
    'pak',
    'box',
    'botol',
    'kaleng',
    'papan',
  ];

  /// Barang dengan satuan ini boleh dijual sebagian?
  static bool bolehPecahan(String? unit) {
    final u = (unit ?? 'pcs').trim().toLowerCase();
    return !satuanBulat.contains(u);
  }

  /// Langkah terkecil yang masuk akal untuk [unit].
  ///
  /// Dipakai sebagai batas bawah, bukan sebagai kelipatan: kasir tetap boleh
  /// mengetik 0,1 kg walau tombol cepatnya ¼ dan ½.
  static double langkahTerkecil(String? unit) => bolehPecahan(unit) ? 0.01 : 1;

  /// Nilai tombol cepat di kasir untuk [unit].
  static List<double> tombolCepat(String? unit) =>
      bolehPecahan(unit) ? pecahanCepat : bulatCepat;

  /// Tombol cepat untuk satuan yang bisa dipecah.
  ///
  /// Hanya seperempat dan setengah — dua pecahan yang benar-benar dipakai di
  /// warung (¼ kg gula, ½ liter minyak). Menambah lebih banyak tombol hanya
  /// menambah kerumunan tanpa menambah kecepatan.
  static const List<double> pecahanCepat = [0.25, 0.5, 1, 2];

  /// Tombol cepat untuk satuan yang tidak bisa dipecah.
  static const List<double> bulatCepat = [1, 2, 5, 10];

  /// Label tombol cepat: ¼, ½, atau angka biasa.
  static String labelTombol(double nilai) {
    if (nilai == 0.25) return '¼';
    if (nilai == 0.5) return '½';
    return Formatters.jumlah(nilai);
  }

  /// Membaca jumlah yang diketik kasir.
  ///
  /// Menerima koma **dan** titik. Papan tombol HP berbahasa Indonesia
  /// menghasilkan koma, sedangkan orang yang biasa memakai kalkulator mengetik
  /// titik; menolak salah satunya membuat kasir mengira aplikasinya rusak.
  ///
  /// Mengembalikan `null` kalau tidak terbaca — supaya pemanggil bisa
  /// membedakan "kosong/salah ketik" dari "sengaja nol".
  static double? baca(String? teks) {
    final t = (teks ?? '').trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  /// Rapikan ke dua angka di belakang koma.
  ///
  /// Tanpa ini `0.1 + 0.2` tersimpan sebagai `0.30000000000000004` dan struk
  /// menampilkan angka yang tidak masuk akal.
  static double rapikan(double nilai) => (nilai * 100).roundToDouble() / 100;

  /// Batasi [nilai] ke rentang yang sah: minimal satu langkah, maksimal [stok].
  ///
  /// Dipakai keranjang supaya kasir tidak bisa menjual lebih banyak daripada
  /// yang ada di rak, dan tidak bisa menyisakan jumlah nol yang membuat baris
  /// tak terlihat tapi tetap terhitung.
  static double batasi(double nilai, String? unit, double stok) {
    final minimum = langkahTerkecil(unit);
    final maksimum = stok < minimum ? minimum : stok;
    if (nilai < minimum) return minimum;
    if (nilai > maksimum) return rapikan(maksimum);
    return rapikan(nilai);
  }
}
