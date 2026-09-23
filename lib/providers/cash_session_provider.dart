import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/cash_model.dart';
import '../data/models/cash_session_model.dart';
import '../data/repositories/cash_repository.dart';
import '../data/repositories/cash_session_repository.dart';

/// State sesi kas — sesi yang sedang berjalan, ringkasannya, dan riwayat
/// hitung uang.
class CashSessionState {
  /// Sesi yang sedang terbuka, `null` kalau laci belum dibuka.
  final CashSessionModel? sesiAktif;

  /// Sesi yang sudah ditutup, terbaru dulu.
  final List<CashSessionModel> riwayat;

  /// Uang masuk & keluar selama sesi yang sedang berjalan.
  final CashSummary ringkasan;

  /// Saldo kas sistem saat ini — "seharusnya ada di laci".
  final int saldoSistem;

  /// Jumlah nota yang tercatat dalam sesi yang sedang berjalan.
  final int notaSesi;

  final bool isLoading;

  const CashSessionState({
    this.sesiAktif,
    this.riwayat = const [],
    this.ringkasan = const CashSummary(),
    this.saldoSistem = 0,
    this.notaSesi = 0,
    this.isLoading = true,
  });

  bool get adaSesiTerbuka => sesiAktif != null;

  /// Perkiraan selisih kalau sesi ditutup dengan [uangFisik].
  ///
  /// Dipakai layar tutup kasir untuk menunjukkan lebih/kurang **sebelum**
  /// kasir menekan tombol simpan — supaya angka mengejutkan tidak baru
  /// muncul setelah datanya tersimpan.
  int selisihTerhadap(int uangFisik) => uangFisik - saldoSistem;
}

/// Notifier sesi kas.
class CashSessionNotifier extends StateNotifier<CashSessionState> {
  final CashSessionRepository _repo = CashSessionRepository();
  final CashRepository _cash = CashRepository();

  CashSessionNotifier() : super(const CashSessionState()) {
    muat();
  }

  /// Baca ulang semuanya dari database.
  ///
  /// Selalu menyusun state baru, bukan menyalin sebagian: nilai `sesiAktif`
  /// bisa berubah dari ada menjadi tidak ada (sesi ditutup), dan pola
  /// `copyWith` dengan `?? nilaiLama` tidak bisa mengosongkan kolom nullable.
  Future<void> muat() async {
    state = CashSessionState(
      sesiAktif: state.sesiAktif,
      riwayat: state.riwayat,
      ringkasan: state.ringkasan,
      saldoSistem: state.saldoSistem,
      notaSesi: state.notaSesi,
      isLoading: true,
    );

    final sesi = await _repo.sesiAktif();
    final saldo = await _cash.getSaldo();
    final riwayat = await _repo.riwayat();

    var ringkasan = const CashSummary();
    var nota = 0;
    if (sesi != null) {
      ringkasan = await _repo.ringkasanSesi(sesi);
      final id = sesi.id;
      if (id != null) {
        nota = (await _repo.penjualanSesi(id)).nota;
      }
    }

    state = CashSessionState(
      sesiAktif: sesi,
      riwayat: riwayat,
      ringkasan: ringkasan,
      saldoSistem: saldo,
      notaSesi: nota,
      isLoading: false,
    );
  }

  /// Buka sesi kas baru. Ditolak kalau masih ada sesi yang terbuka.
  Future<void> buka({String? oleh}) async {
    await _repo.bukaSesi(oleh: oleh);
    await muat();
  }

  /// Tutup sesi: simpan uang fisik yang dihitung dan selisihnya.
  Future<void> tutup({
    required int uangFisik,
    String? oleh,
    String? catatan,
  }) async {
    final id = state.sesiAktif?.id;
    if (id == null) {
      throw Exception('Tidak ada sesi kas yang terbuka.');
    }
    await _repo.tutupSesi(
      id: id,
      uangFisik: uangFisik,
      oleh: oleh,
      catatan: catatan,
    );
    await muat();
  }
}

final cashSessionProvider =
    StateNotifierProvider<CashSessionNotifier, CashSessionState>((ref) {
  return CashSessionNotifier();
});
