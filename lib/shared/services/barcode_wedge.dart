import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../data/models/scanner_settings_model.dart';

/// Hasil satu percobaan pembacaan.
///
/// Dipakai halaman Pengaturan Pemindai untuk memperlihatkan apa yang **benar**
/// diterima aplikasi. Tanpa ini, kegagalan scanner hanya terlihat sebagai
/// "tidak terjadi apa-apa", dan tidak ada cara membedakan alat yang tidak
/// terpasang, penanda akhir yang salah, dan kode yang terlalu panjang.
class HasilPindai {
  const HasilPindai({
    required this.kode,
    required this.mentah,
    required this.panjang,
    required this.durasi,
    required this.diterima,
    required this.waktu,
    this.alasan,
  });

  /// Kode setelah awalan/akhiran yang dikonfigurasi dibuang dan dipangkas.
  final String kode;

  /// Isi apa adanya dari alat, sebelum dibersihkan.
  final String mentah;

  /// Panjang [kode].
  final int panjang;

  /// Waktu dari karakter pertama sampai kumpulan ditutup.
  final Duration durasi;

  final bool diterima;

  /// Kenapa ditolak. `null` kalau [diterima].
  final String? alasan;

  final DateTime waktu;

  int get durasiMs => durasi.inMilliseconds;
}

/// Penyaring jeda untuk scanner barcode mode HID.
///
/// Scanner Bluetooth, scanner kabel USB (OTG), dan scanner nirkabel 2,4 GHz
/// **semuanya** bekerja dalam mode HID: ke Android ketiganya tampil sebagai
/// **keyboard fisik**. Alat itu "mengetik" isi barcode sangat cepat (biasanya
/// 5–30 ms antar karakter) lalu menutup dengan Enter atau Tab. Karena itu
/// aplikasi ini tidak memerlukan Bluetooth API maupun izin USB sama sekali.
///
/// `flutter_blue_plus` yang sudah dipakai untuk printer termal **tidak** bisa
/// dipakai di sini: pustaka itu BLE (Bluetooth Low Energy), sedangkan scanner
/// HID memakai Bluetooth Classic (BR/EDR). Layar "cari alat scanner" justru
/// desain yang salah — alatnya dipasangkan sekali di Pengaturan Bluetooth
/// Android (atau cukup dicolok untuk USB), lalu berlaku untuk aplikasi apa pun.
///
/// Yang membedakan scan dari ketikan manusia bukan isi tombolnya, melainkan
/// **jeda antar karakter**. Manusia mengetik dengan jeda ratusan milidetik;
/// scanner jauh lebih rapat. Kelas ini menyimpan jeda itu dan membuang
/// kumpulan karakter yang tersusun terlalu lambat, supaya angka yang diketik
/// manual tidak pernah ikut terbaca sebagai hasil scan.
///
/// Kelas ini murni perhitungan: tidak menyentuh stream, timer, maupun getaran.
/// Semua itu ada di [BarcodeWedgeScanner], supaya aturannya bisa diuji tanpa
/// menunggu waktu berjalan.
class BarcodeWedge {
  BarcodeWedge({ScannerSettings pengaturan = const ScannerSettings()})
      : _p = pengaturan;

  /// Batas keras penampungan, jauh di atas [ScannerSettings.panjangMaksimum].
  ///
  /// Ada supaya kumpulan yang kacau (mis. papan ketik yang tertahan) tidak
  /// tumbuh tanpa batas. Bedanya dengan [ScannerSettings.panjangMaksimum]:
  /// melewati batas ini **ditolak dengan alasan**, sedangkan melewati panjang
  /// maksimum juga ditolak — tidak ada pemotongan diam-diam di keduanya.
  /// Versi lama memotong di 64 karakter, dan kode QR yang lebih panjang dari
  /// itu diterima dalam keadaan terpotong sehingga tidak pernah cocok dengan
  /// data mana pun.
  static const int batasKeras = 1024;

