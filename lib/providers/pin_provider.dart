import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/auth_repository.dart';
import '../shared/services/pin_service.dart';

/// Status gerbang PIN aplikasi.
class PinState {
  /// Sedang membaca database — layar splash ditahan selama ini.
  final bool isLoading;

  /// Ada akun **aktif** yang memasang PIN.
  ///
  /// Sejak v1.20.0 PIN milik akun, jadi ini berarti "ada yang bisa masuk lewat
  /// PIN", bukan "perangkat ini punya PIN". Akun yang dinonaktifkan tidak
  /// dihitung — kalau dihitung, aplikasi bisa mengunci diri tanpa satu pun PIN
  /// yang bisa membukanya.
  final bool aktif;

  /// Aplikasi sedang menunggu PIN.
  final bool terkunci;

  const PinState({
    this.isLoading = true,
    this.aktif = false,
    this.terkunci = false,
  });

  /// Gerbang PIN hanya menahan kalau ada PIN DAN aplikasi sedang terkunci.
  bool get perluDibuka => aktif && terkunci;

  PinState salin({bool? isLoading, bool? aktif, bool? terkunci}) {
    return PinState(
      isLoading: isLoading ?? this.isLoading,
      aktif: aktif ?? this.aktif,
      terkunci: terkunci ?? this.terkunci,
    );
  }
}

/// Notifier gerbang PIN.
///
/// Sengaja TIDAK memakai `autoDispose`: kalau provider ini dibuang lalu dibuat
/// ulang, `_init()` akan berjalan lagi dan mengunci aplikasi di tengah
/// pemakaian. Terkunci hanya boleh terjadi sekali, saat aplikasi dibuka.
class PinNotifier extends StateNotifier<PinState> {
  PinNotifier(this._repo) : super(const PinState()) {
    _init();
  }

  final AuthRepository _repo;

  /// Saat aplikasi dibuka: pindahkan sisa PIN perangkat lama, lalu kunci kalau
  /// memang ada akun yang memasang PIN.
  ///
  /// Inilah yang membuat PIN ditanyakan **setiap kali aplikasi dibuka**,
  /// tanpa perlu memantau daur hidup aplikasi. Sesi yang tersimpan sengaja
  /// tidak dipercaya sampai PIN diketik: di HP yang dipakai bergantian, sesi
  /// yang tersisa dari kemarin bisa saja milik orang lain.
  Future<void> _init() async {
    await _pindahkanPinLama();

    final aktif = await _repo.adaAkunBerpin();
    state = PinState(isLoading: false, aktif: aktif, terkunci: aktif);
  }

  /// Pindahkan PIN perangkat versi lama (SharedPreferences) ke akun pemilik.
  ///
  /// Toko yang memperbarui aplikasi masih punya PIN terpasang, tetapi tidak ada
  /// akun yang mengenalinya — tanpa pemindahan ini mereka kehilangan jalan
  /// pintas hariannya. Dijalankan sebelum keadaan dibaca, dan aman diulang.
  Future<void> _pindahkanPinLama() async {
    final lama = await PinService.instance.hashLama();
    if (lama == null) return;

    // Database sudah punya PIN sendiri: PIN perangkat lama tidak berlaku lagi,
    // apa pun isinya. Dibuang supaya tidak dicoba ulang setiap aplikasi dibuka.
    if (await _repo.adaAkunBerpin()) {
      await PinService.instance.lupakanLama();
      return;
    }

    // Belum ada pemilik aktif (mis. semua akun dinonaktifkan): PIN lama
    // DIBIARKAN, karena toko itu masih membutuhkannya begitu pemiliknya
    // diaktifkan kembali.
    if (await _repo.adopsiPinPerangkat(lama)) {
      await PinService.instance.lupakanLama();
    }
  }

  /// Baca ulang keadaan PIN dari database.
  ///
  /// Dipakai layar Pengguna: menonaktifkan akun ber-PIN terakhir berarti tidak
  /// ada lagi yang bisa masuk lewat PIN, dan gerbangnya tidak boleh tetap
  /// menahan.
  Future<void> segarkan() async {
    final aktif = await _repo.adaAkunBerpin();
    state = state.salin(aktif: aktif);
  }

  /// Pasang atau ganti PIN sebuah akun.
  ///
  /// Mengembalikan pesan kesalahan, atau `null` kalau berhasil. Setelah
  /// dipasang, aplikasi tidak ikut terkunci — pemasangnya baru saja membuktikan
  /// bahwa dia berhak.
  Future<String?> pasang(int userId, String pin) async {
    try {
      await _repo.pasangPin(userId, pin);
    } catch (e) {
      return _pesan(e);
    }
    await segarkan();
    return null;
  }

  /// Hapus PIN sebuah akun.
  Future<void> hapus(int userId) async {
    await _repo.hapusPin(userId);
    await segarkan();
  }

  /// Buka gerbang setelah pengguna terbukti — lewat PIN, atau lewat email &
  /// kata sandi.
  ///
  /// Ini juga jalan keluar kalau PIN lupa: password lebih kuat daripada PIN,
  /// jadi siapa pun yang tahu passwordnya memang berhak masuk. PIN-nya sendiri
  /// TIDAK dihapus.
  void bukaSetelahLogin() {
    if (!state.aktif) return;
    state = const PinState(isLoading: false, aktif: true, terkunci: false);
  }

  /// Buka gerbang supaya pengguna bisa memakai email & kata sandi.
  ///
  /// Dipakai tombol "Lupa PIN?". Sesinya sudah diputus lebih dulu oleh
  /// pemanggil, jadi membuka gerbang TIDAK membuka aplikasi: yang terlihat
  /// hanya layar masuk, dan layar itu tetap menuntut email dan kata sandi.
  void bukaUntukMasukManual() {
    state = PinState(isLoading: false, aktif: state.aktif, terkunci: false);
  }

  /// Kunci sekarang juga — dipakai tombol "Ganti pengguna".
  ///
  /// Keadaannya dibaca ULANG dari database, bukan dari `state.aktif`: kalau
  /// akun ber-PIN terakhir baru saja dinonaktifkan, mengunci aplikasi di sini
  /// akan menutup satu-satunya jalan masuk.
  Future<void> kunciSekarang() async {
    final aktif = await _repo.adaAkunBerpin();
    state = PinState(isLoading: false, aktif: aktif, terkunci: aktif);
  }

  /// Pesan dari sebuah `Exception` tanpa awalan "Exception: " — pesan ini
  /// tampil apa adanya di layar, jadi awalannya hanya mengganggu.
  String _pesan(Object e) {
    final teks = e.toString();
    return teks.startsWith('Exception: ') ? teks.substring(11) : teks;
  }
}

final pinProvider = StateNotifierProvider<PinNotifier, PinState>((ref) {
  return PinNotifier(AuthRepository());
});
