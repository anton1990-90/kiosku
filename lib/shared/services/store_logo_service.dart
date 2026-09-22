import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mengelola gambar milik toko: logo usaha dan gambar QRIS.
///
/// Gambar yang dipilih dari galeri disalin ke penyimpanan aplikasi supaya
/// tidak hilang kalau pengguna menghapus foto aslinya dari galeri. Yang
/// disimpan di database hanya path-nya.
class StoreLogoService {
  StoreLogoService._();
  static final StoreLogoService instance = StoreLogoService._();

  static const _logoFileName = 'store_logo.png';
  static const _qrisFileName = 'store_qris.png';

  final ImagePicker _picker = ImagePicker();

  // ------------------------------------------------------------------ logo

  /// Pilih gambar dari galeri dan simpan sebagai logo usaha.
  /// Mengembalikan path file baru, atau null kalau pengguna membatalkan.
  Future<String?> pickAndSaveLogo() => _pickAndSave(
        _logoFileName,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

  /// Hapus logo yang tersimpan.
  Future<void> deleteLogo() => _delete(_logoFileName);

  /// Apakah file logo benar-benar ada di disk.
  Future<bool> logoExists(String? path) => _exists(path);

  // ------------------------------------------------------------------ qris

  /// Pilih gambar QRIS dari galeri dan simpan.
  ///
  /// Resolusi dijaga lebih besar daripada logo karena gambar QRIS harus tetap
  /// tajam supaya bisa dipindai pelanggan dari layar HP.
  Future<String?> pickAndSaveQris() => _pickAndSave(
        _qrisFileName,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );

  /// Hapus gambar QRIS yang tersimpan.
  Future<void> deleteQris() => _delete(_qrisFileName);

  /// Apakah file QRIS benar-benar ada di disk.
  Future<bool> qrisExists(String? path) => _exists(path);

  // --------------------------------------------------------------- internal

  Future<String?> _pickAndSave(
    String fileName, {
    required double maxWidth,
    required double maxHeight,
    required int imageQuality,
  }) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, fileName));

    // Timpa gambar lama supaya tidak menumpuk file.
    if (await target.exists()) {
      await target.delete();
    }
    await File(picked.path).copy(target.path);
    return target.path;
  }

  Future<void> _delete(String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, fileName));
      if (await target.exists()) {
        await target.delete();
      }
    } catch (_) {
      // Kalau gagal dihapus, abaikan — file lama akan ditimpa saat ganti.
    }
  }

  Future<bool> _exists(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
