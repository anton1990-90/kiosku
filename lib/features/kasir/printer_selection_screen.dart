import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../shared/services/bluetooth_printer_service.dart';

/// Layar pemilihan printer thermal Bluetooth.
///
/// Mengembalikan [PrinterDevice] yang sudah tersambung lewat `Navigator.pop`.
///
/// Urutannya sengaja begini:
///  1. periksa status Bluetooth dan izinnya (Android 12+ memakai izin runtime),
///  2. tampilkan printer yang **sudah dipasangkan** lebih dulu,
///  3. pindai printer baru sebagai pelengkap.
///
/// Printer thermal 58 mm seperti RPP02N memakai Bluetooth Classic SPP, bukan
/// BLE. Perangkat klasik tidak pernah muncul di pemindaian BLE, jadi daftar
/// "sudah dipasangkan" ditaruh paling atas: printer yang dipasangkan sekali di
/// Pengaturan Android akan selalu muncul di situ tanpa bergantung pada hasil
/// pemindaian.
class PrinterSelectionScreen extends StatefulWidget {
  const PrinterSelectionScreen({super.key});

  @override
  State<PrinterSelectionScreen> createState() => _PrinterSelectionScreenState();
}

class _PrinterSelectionScreenState extends State<PrinterSelectionScreen> {
  final BluetoothPrinterService _service = BluetoothPrinterService.instance;

  StatusPrinter? _status;
  List<PrinterDevice> _terpasang = const [];
  final Map<String, PrinterDevice> _ditemukan = <String, PrinterDevice>{};
  StreamSubscription<PrinterDevice>? _langganan;
  Timer? _timerPindai;
  bool _memindai = false;
  String? _galat;
  String? _sedangSambung;

  @override
  void initState() {
    super.initState();
    unawaited(_mulai());
  }

  @override
  void dispose() {
    _timerPindai?.cancel();
    _langganan?.cancel();
    // Pemindaian native harus dihentikan, kalau tidak BluetoothAdapter terus
    // memindai setelah layar ditutup dan baterai terkuras.
    unawaited(_service.hentikanPindaiKlasik());
    super.dispose();
  }

  Future<void> _mulai() async {
    final status = await _service.status();
    if (!mounted) return;
    setState(() => _status = status);

    if (!status.didukung) {
      setState(() => _galat = 'Perangkat ini tidak punya Bluetooth.');
      return;
    }

    if (!status.izin) {
      final diberi = await _service.mintaIzin();
      if (!mounted) return;
      if (!diberi) {
        setState(() {
          _galat = 'Izin Bluetooth ditolak. Buka Pengaturan > Aplikasi > TokoKu '
              '> Izin, lalu izinkan "Perangkat di sekitar".';
        });
        return;
      }
    }

    final terbaru = await _service.status();
    if (!mounted) return;
    setState(() => _status = terbaru);

    if (!terbaru.aktif) {
      setState(() {
        _galat = 'Bluetooth sedang mati. Nyalakan Bluetooth HP, lalu tekan '
            'Pindai Ulang.';
      });
      await _muatTerpasang();
      return;
    }

    await _muatTerpasang();
    await _pindai();
  }

  Future<void> _muatTerpasang() async {
    final daftar = await _service.printerTerpasang();
    if (!mounted) return;
    setState(() => _terpasang = daftar);
  }

  Future<void> _pindai() async {
    if (!mounted || _memindai) return;
    setState(() {
      _memindai = true;
      _ditemukan.clear();
    });

    await _langganan?.cancel();
    _langganan = _service.pindaiKlasik().listen(_tambah);

    final mulai = await _service.mulaiPindaiKlasik();
    if (!mounted) return;
    if (!mulai) {
      setState(() {
        _galat = 'Tidak bisa memindai. Pastikan Bluetooth menyala dan izin '
            'sudah diberikan.';
      });
    }

    // BLE dipindai bersamaan; hasilnya hanya pelengkap untuk printer BLE.
    unawaited(_pindaiBleLatar());

    _timerPindai?.cancel();
    _timerPindai = Timer(const Duration(seconds: 13), () {
      if (!mounted) return;
      setState(() => _memindai = false);
    });
  }

  Future<void> _pindaiBleLatar() async {
    final daftar = await _service.pindaiBle();
    if (!mounted) return;
    setState(() {
      for (final alat in daftar) {
        _ditemukan[alat.id] = alat;
      }
    });
  }

