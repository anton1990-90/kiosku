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
///   * Hasil deteksi **tidak langsung dipercaya**. Dua penjaga dipasang sebelum
///     sebuah kode diterima: jeda tenang sesudah kamera menyala, dan syarat
///     kode yang sama terbaca dua kali berturut-turut. Tanpa keduanya layar ini
///     menutup pada deteksi PERTAMA, dan deteksi pertama sering datang sebelum
///     pengguna sempat mengarahkan kamera — gejalanya persis "kamera terbuka
///     lalu langsung tertutup, tidak ada yang terbaca".
///   * Hasil yang sudah diserahkan menutup layar ini **sekali saja**. Kamera
///     baru dilepas setelah animasi penutupannya selesai, jadi tanpa penjaga
///     ini deteksi berikutnya memanggil `Navigator.pop` untuk kedua kalinya —
///     dan yang tertutup adalah layar pemanggilnya. Gejalanya: "scan lalu
///     langsung keluar dan kembali ke daftar produk", tanpa barcode terisi.
///   * `start()` tidak pernah dipanggil dua kali untuk controller yang sama.
///     Dialog izin kamera membuat aplikasi ke latar lalu kembali, dan penanganan
///     "resumed" bisa memanggil `start()` lagi tepat saat permintaan pertama
///     masih berjalan — percobaan kedua itu mematikan kamera yang baru menyala.
///   * Kegagalan saat memakai hasil scan **ditampilkan**, tidak dibiarkan
///     hilang. Sebelumnya `_serahkan` dipanggil tanpa penjaga, jadi satu galat
///     apa pun membuat layarnya diam saja sesudah barcode terbaca — dan itu
///     terbaca sebagai "scan tidak bisa".
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
  /// Jeda tenang sesudah kamera menyala.
  ///
  /// Deteksi yang datang sebelum ini diabaikan. Kamera hampir selalu
  /// melaporkan sesuatu dari frame-frame awal — barcode di rak sebelah, label
  /// di meja, atau pantulan layar sendiri — dan tanpa jeda ini layar langsung
  /// menutup sebelum pengguna sempat mengarahkan kamera.
  static const _jedaTenang = Duration(milliseconds: 800);

  /// Berapa kali kode yang sama harus terbaca berturut-turut sebelum diterima.
  ///
  /// Satu bacaan bisa berasal dari satu frame yang salah tafsir, dan
  /// menerimanya berarti layar menutup dengan kode yang salah. Ini hanya bisa
  /// bekerja karena `detectionSpeed` bernilai [DetectionSpeed.normal]: dengan
  /// [DetectionSpeed.noDuplicates] bacaan yang sama justru tidak akan pernah
  /// datang dua kali, sehingga tidak ada kode yang bisa lolos.
  static const _bacaanYakin = 2;

  final _repo = ProductRepository();

  MobileScannerController? _controller;

  /// Kunci widget kamera. Diganti setiap controller dibuat ulang supaya
  /// Flutter membuang State lama dan benar-benar memakai controller baru.
  int _scannerKey = 0;

  MobileScannerException? _error;
  bool _isProcessing = false;

  /// Controller yang `start()`-nya sedang berjalan.
  ///
  /// Dibandingkan dengan **controller**, bukan sekadar penanda benar/salah:
  /// sesudah "Coba lagi" controller-nya sudah berganti, jadi penjaga milik
  /// controller lama tidak boleh menghalangi yang baru.
  MobileScannerController? _sedangMulai;

  /// Kapan kamera selesai menyala. `null` berarti belum.
  DateTime? _mulaiJalan;

  /// Kode yang sedang menunggu pembacaan kedua, dan berapa kali berturut-turut
  /// kode itu terbaca.
  String? _kodeTerakhir;
  int _berapaKali = 0;

  /// Kode yang barusan gagal dipakai. Diabaikan sampai kamera membaca kode
  /// lain, supaya pesan galatnya tidak berputar terus di layar.
  String? _kodeGagal;

  /// Hasil sudah diserahkan ke layar pemanggil; layar ini sedang menutup.
  ///
  /// Kamera tidak langsung mati saat `Navigator.pop` dipanggil — ia baru
  /// dilepas setelah animasi penutupannya selesai. Selama itu deteksi yang
  /// sama terus berdatangan, dan karena penjaga "baca dua kali" sudah
  /// terpenuhi, setiap deteksi berikutnya memanggil `Navigator.pop` SEKALI
  /// LAGI. Yang tertutup saat itu bukan lagi layar ini, melainkan layar
  /// pemanggilnya. Gejalanya: menekan "Scan" di Tambah Produk, memindai satu
  /// barcode, lalu form-nya ikut tertutup dan kembali ke daftar produk tanpa
  /// barcode terisi.
  bool _selesai = false;

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
    //
    // detectionSpeed HARUS normal, bukan noDuplicates: penjaga "baca dua kali"
    // di [_onDetect] bergantung pada bacaan berulang.
    return MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.normal,
    );
  }

  Future<void> _start() async {
    final c = _controller;
    if (c == null) return;
    // `start()` kedua untuk controller yang sama akan gagal dan mematikan
    // kamera yang baru saja menyala. Itu bisa terjadi tanpa kesalahan pengguna:
    // dialog izin kamera membuat aplikasi ke latar, lalu penanganan "resumed"
    // memanggil method ini lagi selagi permintaan pertama masih berjalan.
    if (_sedangMulai == c) return;
    _sedangMulai = c;
    try {
      await c.start();
      if (!mounted || _controller != c) return;
      _mulaiJalan = DateTime.now();
      _kodeTerakhir = null;
      _berapaKali = 0;
      _kodeGagal = null;
      if (_error != null) setState(() => _error = null);
    } on MobileScannerException catch (e) {
      if (!mounted || _controller != c) return;
      setState(() => _error = e);
    } catch (e) {
      if (!mounted || _controller != c) return;
      setState(() {
        _error = MobileScannerException(
          errorCode: MobileScannerErrorCode.genericError,
          errorDetails: MobileScannerErrorDetails(message: '$e'),
        );
      });
    } finally {
      if (_sedangMulai == c) _sedangMulai = null;
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
      _mulaiJalan = null;
      _kodeTerakhir = null;
      _berapaKali = 0;
    });
    // Controller lama baru dilepas setelah frame baru terpasang, supaya
    // widget kamera lama tidak menyentuh controller yang sudah dibuang.
    WidgetsBinding.instance.addPostFrameCallback((_) => lama?.dispose());
    // Kamera baru dinyalakan SESUDAH widget barunya terpasang. Versi sebelumnya
    // memanggil `_start()` langsung dari sini, yaitu sebelum frame baru sempat
    // dibangun: controller baru menyala tanpa widget yang memakainya, dan di
    // sebagian perangkat itu gagal — sehingga tombol "Coba lagi" justru
    // mengulang galat yang sama.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kamera dilepas sistem saat aplikasi ke latar. Nyalakan lagi saat kembali
    // supaya pratinjau tidak membeku hitam.
    if (state == AppLifecycleState.resumed) {
      final c = _controller;
      if (c == null) return;
      if (c.value.isRunning) return;
      // Penjaga untuk controller yang sedang dinyalakan ada di dalam `_start()`
      // sendiri, supaya kedua jalur memakai aturan yang sama persis.
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
    // `_selesai` diperiksa paling awal: begitu hasilnya diserahkan, layar ini
    // sedang menutup dan tidak boleh lagi memproses apa pun. Lihat [_selesai].
    if (_isProcessing || _selesai || !mounted) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final rawValue = barcodes.first.rawValue;
    if (rawValue == null || rawValue.trim().isEmpty) return;
    final kode = rawValue.trim();

    // Barcode yang barusan gagal dipakai tidak dicoba lagi selama kamera masih
    // membacanya. Tanpa ini, kode yang sama akan lolos penjaga "baca dua kali"
    // berulang-ulang dan pesan galatnya berputar terus di layar.
    if (kode == _kodeGagal) return;

    // Penjaga pertama — jeda tenang. Lihat [_jedaTenang].
    final mulai = _mulaiJalan;
    if (mulai == null) return;
    if (DateTime.now().difference(mulai) < _jedaTenang) return;

    // Penjaga kedua — kode yang sama harus terbaca dua kali berturut-turut.
    if (kode == _kodeTerakhir) {
      _berapaKali++;
    } else {
      // Kandidat baru. `setState` hanya di sini, bukan tiap frame, supaya
      // keterangan di layar ikut menampilkan apa yang sedang terbaca tanpa
      // membangun ulang widget puluhan kali per detik.
      setState(() {
        _kodeTerakhir = kode;
        _berapaKali = 1;
      });
    }
    if (_berapaKali < _bacaanYakin) return;

    setState(() => _isProcessing = true);
    try {
      await _serahkan(kode);
    } catch (e) {
      // Dulu tidak ada penjaga di sini: satu galat apa pun — misalnya
      // pembacaan database — membuat layarnya diam saja sesudah barcode
      // terbaca, dan itu terbaca sebagai "scan tidak bisa". Sekarang galatnya
      // ditampilkan.
      if (mounted) {
        setState(() {
          _kodeGagal = kode;
          _kodeTerakhir = null;
          _berapaKali = 0;
        });
        _pesan('Gagal memakai barcode $kode: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Satu pintu untuk hasil kamera maupun ketikan manual.
  ///
  /// `_selesai` dinyalakan SEBELUM `Navigator.pop`, bukan sesudahnya: sesudah
  /// pop, kendali belum tentu kembali ke sini, dan sisa detik animasi penutupan
  /// sudah cukup untuk satu deteksi lagi yang memanggil pop kedua.
  Future<void> _serahkan(String kode) async {
    if (!mounted) return;

    // Mode isi form: kembalikan barcode apa adanya, tanpa cari produk.
    if (widget.rawMode) {
      _selesai = true;
      Navigator.pop(context, kode);
      return;
    }

    final product = await _repo.findByBarcode(kode);
    if (!mounted) return;
    if (product != null) {
      _selesai = true;
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
                // Kode yang sedang terbaca ditampilkan supaya pengguna melihat
                // apa yang dibaca kamera. Sebelumnya layar hanya diam lalu
                // menutup, sehingga tidak ada cara tahu barcodenya terbaca,
                // salah baca, atau tidak terbaca sama sekali.
                _isProcessing
                    ? 'Membaca...'
                    : _kodeTerakhir != null
                        ? 'Terbaca: $_kodeTerakhir'
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
