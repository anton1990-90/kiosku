import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'shared/services/barcode_wedge.dart';
import 'shared/services/scanner_settings_service.dart';

/// Entry point — initializes the app with Riverpod ProviderScope.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pengaturan pemindai dimuat SEBELUM aplikasi tampil, bukan sesudah.
  //
  // Penerima scanner dipasang di atas Navigator (lihat `app.dart`), jadi ia
  // sudah menerima ketikan sejak frame pertama. Kalau pengaturannya baru dibaca
  // belakangan, ketikan yang datang di sela itu dinilai dengan nilai bawaan —
  // dan untuk scanner yang jedanya lebih longgar daripada bawaan, hasilnya
  // "scan pertama selalu gagal". Membacanya di sini menutup celah itu.
  final pengaturanPindai = await ScannerSettingsService.instance.muat();
  BarcodeWedgeScanner.instance.atur(pengaturanPindai);

  runApp(
    const ProviderScope(
      child: TokoKuApp(),
    ),
  );
}