  void _tambah(PrinterDevice alat) {
    if (!mounted) return;
    setState(() => _ditemukan[alat.id] = alat);
  }

  Future<void> _pilih(PrinterDevice alat) async {
    if (_sedangSambung != null) return;

    // Printer klasik harus dipasangkan dulu. Tanpa itu, sambungan RFCOMM
    // langsung ditolak dan pesannya tidak bisa dimengerti pengguna.
    if (alat.jenis == JenisPrinter.klasik && !alat.terpasang) {
      final mulai = await _service.pasangkan(alat.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            mulai
                ? 'Setujui permintaan pasangan (PIN biasanya 0000 atau 1234), '
                    'lalu ketuk ${alat.label} sekali lagi.'
                : 'Gagal memulai pemasangan. Pasangkan printer lewat Pengaturan '
                    'Bluetooth Android, lalu tekan Pindai Ulang.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _muatTerpasang();
      return;
    }

    setState(() {
      _sedangSambung = alat.id;
      _galat = null;
    });

    try {
      await _service.sambung(alat);
      if (!mounted) return;
      Navigator.pop(context, alat);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sedangSambung = null;
        _galat = 'Gagal tersambung ke ${alat.label}: ${_pesan(e)}';
      });
    }
  }

  /// Pesan galat yang bisa dibaca kasir, bukan dump kelas Java.
  String _pesan(Object e) {
    if (e is PlatformException) {
      return e.message ?? e.code;
    }
    return e.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Pilih Printer')),
      body: Column(
        children: [
          _banner(),
          if (_galat != null) _kotakGalat(_galat!),
          Expanded(child: _isi(_status)),
          _tombolBawah(),
        ],
      ),
    );
  }

  Widget _banner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.infoMid, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nyalakan printer, lalu pilih dari daftar "sudah dipasangkan". '
              'Kalau belum ada, pindai lalu ketuk nama printer untuk '
              'memasangkannya.',
              style: TextStyle(fontSize: 13, color: AppColors.infoMid),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kotakGalat(String pesan) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        pesan,
        style: const TextStyle(fontSize: 13, color: AppColors.dangerMid),
      ),
    );
  }

  Widget _isi(StatusPrinter? status) {
    final baris = <Widget>[];

    if (status != null && !status.aktif) {
      baris.add(_catatan(
        'Bluetooth mati. Nyalakan Bluetooth HP, lalu tekan Pindai Ulang.',
      ));
    }

    baris.add(_judul('Printer sudah dipasangkan'));
    if (_terpasang.isEmpty) {
      baris.add(_catatan('Belum ada printer yang dipasangkan di HP ini.'));
    } else {
      for (final alat in _terpasang) {
        baris.add(_kartu(alat));
      }
    }

    final baru = _ditemukan.values
        .where((a) => !_terpasang.any((t) => t.id == a.id))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

    baris.add(_judul('Hasil pindai'));
    if (baru.isEmpty) {
      baris.add(_catatan(
        _memindai
            ? 'Mencari printer...'
            : 'Tidak ada printer baru. Printer yang sudah dipasangkan tetap '
                'bisa dipakai dari daftar di atas.',
      ));
    } else {
      for (final alat in baru) {
        baris.add(_kartu(alat));
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: baris,
    );
  }

  Widget _judul(String teks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _catatan(String teks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        teks,
        style: const TextStyle(fontSize: 13, color: AppColors.textTertiary),
      ),
    );
  }

  Widget _kartu(PrinterDevice alat) {
    final sedang = _sedangSambung == alat.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: _sedangSambung == null ? () => _pilih(alat) : null,
        tileColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.print, color: AppColors.primary, size: 20),
        ),
        title: Text(
          alat.label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textMain,
          ),
        ),
        subtitle: Text(
          _keterangan(alat),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        trailing: sedang
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      ),
    );
  }

  String _keterangan(PrinterDevice alat) {
    final jenis =
        alat.jenis == JenisPrinter.klasik ? 'Bluetooth Classic' : 'Bluetooth LE';
    final pasang = alat.terpasang ? 'sudah dipasangkan' : 'belum dipasangkan';
    return '$jenis - $pasang - ${alat.id}';
  }

  Widget _tombolBawah() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _memindai ? null : _pindai,
          icon: _memindai
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh),
          label: Text(_memindai ? 'Memindai...' : 'Pindai Ulang'),
        ),
      ),
    );
  }
}
