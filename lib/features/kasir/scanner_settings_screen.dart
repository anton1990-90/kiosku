import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/scanner_settings_model.dart';
import '../../providers/scanner_settings_provider.dart';
import '../../shared/services/barcode_wedge.dart';
import '../../shared/services/usb_scanner_service.dart';

/// Pengaturan pemindai barcode: Bluetooth, kabel USB, nirkabel, dan kamera.
///
/// Ada karena tiga hal yang tidak bisa ditebak dari luar:
///
///   * **Penanda akhir.** Sebagian scanner mengirim Enter, sebagian Tab, dan
///     sebagian tidak mengirim apa pun. Kalau aplikasi hanya menebak, alat yang
///     sehat terbaca sebagai "tidak berfungsi".
///   * **Kecepatan kirim.** Scanner murah bisa berjeda 150–250 ms antar
///     karakter. Kalau batasnya terlalu ketat, kodenya terpotong di tengah.
///   * **Panjang kode.** Barcode 1D hanya 8–30 karakter, tetapi kode 2D (QR,
///     Data Matrix, PDF417, Aztec) bisa ratusan karakter. Batas lama 64
///     karakter memotong kode 2D tanpa memberi tahu siapa pun.
///
/// Layar ini juga memuat **area uji**. Itu bagian terpentingnya: tanpa area uji,
/// semua pengaturan di atas hanya tebakan, dan setiap kali hasilnya tetap gagal
/// tidak ada cara mengetahui apakah alatnya tidak terpasang, penanda akhirnya
/// salah, atau kodenya memang terlalu panjang.
///
/// Semua perubahan langsung disimpan dan langsung berlaku; tidak ada tombol
/// Simpan. Alasannya sama dengan halaman Pengaturan Cetak: layar ini dipakai
/// sambil mencoba-coba.
class ScannerSettingsScreen extends ConsumerStatefulWidget {
  const ScannerSettingsScreen({super.key});

  @override
  ConsumerState<ScannerSettingsScreen> createState() =>
      _ScannerSettingsScreenState();
}

class _ScannerSettingsScreenState extends ConsumerState<ScannerSettingsScreen> {
  /// Fokus area uji.
  ///
  /// Area uji menangkap tombolnya sendiri supaya Tab tidak memindahkan fokus
  /// dan Enter tidak menekan tombol di layar — dua hal yang membuat pengujian
  /// scanner mustahil dilakukan.
  final FocusNode _fokusUji = FocusNode(debugLabel: 'uji-pemindai');

  final TextEditingController _awalanCtrl = TextEditingController();
  final TextEditingController _akhiranCtrl = TextEditingController();

  StreamSubscription<HasilPindai>? _langgananRincian;
  StreamSubscription<String>? _langgananTombol;

  /// Tombol-tombol terakhir, apa adanya.
  ///
  /// Inilah jawaban atas pertanyaan "scanner saya sebenarnya mengirim apa?" —
  /// pertanyaan yang tidak bisa dijawab oleh hasil scan, karena hasil hanya
  /// muncul kalau semuanya sudah cocok.
  final List<String> _jejak = [];

  HasilPindai? _terakhir;

  bool _kolomTerisi = false;

  List<UsbScannerDevice> _usb = const [];
  bool _usbDiperiksa = false;
  bool _usbTersedia = true;
  String? _usbGalat;

  @override
  void initState() {
    super.initState();

    _langgananRincian =
        BarcodeWedgeScanner.instance.rincian.listen(_terimaRincian);
    _langgananTombol =
        BarcodeWedgeScanner.instance.tombolMentah.listen(_terimaTombol);

    // Nilai tersimpan baru terlihat setelah pemuatan selesai; mengisi kolom
    // lebih awal akan menampilkan nilai bawaan yang sekejap kemudian berubah.
    ref.read(scannerSettingsProvider.notifier).siap().then((_) {
      if (mounted) _isiKolom();
    });

    _periksaUsb();
  }

