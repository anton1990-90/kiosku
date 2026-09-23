import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/cash_session_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cash_session_provider.dart';
import '../../shared/widgets/shared_widgets.dart';

/// Layar Tutup Kasir — hitung uang fisik di laci, bandingkan dengan catatan
/// sistem, lalu simpan selisihnya.
///
/// Ritualnya dua langkah, dan urutannya penting:
///
///   1. **Buka sesi** saat mulai jaga. Saldo awal diambil otomatis dari saldo
///      sistem, bukan diketik — supaya aritmetikanya pasti.
///   2. **Tutup sesi** saat selesai. Kasir menghitung uang di laci dan
///      mengetikkan hasilnya; aplikasi menunjukkan selisihnya terhadap catatan
///      sistem, dan selisih itu disimpan bersama catatan kasir.
///
/// Selisih yang tidak nol **wajib disertai catatan**. Tanpa penjelasan, angka
/// "kurang Rp 20.000" tidak bisa ditindaklanjuti siapa pun — dan tuduhan
/// kurang uang tanpa penjelasan adalah hal yang paling merusak kepercayaan
/// antara pemilik toko dan kasirnya.
///
/// Layar ini bisa dibuka kasir maupun pemilik toko: yang menghitung uang di
/// laci adalah orang yang memegang lacinya.
class TutupKasirScreen extends ConsumerStatefulWidget {
  const TutupKasirScreen({super.key});

  @override
  ConsumerState<TutupKasirScreen> createState() => _TutupKasirScreenState();
}

class _TutupKasirScreenState extends ConsumerState<TutupKasirScreen> {
  final _uangFisik = TextEditingController();
  final _catatan = TextEditingController();
  bool _sibuk = false;

  @override
  void dispose() {
    _uangFisik.dispose();
    _catatan.dispose();
    super.dispose();
  }

  /// Uang fisik yang diketik, atau `null` kalau belum diisi.
  ///
  /// Titik dan spasi dibuang lebih dulu: orang mengetik "1.500.000" jauh lebih
  /// sering daripada "1500000", dan `int.tryParse` akan gagal pada yang
  /// pertama — kegagalan yang tampak seperti "aplikasi tidak menghitung".
  int? get _nilaiUangFisik {
    final angka = _uangFisik.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (angka.isEmpty) return null;
    return int.tryParse(angka);
  }

  String? get _emailPengguna => ref.read(authProvider).user?.email;

