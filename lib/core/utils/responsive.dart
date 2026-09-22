import 'package:flutter/widgets.dart';

/// Aturan tampilan responsif yang dipakai bersama oleh semua layar.
///
/// Aplikasi ini dipakai di HP toko yang kecil maupun tablet, jadi ukuran
/// dipilih dari lebar layar, bukan angka tetap. Tiga hal yang diatur:
///
///   * [isTablet] — memilih navigasi bawah atau rel samping.
///   * [gridColumns] — jumlah kolom daftar produk.
///   * [centered] — membatasi lebar isi halaman supaya tidak melebar penuh.
class Responsive {
  Responsive._();

  /// Lebar mulai dianggap tablet. Di bawah ini tata letak HP yang dipakai.
  static const double tabletBreakpoint = 720;

  /// Lebar maksimum isi halaman. Tanpa batas ini, di tablet baris teks jadi
  /// sangat panjang dan sulit dibaca.
  static const double maxContentWidth = 760;

  /// Lebar minimum satu kartu produk sebelum kolomnya ditambah.
  static const double minTileWidth = 168;

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= tabletBreakpoint;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;

  /// Jumlah kolom grid produk untuk lebar tertentu.
  ///
  /// Minimal 2 (HP kecil) dan maksimal [maks] supaya kartunya tidak jadi
  /// terlalu kecil di layar sangat lebar.
  static int columnsForWidth(
    double lebar, {
    double minTileWidth = minTileWidth,
    int maks = 6,
  }) {
    if (lebar <= 0) return 2;
    final kolom = (lebar / minTileWidth).floor();
    if (kolom < 2) return 2;
    if (kolom > maks) return maks;
    return kolom;
  }

  static int gridColumns(BuildContext context, {int maks = 6}) =>
      columnsForWidth(width(context), maks: maks);

  /// Bungkus isi halaman supaya tetap di tengah dan tidak melebar penuh.
  static Widget centered(
    Widget child, {
    double maxWidth = maxContentWidth,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
