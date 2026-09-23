import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/services/update_service.dart';

/// Status pemeriksaan pembaruan aplikasi.
class UpdateState {
  /// Sedang memeriksa ke server.
  final bool memeriksa;

  /// Sudah pernah diperiksa pada sesi ini (berhasil maupun gagal).
  final bool sudahDiperiksa;

  /// Pembaruan yang tersedia.
  /// `null` berarti aplikasi sudah versi terbaru, atau pemeriksaan gagal
  /// (mis. tidak ada internet).
  final UpdateInfo? info;

  const UpdateState({
    this.memeriksa = false,
    this.sudahDiperiksa = false,
    this.info,
  });

  bool get adaPembaruan => info != null;
}

/// Mengelola pemeriksaan pembaruan.
///
/// Dipakai bersama oleh lencana notifikasi di pojok kanan atas dan tombol
/// "Cek Pembaruan" di layar Profil, supaya keduanya menampilkan hal yang sama
/// dan server tidak ditanya dua kali.
class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState());

  /// Periksa pembaruan. Hasilnya disimpan di [state], jadi pemanggilan
  /// berikutnya tidak menembak server lagi — kecuali [paksa] diisi true
  /// (dipakai tombol "Cek Pembaruan" yang memang ditekan pengguna).
  Future<UpdateInfo?> periksa({bool paksa = false}) async {
    if (state.memeriksa) return state.info;
    if (state.sudahDiperiksa && !paksa) return state.info;

    state = UpdateState(
      memeriksa: true,
      sudahDiperiksa: state.sudahDiperiksa,
      info: state.info,
    );

    final hasil = await UpdateService.instance.checkForUpdate();
    if (!mounted) return hasil;

    state = UpdateState(
      memeriksa: false,
      sudahDiperiksa: true,
      info: hasil,
    );
    return hasil;
  }
}

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