  ScannerSettings _p;
  final StringBuffer _isi = StringBuffer();
  DateTime? _sebelumnya;
  DateTime? _mulai;
  bool _penuh = false;

  ScannerSettings get pengaturan => _p;

  /// Ganti pengaturan dan buang kumpulan yang sedang berjalan.
  ///
  /// Membuang kumpulan itu wajib: sisa karakter yang dikumpulkan dengan jeda
  /// lama akan dinilai dengan aturan baru, dan hasilnya kode gabungan yang
  /// tidak pernah ada.
  set pengaturan(ScannerSettings baru) {
    _p = baru;
    bersihkan();
  }

  /// Karakter yang sudah terkumpul sejauh ini.
  String get isi => _isi.toString();

  void bersihkan() {
    _isi.clear();
    _sebelumnya = null;
    _mulai = null;
    _penuh = false;
  }

  /// Masukkan satu karakter beserta waktu kedatangannya.
  ///
  /// Jeda yang lebih longgar daripada [ScannerSettings.jedaAntarKarakter]
  /// memutus kumpulan lebih dulu: itu bukan satu scan yang sedang berjalan,
  /// melainkan ketikan manusia.
  void masukkan(String karakter, DateTime sekarang) {
    if (!_p.aktif) return;

    final sebelum = _sebelumnya;
    if (sebelum != null &&
        sekarang.difference(sebelum).inMilliseconds > _p.jedaAntarKarakter) {
      bersihkan();
    }

    _mulai ??= sekarang;
    _sebelumnya = sekarang;

    if (karakter.length != 1) return;
    if (_isi.length >= batasKeras) {
      _penuh = true;
      return;
    }
    _isi.write(karakter);
  }

  /// Apakah tombol ini penanda akhir menurut pengaturan?
  ///
  /// [AkhiranPindai.tanpa] selalu `false` — di mode itu kumpulan hanya
  /// ditutup oleh jeda diam.
  bool penandaAkhir(LogicalKeyboardKey tombol) {
    final enter = tombol == LogicalKeyboardKey.enter ||
        tombol == LogicalKeyboardKey.numpadEnter;
    final tab = tombol == LogicalKeyboardKey.tab;

    switch (_p.akhiran) {
      case AkhiranPindai.enter:
        return enter;
      case AkhiranPindai.tab:
        return tab;
      case AkhiranPindai.keduanya:
        return enter || tab;
      case AkhiranPindai.tanpa:
        return false;
    }
  }

  /// Tutup kumpulan karena ada penanda akhir yang pasti.
  ///
  /// Mengembalikan `null` kalau tidak ada apa pun yang terkumpul — Enter yang
  /// datang sendiri bukan percobaan pembacaan.
  HasilPindai? tutup(DateTime sekarang) =>
      _selesaikan(sekarang, dariDiam: false);

  /// Tutup kumpulan karena tidak ada karakter baru selama beberapa lama.
  ///
  /// Dipakai untuk scanner yang tidak dikonfigurasi mengirim Enter, dan sebagai
  /// jaring pengaman kalau penanda akhir yang dipilih ternyata tidak dikirim
  /// alat. Syaratnya lebih ketat daripada [tutup], karena tanpa penanda akhir
  /// bukti bahwa ini hasil scan lebih lemah.
  HasilPindai? tutupKarenaDiam(DateTime sekarang) =>
      _selesaikan(sekarang, dariDiam: true);

