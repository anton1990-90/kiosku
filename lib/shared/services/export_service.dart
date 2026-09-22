import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Menyimpan berkas ekspor lalu membuka menu "Bagikan" Android.
///
/// Berkas ditulis ke folder dokumen aplikasi (tidak perlu izin penyimpanan),
/// lalu dibagikan lewat share sheet supaya pengguna bisa menyimpannya ke
/// WhatsApp, email, Google Drive, atau membukanya di aplikasi lain.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  /// Folder tempat semua hasil ekspor disimpan.
  Future<Directory> _folder() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/ekspor');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Nama berkas yang aman dipakai di sistem berkas.
  static String safeName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^A-Za-z0-9 _\-]'), '').trim();
    return cleaned.replaceAll(RegExp(r'\s+'), '-').toLowerCase();
  }

  /// Tulis berkas CSV.
  ///
  /// Ditambahi BOM UTF-8 supaya Excel di Windows membaca huruf beraksen
  /// dengan benar, dan pemisahnya titik koma agar cocok dengan Excel
  /// berlokal Indonesia.
  Future<File> writeCsv({
    required String filename,
    required List<List<String>> rows,
  }) async {
    final dir = await _folder();
    final file = File('${dir.path}/$filename.csv');

    final buffer = StringBuffer('\uFEFF');
    for (final row in rows) {
      buffer.writeln(row.map(_csvCell).join(';'));
    }

    await file.writeAsString(buffer.toString(), encoding: utf8, flush: true);
    return file;
  }

  static String _csvCell(String value) {
    final needsQuote = value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    final escaped = value.replaceAll('"', '""');
    return needsQuote ? '"$escaped"' : escaped;
  }

  /// Tulis berkas PDF dari byte yang sudah jadi.
  Future<File> writePdf({
    required String filename,
    required Uint8List bytes,
  }) async {
    final dir = await _folder();
    final file = File('${dir.path}/$filename.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Buka menu bagikan untuk satu berkas.
  Future<void> share(
    File file, {
    String? subject,
    String? text,
  }) async {
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: subject,
      text: text,
    );
  }
}
