import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Mengelola logo usaha milik pengguna.
///
/// Gambar yang dipilih dari galeri disalin ke penyimpanan aplikasi supaya
/// tidak hilang kalau pengguna menghapus foto aslinya dari galeri. Yang
/// disimpan di database hanya path-nya.
class StoreLogoService {
  StoreLogoService._();
  static final StoreLogoService instance = StoreLogoService._();

  static const _fileName = 'store_logo.png';

  final ImagePicker _picker = ImagePicker();

  /// Pilih gambar dari galeri dan simpan sebagai logo.
  /// Mengembalikan path file baru, atau null kalau pengguna membatalkan.
  Future<String?> pickAndSaveLogo() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final target = File(p.join(dir.path, _fileName));

    // Timpa logo lama supaya tidak menumpuk file.
    if (await target.exists()) {
      await target.delete();
    }
    await File(picked.path).copy(target.path);
    return target.path;
  }

  /// Hapus logo yang tersimpan.
  Future<void> deleteLogo() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final target = File(p.join(dir.path, _fileName));
      if (await target.exists()) {
        await target.delete();
      }
    } catch (_) {
      // Kalau gagal dihapus, abaikan — logo lama akan ditimpa saat ganti.
    }
  }

  /// Apakah file logo benar-benar ada di disk.
  Future<bool> logoExists(String? path) async {
    if (path == null || path.isEmpty) return false;
    try {
      return await File(path).exists();
    } catch (_) {
      return false;
    }
  }
}