  HasilPindai? _selesaikan(DateTime sekarang, {required bool dariDiam}) {
    final mentah = _isi.toString();
    final mulai = _mulai;
    final sebelumnya = _sebelumnya;
    final penuh = _penuh;

    // Durasi dihitung dari karakter PERTAMA sampai karakter TERAKHIR, bukan
    // sampai saat kumpulan ditutup. Selisihnya bukan detail: kumpulan yang
    // ditutup karena diam selalu dinilai 250 ms lebih lambat daripada
    // kenyataannya, dan dengan batas 300 ms itu berarti kode enam karakter
    // yang dikirim scanner dalam 150 ms tetap ditolak — persis gejala "scanner
    // tidak mengirim Enter jadi tidak pernah terbaca".
    final durasi = (mulai == null || sebelumnya == null || penuh)
        ? Duration.zero
        : sebelumnya.difference(mulai);

    // Kumpulan ini sudah selesai apa pun hasilnya, jadi jangan ditinggalkan
    // menggantung — kalau tidak, isinya bisa terbawa ke Enter berikutnya.
    bersihkan();

    // Enter atau Tab tanpa karakter di depannya bukan percobaan pembacaan.
    if (mentah.trim().isEmpty) return null;

    final kode = _rapikanKode(mentah);

    String? alasan;
    if (penuh) {
      alasan = 'Lebih dari $batasKeras karakter';
    } else if (kode.isEmpty) {
      alasan = 'Kosong setelah awalan/akhiran dibuang';
    } else if (kode.length < _panjangMinimum(dariDiam)) {
      alasan = 'Terlalu pendek: ${kode.length} karakter '
          '(minimum ${_panjangMinimum(dariDiam)})';
    } else if (kode.length > _p.panjangMaksimum) {
      alasan = 'Terlalu panjang: ${kode.length} karakter '
          '(maksimum ${_p.panjangMaksimum})';
    } else if (dariDiam && durasi > _durasiMaksimumDiam(kode.length)) {
      // Kumpulan yang tersusun lambat lebih mungkin ketikan manusia daripada
      // hasil scan. Batas ini sengaja TIDAK mengikuti jeda yang diatur
      // pengguna: kalau ikut, menaikkan jeda untuk scanner lambat justru
      // membuka pintu bagi ketikan tangan.
      alasan = 'Terlalu lambat: ${durasi.inMilliseconds} ms untuk '
          '${kode.length} karakter';
    }

    return HasilPindai(
      kode: kode,
      mentah: mentah,
      panjang: kode.length,
      durasi: durasi,
      diterima: alasan == null,
      alasan: alasan,
      waktu: sekarang,
    );
  }

  int _panjangMinimum(bool dariDiam) =>
      dariDiam ? _p.panjangMinimumDiam : _p.panjangMinimum;

  /// Batas waktu untuk kumpulan yang ditutup karena diam.
  ///
  /// Untuk kode pendek berlaku 400 ms; untuk kode panjang (2D, ratusan
  /// karakter) batasnya ikut memanjang, karena 400 ms mustahil untuk kode
  /// sepanjang itu sekalipun oleh scanner tercepat.
  ///
  /// Batas ini **tidak** mengikuti [ScannerSettings.jedaAntarKarakter]. Kalau
  /// ikut, menaikkan jeda untuk scanner lambat justru membuka pintu bagi
  /// ketikan tangan yang cepat — dan pada saat itu tidak ada lagi yang
  /// membedakan keduanya. Konsekuensinya disengaja: scanner yang sangat lambat
  /// **dan** tidak mengirim penanda akhir tidak bisa dibedakan dari ketikan
  /// manusia, jadi penyelesaiannya bukan menaikkan jeda, melainkan mengatur
  /// alatnya supaya mengirim Enter atau Tab.
  Duration _durasiMaksimumDiam(int panjang) {
    const dasar = Duration(milliseconds: 400);
    final skala = Duration(milliseconds: panjang * 80);
    return skala > dasar ? skala : dasar;
  }

  /// Buang awalan/akhiran yang dikonfigurasi, lalu pangkas spasi.
  String _rapikanKode(String mentah) {
    var kode = mentah;

    final awalan = _p.awalanBuang;
    if (awalan.isNotEmpty && kode.startsWith(awalan)) {
      kode = kode.substring(awalan.length);
    }

    final akhiran = _p.akhiranBuang;
    if (akhiran.isNotEmpty && kode.endsWith(akhiran)) {
      kode = kode.substring(0, kode.length - akhiran.length);
    }

    return kode.trim();
  }
}

