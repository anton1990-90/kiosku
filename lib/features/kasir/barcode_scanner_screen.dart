import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/product_repository.dart';

/// Barcode scanner screen — scan a product barcode (EAN-13 / UPC).
///
/// Dua mode:
///   * [rawMode] false (default) — cari produk berdasarkan barcode, lalu
///     kembalikan [ProductModel] lewat Navigator.pop. Dipakai di layar Kasir.
///   * [rawMode] true — langsung kembalikan string barcode apa adanya.
///     Dipakai saat menambah produk baru, karena produknya belum ada.
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

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _repo = ProductRepository();
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _isProcessing = true;

    try {
      // Mode isi form: kembalikan barcode apa adanya, tanpa cari produk.
      if (widget.rawMode) {
        if (mounted) Navigator.pop(context, rawValue);
        return;
      }

      // Look up product by barcode
      final product = await _repo.findByBarcode(rawValue);
      if (product != null && mounted) {
        Navigator.pop(context, product);
        return;
      }

      // No product match — return raw barcode so caller can handle
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode tidak ditemukan: $rawValue'),
            backgroundColor: AppColors.warningMid,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
        // Reset after a short delay so the user can scan again
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.rawMode ? 'Scan Barcode Produk' : 'Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => _buildError(),
          ),
          // Scan frame overlay
          Container(
            width: 260,
            height: 160,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.accent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          Positioned(
            bottom: 60,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.rawMode
                    ? 'Arahkan kamera ke barcode pada kemasan produk'
                    : 'Arahkan kamera ke barcode produk',
                style: const TextStyle(color: Colors.white, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: Colors.white54, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Kamera tidak tersedia',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Izinkan akses kamera di pengaturan HP Anda, atau masukkan barcode manual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali'),
            ),
          ],
        ),
      ),
    );
  }
}
