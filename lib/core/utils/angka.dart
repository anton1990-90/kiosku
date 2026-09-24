/// Pembacaan angka dari SQLite.
///
/// Satu kolom bisa berisi INTEGER **atau** REAL tergantung nilainya. SQLite
/// hanya memakai tipe yang ditulis di `CREATE TABLE` sebagai *affinity*, bukan
/// sebagai batasan: di kolom `quantity INTEGER` nilai `2` disimpan sebagai
/// integer, sedangkan `0.5` disimpan sebagai real. Itu memang perilaku yang
/// diinginkan sejak barang bisa dijual sebagian (¼ kg gula), dan justru karena
/// itu kolomnya **tidak perlu** diubah tipenya — tidak ada `ALTER COLUMN` di
/// SQLite, dan menulis ulang `CREATE TABLE products/sales/sale_items` berarti
/// membongkar tabel yang sudah berisi data penjual pelanggan.
///
/// Konsekuensinya: `map['quantity'] as int` meledak begitu nilainya 0.5, dan
/// `as double` meledak begitu nilainya 2. Keduanya galat **runtime**, muncul di
/// HP pelanggan, dan tidak satu pun pemeriksa statis di repo ini bisa melihat
/// tipe. Karena itu seluruh pembacaan angka dari database lewat kelas ini.
class Angka {
  Angka._();

  /// Kuantitas / jumlah barang. Boleh pecahan.
  ///
  /// Dipakai untuk kolom `products.stock`, `products.min_stock`,
  /// `sale_items.quantity`, `sales.total_items`, dan `stock_movements.quantity`.
  static double jumlah(Object? nilai) {
    if (nilai is num) return nilai.toDouble();
    if (nilai is String) return double.tryParse(nilai) ?? 0.0;
    return 0;
  }

  /// Seperti [jumlah], tapi memakai [cadangan] kalau nilainya kosong.
  ///
  /// Dipakai kolom yang punya nilai cadangan di Dart (mis. `min_stock` yang
  /// formulirnya menawarkan 5). Tanpa ini, `null` akan jadi 0 dan batas minimum
  /// stok tiba-tiba berubah jadi nol.
  static double jumlahAtau(Object? nilai, double cadangan) =>
      nilai == null ? cadangan : jumlah(nilai);

  /// Uang. Selalu rupiah bulat.
  ///
  /// Hasil SQL seperti `SUM(subtotal - cost_price * quantity)` berbentuk REAL
  /// begitu kuantitasnya pecahan, padahal uang di aplikasi ini selalu bilangan
  /// bulat. Pembulatannya dikumpulkan di sini supaya tidak ada satu laporan pun
  /// yang menyimpan nilai setengah rupiah.
  static int uang(Object? nilai) {
    if (nilai is int) return nilai;
    if (nilai is num) return nilai.round();
    if (nilai is String) return double.tryParse(nilai)?.round() ?? 0;
    return 0;
  }
}