/// Penerima scan untuk seluruh aplikasi.
///
/// Dipasang sekali di `app.dart` sebagai pembungkus `MaterialApp.router`, lalu
/// layar-layar yang butuh mendengarkan [hasil] di `initState` masing-masing.
class BarcodeWedgeScanner {
  BarcodeWedgeScanner._();

  /// Satu instance untuk seluruh aplikasi.
  static final BarcodeWedgeScanner instance = BarcodeWedgeScanner._();

  final BarcodeWedge _wedge = BarcodeWedge();

  /// Kode yang **diterima** — inilah yang didengarkan layar kasir dan form
  /// produk. Isinya sama seperti versi sebelumnya, jadi pemanggil lama tidak
  /// perlu berubah.
  final _pengendali = StreamController<String>.broadcast();

  /// Setiap percobaan pembacaan, diterima maupun ditolak, beserta alasannya.
  /// Dipakai halaman Pengaturan Pemindai.
  final _rincian = StreamController<HasilPindai>.broadcast();

  /// Nama tombol apa adanya, untuk diagnosa.
  ///
  /// Ini yang menjawab pertanyaan "scanner saya sebenarnya mengirim apa?" —
  /// pertanyaan yang tidak bisa dijawab dari [hasil] karena hasil hanya muncul
  /// kalau semuanya sudah cocok.
  final _tombol = StreamController<String>.broadcast();

  Timer? _jamDiam;

  ScannerSettings get pengaturan => _wedge.pengaturan;

  /// Aliran barcode yang selesai terbaca.
  ///
  /// Siarannya broadcast supaya beberapa layar boleh mendengarkan sekaligus;
  /// yang benar-benar bertindak hanya layar yang rutenya sedang tampil
  /// (dijaga `ModalRoute.of(context)?.isCurrent` di masing-masing layar).
  Stream<String> get hasil => _pengendali.stream;

  Stream<HasilPindai> get rincian => _rincian.stream;

  Stream<String> get tombolMentah => _tombol.stream;

  /// Karakter yang sedang terkumpul, untuk ditampilkan di halaman uji.
  String get terkumpul => _wedge.isi;

  /// Terapkan pengaturan baru.
  ///
  /// Dipanggil `main()` sebelum aplikasi tampil, lalu lagi setiap kali
  /// pengaturan diubah — jadi perubahan berlaku tanpa menutup aplikasi.
  void atur(ScannerSettings baru) {
    _batalkanJam();
    _wedge.pengaturan = baru;
  }

  /// Buang kumpulan yang sedang berjalan.
  void bersihkan() {
    _batalkanJam();
    _wedge.bersihkan();
  }

  /// Teruskan satu event ke penerima.
  ///
  /// Dipakai halaman uji yang menangkap tombolnya sendiri: layar itu
  /// mengembalikan `handled` supaya Tab tidak memindahkan fokus dan Enter tidak
  /// menekan tombol di layar, dan akibatnya event-nya tidak akan pernah sampai
  /// ke penerima global di atas Navigator. Tanpa jalur ini, menguji scanner di
  /// halaman pengaturan justru membuat scanner tampak mati.
  KeyEventResult teruskan(KeyEvent event) => dengar(event);