  void _pesan(String teks, {bool galat = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor: galat ? AppColors.danger : AppColors.primaryDark,
      ),
    );
  }

  Future<void> _bukaSesi() async {
    setState(() => _sibuk = true);
    try {
      await ref.read(cashSessionProvider.notifier).buka(oleh: _emailPengguna);
      _pesan('Sesi kas dibuka. Selamat bekerja.');
    } catch (e) {
      _pesan('$e'.replaceFirst('Exception: ', ''), galat: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _tutupSesi() async {
    final uangFisik = _nilaiUangFisik;
    if (uangFisik == null) {
      _pesan('Isi dulu jumlah uang fisik yang dihitung.', galat: true);
      return;
    }

    final selisih =
        ref.read(cashSessionProvider).selisihTerhadap(uangFisik);
    final catatan = _catatan.text.trim();
    if (selisih != 0 && catatan.isEmpty) {
      _pesan(
        'Uangnya tidak sama dengan catatan sistem. Tulis dulu '
        'penjelasannya di kolom catatan.',
        galat: true,
      );
      return;
    }

    setState(() => _sibuk = true);
    try {
      await ref.read(cashSessionProvider.notifier).tutup(
            uangFisik: uangFisik,
            oleh: _emailPengguna,
            catatan: catatan.isEmpty ? null : catatan,
          );
      _uangFisik.clear();
      _catatan.clear();
      _pesan(
        selisih == 0
            ? 'Sesi ditutup. Uang di laci cocok dengan catatan.'
            : 'Sesi ditutup. Selisih ${Formatters.rupiah(selisih.abs())} '
                'sudah tercatat.',
      );
    } catch (e) {
      _pesan('$e'.replaceFirst('Exception: ', ''), galat: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cashSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Tutup Kasir'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: () => ref.read(cashSessionProvider.notifier).muat(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.read(cashSessionProvider.notifier).muat(),
              child: Responsive.centered(
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                  children: [
                    if (state.adaSesiTerbuka)
                      ..._sesiBerjalan(state)
                    else
                      _belumDibuka(state),
                    const SizedBox(height: 24),
                    const SectionTitle(
                      title: 'Riwayat hitung uang',
                      subtitle: 'Sesi yang sudah ditutup, terbaru di atas',
                    ),
                    ..._riwayat(state),
                  ],
                ),
              ),
            ),
    );
  }

  // ------------------------------------------------------------ buka sesi

  List<Widget> _belumDibuka(CashSessionState state) {
    return [
      const SectionTitle(
        title: 'Laci belum dibuka',
        subtitle: 'Buka sesi dulu supaya hitungan uang nanti ada pembandingnya',
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _dekorasi(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sesi kas adalah satu giliran jaga: dari laci dibuka sampai '
              'uangnya dihitung. Tanpa sesi, selisih kas baru ketahuan '
              'berbulan-bulan kemudian dan tidak bisa lagi ditelusuri ke siapa.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            _baris('Saldo kas sistem sekarang',
                Formatters.rupiah(state.saldoSistem), tebal: true),
            const SizedBox(height: 4),
            const Text(
              'Angka ini dipakai sebagai saldo awal. Kalau uang di laci '
              'memang tidak sama dengan catatan sistem, selisihnya akan '
              'muncul saat sesi ditutup.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sibuk ? null : _bukaSesi,
                icon: const Icon(Icons.lock_open_outlined, size: 18),
                label: const Text('Buka sesi kas'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // -------------------------------------------------------- sesi berjalan

  List<Widget> _sesiBerjalan(CashSessionState state) {
    final sesi = state.sesiAktif!;
    final uangFisik = _nilaiUangFisik;
    final selisih = uangFisik == null ? null : state.selisihTerhadap(uangFisik);

    return [
      const SectionTitle(
        title: 'Sesi sedang berjalan',
        subtitle: 'Hitung uang di laci, lalu masukkan hasilnya di bawah',
      ),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _dekorasi(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _baris('Dibuka', Formatters.dateTime(sesi.openedAt)),
            if (sesi.openedBy != null && sesi.openedBy!.isNotEmpty)
              _baris('Dibuka oleh', sesi.openedBy!),
            _baris('Saldo awal', Formatters.rupiah(sesi.openingBalance)),
            _baris('Uang masuk', Formatters.rupiah(state.ringkasan.masuk)),
            _baris('Uang keluar', Formatters.rupiah(state.ringkasan.keluar)),
            _baris('Nota tercatat', '${state.notaSesi} transaksi'),
            const Divider(height: 22),
            _baris('Seharusnya di laci',
                Formatters.rupiah(state.saldoSistem), tebal: true),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _dekorasi(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _uangFisik,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Uang fisik di laci',
                helperText: 'Hitung uang yang benar-benar ada di laci.',
                prefixText: 'Rp ',
              ),
            ),
            if (selisih != null) ...[
              const SizedBox(height: 14),
              _kotakSelisih(selisih),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _catatan,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Catatan',
                helperText: selisih != null && selisih != 0
                    ? 'Wajib diisi: jelaskan kenapa uangnya berbeda.'
                    : 'Opsional — mis. uang kembalian yang tertinggal.',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sibuk ? null : _tutupSesi,
                icon: const Icon(Icons.lock_outline, size: 18),
                label: const Text('Tutup kasir & simpan'),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Kotak selisih — lebih / kurang / cocok.
  ///
  /// Ditampilkan sebelum kasir menekan simpan, supaya angka mengejutkan tidak
  /// baru muncul setelah datanya tersimpan dan tidak bisa diubah lagi.
  Widget _kotakSelisih(int selisih) {
    final cocok = selisih == 0;
    final warna = cocok
        ? AppColors.success
        : (selisih > 0 ? AppColors.warningMid : AppColors.danger);
    final latar = cocok
        ? AppColors.successLight
        : (selisih > 0 ? AppColors.warningLight : AppColors.dangerLight);
    final judul = cocok
        ? 'Uang di laci cocok dengan catatan'
        : (selisih > 0
            ? 'Uang di laci LEBIH ${Formatters.rupiah(selisih)}'
            : 'Uang di laci KURANG ${Formatters.rupiah(selisih.abs())}');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: latar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            cocok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: warna,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              judul,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: warna,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- riwayat

  List<Widget> _riwayat(CashSessionState state) {
    if (state.riwayat.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: _dekorasi(),
          child: const Column(
            children: [
              Icon(Icons.history_toggle_off,
                  size: 40, color: AppColors.textTertiary),
              SizedBox(height: 10),
              Text(
                'Belum ada sesi yang ditutup',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Setelah sesi pertama ditutup, riwayat hitung uang '
                'muncul di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      ];
    }

    return state.riwayat.map(_kartuRiwayat).toList();
  }

  Widget _kartuRiwayat(CashSessionModel sesi) {
    final selisih = sesi.difference ?? 0;
    final warna = selisih == 0
        ? AppColors.success
        : (selisih > 0 ? AppColors.warningMid : AppColors.danger);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _dekorasi(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  sesi.closedAt == null
                      ? Formatters.dateTime(sesi.openedAt)
                      : Formatters.dateTime(sesi.closedAt!),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: selisih == 0
                      ? AppColors.successLight
                      : (selisih > 0
                          ? AppColors.warningLight
                          : AppColors.dangerLight),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selisih == 0
                      ? 'Cocok'
                      : '${sesi.labelSelisih} ${Formatters.rupiah(selisih.abs())}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: warna,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _baris('Seharusnya', Formatters.rupiah(sesi.expectedClosing ?? 0)),
          _baris('Uang fisik', Formatters.rupiah(sesi.countedCash ?? 0)),
          if (sesi.closedBy != null && sesi.closedBy!.isNotEmpty)
            _baris('Ditutup oleh', sesi.closedBy!),
          if (sesi.note != null && sesi.note!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              sesi.note!,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                fontStyle: FontStyle.italic,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------- bantuan

  BoxDecoration _dekorasi() => BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      );

  Widget _baris(String label, String nilai, {bool tebal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: tebal ? AppColors.textMain : AppColors.textSecondary,
                fontWeight: tebal ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            nilai,
            style: TextStyle(
              fontSize: tebal ? 14 : 13,
              fontWeight: tebal ? FontWeight.w700 : FontWeight.w600,
              color: AppColors.textMain,
            ),
          ),
        ],
      ),
    );
  }
}
