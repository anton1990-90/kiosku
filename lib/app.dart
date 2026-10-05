import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_router.dart';
import 'shared/services/barcode_wedge.dart';

/// Root app widget — MaterialApp.router with GoRouter.
class TokoKuApp extends ConsumerWidget {
  const TokoKuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'TokoKu — Sembako & Penjualan',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      // Scanner barcode Bluetooth mode HID tampil ke Android sebagai keyboard
      // fisik, jadi penerimanya cukup dipasang sekali di sini — di ATAS
      // Navigator, supaya ketikan dari layar mana pun naik ke sini.
      //
      // `canRequestFocus: false` dan `skipTraversal: true` penting: tanpa
      // keduanya, simpul fokus ini ikut diperebutkan dan kolom teks di dalam
      // layar bisa kehilangan fokus begitu aplikasi dibuka.
      builder: (context, child) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) => BarcodeWedgeScanner.instance.dengar(event),
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