  /// Pasang ke `Focus.onKeyEvent` yang membungkus seluruh aplikasi.
  ///
  /// Selalu mengembalikan [KeyEventResult.ignored] supaya ketikannya tetap
  /// sampai ke kolom teks yang sedang difokuskan — penyaring ini menambah
  /// jalur, bukan menggantikannya.
  KeyEventResult dengar(KeyEvent event) {
    if (!_wedge.pengaturan.aktif) return KeyEventResult.ignored;

    // Hanya saat tombol ditekan: KeyUpEvent dan KeyRepeatEvent akan menggandakan
    // tiap karakter.
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Pintasan papan ketik (Ctrl/Alt/Meta) bukan hasil scan.
    final papan = HardwareKeyboard.instance;
    if (papan.isControlPressed || papan.isAltPressed || papan.isMetaPressed) {
      bersihkan();
      return KeyEventResult.ignored;
    }

    final tombol = event.logicalKey;

    // Escape membuang kumpulan yang sedang berjalan. Berguna saat scanner
    // salah membaca dan kasir ingin membatalkannya tanpa menunggu.
    if (tombol == LogicalKeyboardKey.escape) {
      bersihkan();
      return KeyEventResult.ignored;
    }

    // Penanda akhir diperiksa LEBIH DULU daripada karakter: karakter untuk
    // Enter adalah baris baru, jadi kalau urutannya terbalik, baris baru itu
    // ikut masuk ke dalam barcode.
    //
    // Penanda yang TIDAK dipilih pengaturan juga tidak boleh masuk ke kode:
    // menyimpan `\n` atau `\t` di dalam kode membuatnya tidak pernah cocok
    // dengan barcode mana pun, dan gejalanya persis "scan salah".
    final kandidatPenanda = tombol == LogicalKeyboardKey.enter ||
        tombol == LogicalKeyboardKey.numpadEnter ||
        tombol == LogicalKeyboardKey.tab;
    if (kandidatPenanda) {
      _catatTombol(tombol, null);
      if (_wedge.penandaAkhir(tombol)) {
        _batalkanJam();
        _selesaikan(_wedge.tutup(DateTime.now()));
      }
      return KeyEventResult.ignored;
    }

    final karakter = event.character;
    if (karakter == null || karakter.isEmpty) return KeyEventResult.ignored;

    _catatTombol(tombol, karakter);
    _wedge.masukkan(karakter, DateTime.now());
    _pasangJam();
    return KeyEventResult.ignored;
  }

  /// Kirim nama tombol ke aliran diagnosa — hanya kalau ada yang mendengarkan.
  ///
  /// Tanpa penjagaan `hasListener`, setiap ketukan tombol di seluruh aplikasi
  /// akan dibuatkan objek string yang langsung dibuang.
  void _catatTombol(LogicalKeyboardKey tombol, String? karakter) {
    if (!_tombol.hasListener) return;
    if (tombol == LogicalKeyboardKey.enter ||
        tombol == LogicalKeyboardKey.numpadEnter) {
      _tombol.add('<Enter>');
    } else if (tombol == LogicalKeyboardKey.tab) {
      _tombol.add('<Tab>');
    } else if (karakter != null && karakter.length == 1) {
      // `event.character` dipakai, bukan label tombol: itulah yang benar-benar
      // dikirim alat, termasuk kalau tata letak papan ketiknya bukan US.
      _tombol.add(karakter);
    }
  }

  void _selesaikan(HasilPindai? hasil) {
    if (hasil == null) return;
    _rincian.add(hasil);
    if (!hasil.diterima) return;
    _pengendali.add(hasil.kode);
    _umpanBalik();
  }

  /// Getaran/nada pendek sebagai tanda kode diterima.
  ///
  /// Keduanya memakai `flutter/services`, jadi tidak menambah paket maupun
  /// izin. Hasilnya sengaja tidak ditunggu dan galatnya dibuang dengan
  /// `ignore()`: getaran tidak tersedia di semua perangkat, dan umpan balik
  /// yang gagal tidak boleh menggagalkan pembacaan kode.
  void _umpanBalik() {
    final p = _wedge.pengaturan;
    if (p.getar) {
      HapticFeedback.mediumImpact().ignore();
    }
    if (p.bunyi) {
      SystemSound.play(SystemSoundType.click).ignore();
    }
  }

  void _pasangJam() {
    _batalkanJam();
    _jamDiam = Timer(_wedge.pengaturan.jedaDiam, _karenaDiam);
  }

  void _batalkanJam() {
    _jamDiam?.cancel();
    _jamDiam = null;
  }

  void _karenaDiam() {
    _jamDiam = null;
    _selesaikan(_wedge.tutupKarenaDiam(DateTime.now()));
  }
}
