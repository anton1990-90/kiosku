import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mengelola foto barang yang dipilih dari galeri HP.
///
/// Berbeda dari [StoreLogoService] yang memakai satu nama berkas tetap untuk
/// logo usaha, di sini setiap barang punya berkasnya sendiri. Nama berkas
/// dibuat dari waktu pemilihan, bukan dari id barang, karena saat menambah
/// barang baru id-nya belum ada.
///
/// Foto disalin ke penyimpanan aplikasi supaya tidak ikut hilang kalau pemilik
/// menghapus foto aslinya dari galeri. Yang disimpan di database hanya path-nya.
class ProductPhotoService {
  ProductPhotoService._();
  static final ProductPhotoService instance = ProductPhotoService._();

  /// Awal nama semua berkas foto barang — dipakai untuk mengenali berkas
  /// milik fitur ini dan tidak menyentuh berkas lain di folder yang sama.
  static const _awalanBerkas = 'produk_';

  final ImagePicker _picker = ImagePicker();

  /// Pilih foto dari galeri dan simpan ke penyimpanan aplikasi.
  ///
  /// Mengembalikan path berkas baru, atau `null` kalau pemilik membatalkan
  /// pilihan. Resolusi dikecilkan ke 720 px supaya tidak memakan ruang
  /// penyimpanan dan tetap tajam di daftar barang maupun di kasir.
  Future<String?> pilihDanSimpan() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final nama = '$_awalanBerkas${DateTime.now().millisecondsSinceEpoch}.png';
    final target = File(p.join(dir.path, nama));

    await File(picked.path).copy(target.path);
    return target.path;
  }

  /// Hapus berkas foto lama. Dipanggil saat pemilik mengganti atau menghapus
  /// foto supaya berkas lama tidak menumpuk di penyimpanan.
  ///
  /// Gagal menghapus tidak pernah melempar — yang penting database tidak lagi
  /// menunjuk ke berkas itu.
  Future<void> hapus(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final berkas = File(path);
      if (await berkas.exists()) {
        await berkas.delete();
      }
    } catch (_) {
      // Abaikan: berkas mungkin sudah tidak ada atau sedang dipakai.
    }
  }

  /// Apakah berkas foto benar-benar ada di disk.
  ///
  /// Dipakai sebelum menampilkan gambar, supaya path basi (misalnya setelah
  /// pemilik membersihkan penyimpanan) tidak menghasilkan kotak gambar rusak.
  Future<bool> ada(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
