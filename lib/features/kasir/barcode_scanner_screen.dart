import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

/// Barcode scanner screen — scan a product barcode (EAN-13 / UPC / Code128).
///
/// Dua mode:
///   * [rawMode] false (default) — cari produk berdasarkan barcode, lalu
///     kembalikan [ProductModel] lewat Navigator.pop. Dipakai di layar Kasir.
///   * [rawMode] true — langsung kembalikan string barcode apa adanya.
///     Dipakai saat menambah produk baru, karena produknya belum ada.
///
/// Layar ini sengaja dibuat tahan gagal:
///   * Kalau izin kamera pernah ditolak, pengguna tidak terjebak. Tombol
///     "Coba lagi" membuat ulang controller supaya permintaan izin bisa
///     diajukan ulang — `stop()` tidak bisa mereset galat saat kamera belum
///     pernah menyala.
///   * Selalu ada jalan keluar lewat "Masukkan manual", jadi pemindaian tetap
///     bisa diselesaikan walau kamera tidak tersedia.
class BarcodeScannerScreen extends StatefulWidget {
  final bool rawMode;

  const BarcodeScannerScreen({super.key, this.rawMode = false});

  /// Buka layar scan dan tunggu hasil berupa string barcode.
  /// Mengembalikan null kalau pengguna menutup layar tanpa scan.
  static Future<String?> scanRaw(BuildContext context) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => const BarcodeScannerScreen(rawMode: true),
      ),
    );
    return result;
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final _repo = ProductRepository();

  MobileScannerController? _controller;

  /// Kunci widget kamera. Diganti setiap controller dibuat ulang supaya
  /// Flutter membuang State lama dan benar-benar memakai controller baru.
  int _scannerKey = 0;

  MobileScannerException? _error;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = _buatController();
    // Beri kesempatan layar tampil dulu, baru minta izin & nyalakan kamera.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  MobileScannerController _buatController() {
    // autoStart dimatikan supaya urutan start/stop sepenuhnya diatur di sini
    // dan setiap kegagalan bisa ditangkap, bukan hilang diam-diam.
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null) return;
    try {
      await c.start();
      if (!mounted) return;
      if (_error != null) setState(() => _error = null);
    } on MobileScannerException catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
          errorDetails: MobileScannerErrorDetails(message: '$e'),
        );
      });
    }
  }

  /// Buat ulang controller lalu nyalakan lagi.
  ///
  /// Ini satu-satunya cara meminta izin kamera untuk kedua kalinya:
  /// setelah izin ditolak, `stop()` langsung keluar lebih awal karena kamera
  /// tidak pernah berjalan, sehingga galatnya tidak pernah direset.
  Future<void> _cobaLagi() async {
    final lama = _controller;
    setState(() {
      _scannerKey++;
      _controller = _buatController();
      _error = null;
    });
    // Controller lama baru dilepas setelah frame baru terpasang, supaya
    // widget kamera lama tidak menyentuh controller yang sudah dibuang.
    WidgetsBinding.instance.addPostFrameCallback((_) => lama?.dispose());
    await _start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera dilepas sistem saat aplikasi ke latar. Nyalakan lagi saat kembali
    // supaya pratinjau tidak membeku hitam.
    if (state == AppLifecycleState.resumed) {
      final c = _controller;
      if (c == null) return;
      if (c.value.isRunning) return;
      if (c.value.error?.errorCode == MobileScannerErrorCode.permissionDenied) {
        return;
      }
      _start();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.stop();
      c.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------ hasil scan

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await _serahkan(rawValue.trim());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Satu pintu untuk hasil kamera maupun ketikan manual.
  Future<void> _serahkan(String kode) async {
    if (!mounted) return;

    // Mode isi form: kembalikan barcode apa adanya, tanpa cari produk.
    if (widget.rawMode) {
      Navigator.pop(context, kode);
      return;
    }

    final product = await _repo.findByBarcode(kode);
    if (!mounted) return;
    if (product != null) {
      Navigator.pop(context, product);
      return;
    }

    _pesan('Barcode belum terdaftar: $kode');
  }

  void _pesan(String text, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? AppColors.warningMid : AppColors.success,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Isi barcode dengan tangan — jalan keluar kalau kamera bermasalah.
  Future<void> _masukkanManual() async {
    final textController = TextEditingController();
    final hasil = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Masukkan barcode manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ketuk angka yang tertera di bawah barcode pada kemasan.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'Contoh: 8991002101234',
                prefixIcon: Icon(Icons.qr_code, color: AppColors.textTertiary),
              ),
              onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, textController.text.trim()),
            child: const Text('Pakai'),
          ),
        ],
      ),
    );
    textController.dispose();

    if (hasil == null || hasil.isEmpty || !mounted) return;
    await _serahkan(hasil);
  }

  // -------------------------------------------------------------- tampilan

  /// Terjemahkan kode galat jadi penjelasan yang bisa ditindaklanjuti.
  ({String judul, String saran}) _artiError(MobileScannerException e) {
    switch (e.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return (
          judul: 'Izin kamera ditolak',
          saran: 'Aplikasi butuh izin kamera untuk memindai barcode. Buka '
              'Pengaturan > Aplikasi > TokoKu > Izin, nyalakan Kamera. '
              'Setelah itu tekan "Coba lagi".',
        );
      case MobileScannerErrorCode.unsupported:
        return (
          judul: 'Kamera tidak didukung',
          saran: 'Perangkat ini tidak bisa memakai pemindai kamera. '
              'Gunakan tombol "Masukkan manual" di bawah.',
        );
      case MobileScannerErrorCode.controllerAlreadyInitialized:
      case MobileScannerErrorCode.controllerUninitialized:
      case MobileScannerErrorCode.controllerDisposed:
        return (
          judul: 'Kamera perlu dinyalakan ulang',
          saran: 'Tekan "Coba lagi" untuk menyalakan kamera sekali lagi.',
        );
      case MobileScannerErrorCode.genericError:
        return (
          judul: 'Kamera gagal dinyalakan',
          saran: e.errorDetails?.message ??
              'Pastikan kamera tidak sedang dipakai aplikasi lain, '
                  'lalu tekan "Coba lagi".',
        );
    }
  }

  Widget _tampilanError(MobileScannerException error) {
    final arti = _artiError(error);

    return Container(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white54, size: 56),
              const SizedBox(height: 16),
              Text(
                arti.judul,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                arti.saran,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                    ),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Kembali'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _cobaLagi,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: _masukkanManual,
                style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                icon: const Icon(Icons.keyboard, size: 18),
                label: const Text('Masukkan manual'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tampilanKamera(MobileScannerController controller) {
    return Stack(
      alignment: Alignment.center,
      children: [
        MobileScanner(
          key: ValueKey('scanner-$_scannerKey'),
          controller: controller,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) => _tampilanError(error),
        ),
        // Bingkai pembidik.
        IgnorePointer(
          child: Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          bottom: 84,
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isProcessing
                    ? 'Membaca...'
                    : widget.rawMode
                        ? 'Arahkan kamera ke barcode pada kemasan'
                        : 'Arahkan kamera ke barcode produk',
                style: const TextStyle(color: Colors.white, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final error = _error ?? controller?.value.error;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.rawMode ? 'Scan Barcode Produk' : 'Scan Barcode'),
        actions: [
          if (controller != null && error == null)
            ValueListenableBuilder<MobileScannerState>(
              valueListenable: controller,
              builder: (context, value, _) {
                final running = value.isRunning;
                final torchOn = value.torchState == TorchState.on;
                return Row(
                  children: [
                    IconButton(
                      tooltip: torchOn ? 'Matikan lampu' : 'Nyalakan lampu',
                      onPressed: running
                          ? () => controller.toggleTorch()
                          : null,
                      icon: Icon(
                        torchOn ? Icons.flash_on : Icons.flash_off,
                        color: running ? Colors.white : Colors.white38,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Ganti kamera',
                      onPressed:
                          running ? () => controller.switchCamera() : null,
                      icon: Icon(
                        Icons.cameraswitch,
                        color: running ? Colors.white : Colors.white38,
                      ),
                    ),
                  ],
                );
              },
            ),
          IconButton(
            tooltip: 'Masukkan barcode manual',
            onPressed: _masukkanManual,
            icon: const Icon(Icons.keyboard),
          ),
        ],
      ),
      body: controller == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : error != null
              ? _tampilanError(error)
              : _tampilanKamera(controller),
    );
  }
}