  @override
  void dispose() {
    _langgananRincian?.cancel();
    _langgananTombol?.cancel();
    _fokusUji.dispose();
    _awalanCtrl.dispose();
    _akhiranCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  void _terimaRincian(HasilPindai hasil) {
    if (!mounted) return;
    setState(() => _terakhir = hasil);
  }

  void _terimaTombol(String tombol) {
    if (!mounted) return;
    setState(() {
      _jejak.add(tombol);
      // Batasi supaya kumpulan yang kacau (papan ketik tertahan) tidak
      // menghabiskan memori halaman ini.
      if (_jejak.length > 160) {
        _jejak.removeRange(0, _jejak.length - 160);
      }
    });
  }

  void _isiKolom() {
    if (_kolomTerisi) return;
    _kolomTerisi = true;
    final p = ref.read(scannerSettingsProvider);
    _awalanCtrl.text = p.awalanBuang;
    _akhiranCtrl.text = p.akhiranBuang;
  }

  Future<void> _ubah(ScannerSettings baru) async {
    await ref.read(scannerSettingsProvider.notifier).ubah(baru);
  }

  /// Ubah pengaturan yang mengubah cara kode dikumpulkan, lalu kosongkan uji.
  ///
  /// Sisa karakter dari percobaan sebelumnya sudah dikumpulkan dengan aturan
  /// lama; membiarkannya membuat hasil percobaan berikutnya menyesatkan.
  Future<void> _ubahDanBersihkan(ScannerSettings baru) async {
    _bersihkan();
    await _ubah(baru);
  }

  void _bersihkan() {
    ref.read(scannerSettingsProvider.notifier).bersihkan();
    setState(() {
      _jejak.clear();
      _terakhir = null;
    });
  }

  Future<void> _periksaUsb() async {
    final hasil = await UsbScanner.periksa();
    if (!mounted) return;
    setState(() {
      _usb = hasil.alat;
      _usbTersedia = hasil.tersedia;
      _usbGalat = hasil.galat;
      _usbDiperiksa = true;
    });
  }

  // ---------------------------------------------------------------------------
  // Tampilan
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pengaturan = ref.watch(scannerSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(title: const Text('Pemindai barcode')),
      body: Responsive.centered(
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _kartuStatus(pengaturan),
            const SizedBox(height: 18),
            _judul('Uji pemindai'),
            _kartuUji(pengaturan),
            const SizedBox(height: 18),
            _judul('Jenis alat'),
            _kartuJenis(pengaturan),
            const SizedBox(height: 10),
            _panduan(pengaturan.jenis),
            const SizedBox(height: 18),
            _judul('Pengaturan pembacaan'),
            _kartuBaca(pengaturan),
            const SizedBox(height: 18),
            _judul('Umpan balik'),
            _kartuUmpanBalik(pengaturan),
            if (pengaturan.jenis.lewatUsb) ...[
              const SizedBox(height: 18),
              _judul('Alat USB terdeteksi'),
              _kartuUsb(),
            ],
            const SizedBox(height: 18),
            _catatan(
              'Barcode 2D (QR, Data Matrix, PDF417, Aztec) didukung lewat '
              'kamera maupun lewat scanner 2D yang mengirim sebagai keyboard. '
              'Kalau kode 2D Anda lebih panjang dari batas di atas, naikkan '
              'panjang maksimum — kode yang terpotong tidak akan pernah cocok '
              'dengan data mana pun.',
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  // --- status ---------------------------------------------------------------

  Widget _kartuStatus(ScannerSettings p) {
    return _kartu(
      anak: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.aktif,
            activeColor: AppColors.primary,
            title: const Text(
              'Pemindai aktif',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            subtitle: Text(
              p.aktif
                  ? 'Menerima ketikan dari alat yang tampil sebagai keyboard.'
                  : 'Dimatikan — hasil scan tidak akan dibaca aplikasi.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            onChanged: (nilai) => _ubah(p.copyWith(aktif: nilai)),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                Icon(
                  p.aktif ? Icons.sensors : Icons.sensors_off,
                  size: 18,
                  color: p.aktif ? AppColors.success : AppColors.textTertiary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    p.aktif
                        ? 'Penanda: ${p.akhiran.label} · jeda '
                            '${p.jedaAntarKarakter} ms · '
                            '${p.panjangMinimum}–${p.panjangMaksimum} karakter'
                        : 'Penerima ketikan dimatikan',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- uji ------------------------------------------------------------------

  Widget _kartuUji(ScannerSettings p) {
    final terakhir = _terakhir;
    final jejak = _jejak.isEmpty ? '—' : _jejak.join();

    return _kartu(
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ketuk kotak di bawah, lalu pindai satu barcode.',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 4),
          _catatan(
            'Tombol yang dikirim alat akan muncul apa adanya, termasuk '
            '<Enter> dan <Tab>. Kalau kotak ini tetap kosong saat barcode '
            'dipindai, masalahnya ada di alat atau di pasangannya — bukan di '
            'aplikasi.',
          ),
          const SizedBox(height: 12),
          Focus(
            focusNode: _fokusUji,
            autofocus: true,
            onKeyEvent: (_, event) {
              // Diteruskan sendiri: karena di bawah ini mengembalikan
              // `handled`, event tidak akan sampai ke penerima global di atas
              // Navigator — dan scanner akan tampak mati justru di halaman
              // yang seharusnya mengujinya.
              if (event is KeyDownEvent) {
                BarcodeWedgeScanner.instance.teruskan(event);
              }
              return KeyEventResult.handled;
            },
            child: GestureDetector(
              onTap: () => _fokusUji.requestFocus(),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 86),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      jejak,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_jejak.length} tombol · sedang terkumpul '
                      '${BarcodeWedgeScanner.instance.terkumpul.length} karakter',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _hasilUji(terakhir, p),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _bersihkan,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Bersihkan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _fokusUji.requestFocus(),
                  icon: const Icon(Icons.center_focus_weak, size: 18),
                  label: const Text('Siapkan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hasilUji(HasilPindai? hasil, ScannerSettings p) {
    if (hasil == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.bgSoft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Belum ada kode terbaca.',
          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
        ),
      );
    }

    final diterima = hasil.diterima;
    final warna = diterima ? AppColors.success : AppColors.warning;
    final latar = diterima ? AppColors.successLight : AppColors.warningLight;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: warna.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                diterima ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                color: warna,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  diterima
                      ? 'Terbaca ${hasil.panjang} karakter · '
                          '${hasil.durasiMs} ms'
                      : (hasil.alasan ?? 'Ditolak'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: warna,
                  ),
                ),
              ),
            ],
          ),
          if (diterima) ...[
            const SizedBox(height: 8),
            SelectableText(
              hasil.kode,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'Isi mentah: ${hasil.mentah}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _saran(hasil, p),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Saran perbaikan untuk hasil yang ditolak.
  ///
  /// Sengaja menyebut angka yang sedang berlaku dan angka yang harus dituju,
  /// bukan "periksa pengaturan": pengguna tidak tahu pengaturan mana yang
  /// salah, dan tidak tahu seberapa jauh harus menggesernya.
  String _saran(HasilPindai hasil, ScannerSettings p) {
    final alasan = hasil.alasan ?? '';
    if (alasan.startsWith('Terlalu pendek')) {
      return 'Panjang minimum sekarang ${p.panjangMinimum}. Turunkan ke '
          '${hasil.panjang} atau kurang, lalu pindai ulang.';
    }
    if (alasan.startsWith('Terlalu panjang')) {
      return 'Panjang maksimum sekarang ${p.panjangMaksimum}. Naikkan ke '
          '${hasil.panjang} atau lebih.';
    }
    if (alasan.startsWith('Terlalu lambat')) {
      return 'Alat ini mengirim kode terlalu lambat untuk dikenali tanpa '
          'penanda akhir. Atur alatnya supaya mengirim Enter atau Tab (biasanya '
          'dengan memindai barcode pengaturan di buku manualnya), lalu pilih '
          'penanda itu di atas — jalur penanda akhir tidak terkena batas waktu.';
    }
    if (alasan.startsWith('Kosong')) {
      return 'Awalan/akhiran yang dibuang menghabiskan seluruh kode. '
          'Kosongkan kolom "Buang awalan" dan "Buang akhiran".';
    }
    return 'Pindai ulang setelah menyesuaikan pengaturan di bawah.';
  }

  // --- jenis alat -----------------------------------------------------------

  Widget _kartuJenis(ScannerSettings p) {
    return _kartu(
      anak: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final jenis in JenisPemindai.values)
            _pil(
              label: jenis.label,
              terpilih: p.jenis == jenis,
              onTap: () => _ubah(p.copyWith(jenis: jenis)),
            ),
        ],
      ),
    );
  }

  Widget _panduan(JenisPemindai jenis) {
    late final String judul;
    late final List<String> langkah;

    switch (jenis) {
      case JenisPemindai.bluetooth:
        judul = 'Scanner Bluetooth';
        langkah = const [
          'Pasangkan alat di Pengaturan Bluetooth Android, bukan di aplikasi '
              'ini. Setelah terpasang, alat langsung berlaku untuk semua '
              'aplikasi.',
          'Alat harus dalam mode HID (kadang disebut "keyboard" atau "HID '
              'mode"). Kalau alatnya masih mode SPP/serial, pindai barcode '
              '"HID" di buku manualnya.',
          'Kalau alat tidak muncul di daftar Bluetooth, tahan tombol '
              'pairing-nya 3–5 detik sampai lampunya berkedip cepat.',
        ];
        break;
      case JenisPemindai.usb:
        judul = 'Scanner kabel USB (OTG)';
        langkah = const [
          'Sambungkan lewat adaptor OTG. Alat akan tampil sebagai keyboard — '
              'tidak ada izin yang perlu diberikan.',
          'Kalau HP tidak bereaksi sama sekali, coba adaptor OTG lain: '
              'sebagian HP hanya mau menerima OTG dengan adaptor yang benar.',
          'Alat harus dalam mode HID. Mode COM/serial akan terdeteksi di '
              'kartu "Alat USB terdeteksi" tetapi tidak mengirim apa pun — '
              'pindai barcode "USB HID Keyboard" di buku manualnya.',
        ];
        break;
      case JenisPemindai.nirkabel:
        judul = 'Scanner nirkabel 2,4 GHz';
        langkah = const [
          'Colokkan dongle-nya lewat adaptor OTG. Dongle itulah yang menjadi '
              'keyboard bagi Android, bukan alatnya.',
          'Pasangkan alat ke dongle dengan menekan tombol pairing di keduanya '
              'sampai lampunya berhenti berkedip.',
          'Jarak jangkauan biasanya 10 meter tanpa sekat; kalau terpotong, '
              'dekatkan alat ke HP.',
        ];
        break;
      case JenisPemindai.kamera:
        judul = 'Kamera HP';
        langkah = const [
          'Kamera dipakai lewat tombol scan di layar Kasir dan di form produk. '
              'Barcode 1D maupun 2D terbaca.',
          'Arahkan kamera sampai bingkai penuh, lalu tahan sebentar — layar '
              'menunggu kode yang sama terbaca dua kali supaya tidak salah '
              'baca.',
          'Kalau kamera tidak mau menyala, periksa izin kamera di Pengaturan '
              'Android.',
        ];
        break;
    }

    return _kartu(
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            judul,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < langkah.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${i + 1}.',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      langkah[i],
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // --- pembacaan ------------------------------------------------------------

  Widget _kartuBaca(ScannerSettings p) {
    return _kartu(
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _label('Jeda antar karakter')),
              Text(
                '${p.jedaAntarKarakter} ms',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: p.jedaAntarKarakter.clamp(30, 500).toDouble(),
            min: 30,
            max: 500,
            divisions: 47,
            activeColor: AppColors.primary,
            label: '${p.jedaAntarKarakter} ms',
            onChanged: (nilai) => ref
                .read(scannerSettingsProvider.notifier)
                .ubahSementara(p.copyWith(jedaAntarKarakter: nilai.round())),
            // Disimpan sekali saat jari dilepas, bukan di setiap geseran.
            onChangeEnd: (_) => _ubah(ref.read(scannerSettingsProvider)),
          ),
          _catatan(_keteranganJeda(p.jedaAntarKarakter)),
          const Divider(height: 22, color: AppColors.border),
          _label('Penanda akhir'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final akhiran in AkhiranPindai.values)
                _pil(
                  label: akhiran.label,
                  terpilih: p.akhiran == akhiran,
                  onTap: () => _ubahDanBersihkan(p.copyWith(akhiran: akhiran)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          _catatan(
            p.akhiran == AkhiranPindai.tanpa
                ? 'Tanpa penanda: kode dianggap selesai setelah alat berhenti '
                    'mengirim. Paling tidak yakin, jadi kode harus lebih '
                    'panjang dan sangat rapat.'
                : 'Kalau scanner Anda tidak mengirim Enter maupun Tab, pilih '
                    '"Tanpa penanda".',
          ),
          const Divider(height: 22, color: AppColors.border),
          _pengaturAngka(
            judul: 'Panjang minimum',
            satuan: 'Kode lebih pendek dari ini diabaikan.',
            nilai: p.panjangMinimum,
            bawah: 1,
            atas: 24,
            langkah: 1,
            onUbah: (nilai) => _ubahDanBersihkan(
              p.copyWith(panjangMinimum: nilai),
            ),
          ),
          const SizedBox(height: 8),
          _pengaturAngka(
            judul: 'Panjang maksimum',
            satuan: 'Untuk kode 2D, naikkan sampai 256 atau 512.',
            nilai: p.panjangMaksimum,
            bawah: 16,
            atas: 512,
            langkah: 16,
            onUbah: (nilai) => _ubahDanBersihkan(
              p.copyWith(panjangMaksimum: nilai),
            ),
          ),
          const Divider(height: 22, color: AppColors.border),
          _label('Buang awalan & akhiran'),
          const SizedBox(height: 4),
          _catatan(
            'Sebagian alat menambahkan penanda di depan atau belakang kode, '
            'mis. ]C1 untuk Code 128. Isi hanya kalau kode hasil uji di atas '
            'memang berawalan/berakhiran begitu.',
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _awalanCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Awalan',
                    hintText: 'mis. ]C1',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (teks) =>
                      _ubah(p.copyWith(awalanBuang: teks)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _akhiranCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Akhiran',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (teks) =>
                      _ubah(p.copyWith(akhiranBuang: teks)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _keteranganJeda(int jeda) {
    if (jeda <= 60) {
      return 'Sangat cepat. Hanya untuk scanner yang mengirim hampir tanpa '
          'jeda; scanner lambat akan terpotong di tengah.';
    }
    if (jeda <= 150) {
      return 'Normal. Cocok untuk sebagian besar scanner Bluetooth maupun USB.';
    }
    if (jeda <= 300) {
      return 'Longgar. Pakai kalau kode hasil uji terpotong di tengah.';
    }
    return 'Sangat longgar. Ketikan tangan yang cepat bisa ikut terbaca '
        'sebagai hasil scan — pakai hanya kalau scanner Anda memang lambat.';
  }

  // --- umpan balik ----------------------------------------------------------

  Widget _kartuUmpanBalik(ScannerSettings p) {
    return _kartu(
      anak: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.getar,
            activeColor: AppColors.primary,
            title: const Text(
              'Getar saat kode terbaca',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            subtitle: const Text(
              'Kasir tidak perlu menoleh ke layar untuk tahu kodenya masuk.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            onChanged: (nilai) => _ubah(p.copyWith(getar: nilai)),
          ),
          const Divider(height: 1, color: AppColors.border),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.bunyi,
            activeColor: AppColors.primary,
            title: const Text(
              'Bunyi klik saat kode terbaca',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
            subtitle: const Text(
              'Berguna di tempat ramai, tetapi ikut berbunyi untuk scan yang '
              'salah baca.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            onChanged: (nilai) => _ubah(p.copyWith(bunyi: nilai)),
          ),
        ],
      ),
    );
  }

  // --- USB ------------------------------------------------------------------

  Widget _kartuUsb() {
    if (!_usbDiperiksa) {
      return _kartu(
        anak: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Memeriksa colokan USB...',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (!_usbTersedia) {
      return _kartu(
        anak: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pemeriksaan USB tidak tersedia di perangkat ini.',
              style: TextStyle(fontSize: 13, color: AppColors.textMain),
            ),
            const SizedBox(height: 4),
            _catatan(
              _usbGalat ??
                  'Scanner USB tetap bisa dipakai — pemeriksaan ini hanya '
                      'menampilkan alat apa yang tercolok.',
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _periksaUsb,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Periksa lagi'),
            ),
          ],
        ),
      );
    }

    final hid = _usb.where((a) => a.hid).toList();
    final com = _usb.where((a) => a.modeCom).toList();

    return _kartu(
      anak: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_usb.isEmpty)
            const Text(
              'Tidak ada alat USB terdeteksi.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            )
          else if (hid.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${hid.length} alat keyboard (HID) terdeteksi — siap '
                    'dipakai.',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
            )
          else if (com.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.warning_amber_outlined,
                    size: 18, color: AppColors.warning),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Alat terdeteksi, tetapi dalam mode COM/serial — bukan '
                    'keyboard.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warningMid,
                    ),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Alat USB terdeteksi, tetapi bukan keyboard.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMain,
              ),
            ),
          const SizedBox(height: 8),
          for (final alat in _usb)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(
                    alat.hid ? Icons.keyboard : Icons.usb,
                    size: 16,
                    color: alat.hid
                        ? AppColors.textSecondary
                        : AppColors.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${alat.judul} · ${alat.kelas.toLowerCase()} · '
                      '${alat.vendorId.toRadixString(16)}:'
                      '${alat.productId.toRadixString(16)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (com.isNotEmpty) ...[
            const SizedBox(height: 4),
            _catatan(
              'Alat mode COM tidak akan pernah mengirim hasil scan ke '
              'aplikasi. Pindai barcode "USB HID Keyboard" di buku manual '
              'alat untuk mengubah modenya, lalu cabut dan colok ulang.',
            ),
          ],
          if (_usb.isEmpty) ...[
            const SizedBox(height: 4),
            _catatan(
              'Colokkan scanner lewat adaptor OTG. Kalau tetap tidak '
              'terdeteksi, adaptornya kemungkinan tidak didukung HP ini.',
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _periksaUsb,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Periksa lagi'),
          ),
        ],
      ),
    );
  }

  // --- bagian kecil ---------------------------------------------------------

  Widget _judul(String teks) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
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

  Widget _label(String teks) {
    return Text(
      teks,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
    );
  }

  Widget _catatan(String teks) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        teks,
        style: const TextStyle(
          fontSize: 11,
          height: 1.4,
          color: AppColors.textTertiary,
        ),
      ),
    );
  }

  Widget _kartu({required Widget anak}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: anak,
    );
  }

  Widget _pil({
    required String label,
    required bool terpilih,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: terpilih ? AppColors.primaryLight : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: terpilih ? AppColors.primary : AppColors.border,
            width: terpilih ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: terpilih ? AppColors.primaryDark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _pengaturAngka({
    required String judul,
    required String satuan,
    required int nilai,
    required int bawah,
    required int atas,
    required int langkah,
    required ValueChanged<int> onUbah,
  }) {
    int turun() {
      final hasil = nilai - langkah;
      return hasil < bawah ? bawah : hasil;
    }

    int naik() {
      final hasil = nilai + langkah;
      return hasil > atas ? atas : hasil;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(judul),
              const SizedBox(height: 2),
              Text(
                satuan,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: nilai <= bawah ? null : () => onUbah(turun()),
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.primary,
          iconSize: 22,
        ),
        SizedBox(
          width: 42,
          child: Text(
            '$nilai',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
        ),
        IconButton(
          onPressed: nilai >= atas ? null : () => onUbah(naik()),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
          iconSize: 22,
        ),
      ],
    );
  }
}
