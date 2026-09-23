import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/report_period.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/accounting_models.dart';
import '../../data/repositories/accounting_repository.dart';
import '../../data/repositories/sale_repository.dart';
import '../../providers/auth_provider.dart';
import '../../shared/services/receipt_printer.dart';

/// Daftar transaksi penjualan beserta rinciannya.
///
/// Dibuka dari beranda lewat kartu "Transaksi hari ini". Periodenya bisa
/// diganti ke mingguan atau bulanan untuk menelusuri transaksi lama.
class TransaksiScreen extends ConsumerStatefulWidget {
  const TransaksiScreen({super.key});

  @override
  ConsumerState<TransaksiScreen> createState() => _TransaksiScreenState();
}

class _TransaksiScreenState extends ConsumerState<TransaksiScreen> {
  final _repo = AccountingRepository();

  ReportPeriod _period = ReportPeriod.today();
  List<SaleWithItems> _data = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    final data = await _repo.getSalesWithItems(_period.start, _period.end);
    if (!mounted) return;
    setState(() {
      _data = data;
      _loading = false;
    });
  }

  Future<void> _gantiPeriode(ReportPeriod periode) async {
    setState(() => _period = periode);
    await _muat();
  }

  /// Cetak ulang struk untuk satu transaksi lama.
  ///
  /// Struk aslinya hanya bisa dicetak sekali, di layar kasir. Kalau kertas
  /// habis, printer mati, atau pelanggan minta salinan, transaksi lama harus
  /// tetap bisa dicetak dari sini.
  Future<void> _cetakUlangStruk(SaleWithItems trx) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sesi tidak ditemukan, silakan masuk ulang'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Riwayat hanya menyimpan ringkasan, jadi penjualan dan baris barangnya
    // diambil ulang dari database sebelum disusun menjadi struk.
    final repo = SaleRepository();
    final sale = await repo.getSaleById(trx.saleId);
    if (!mounted) return;
    if (sale == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi tidak ditemukan'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final items = await repo.getSaleItems(trx.saleId);
    if (!mounted) return;

    // Mencetak struk untuk transaksi yang sudah dibatalkan akan menyesatkan
    // pelanggan: kertasnya terlihat seperti bukti jual-beli yang sah.
    if (sale.dibatalkan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaksi ini sudah dibatalkan, struknya tidak dicetak'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await cetakStruk(
      context: context,
      sale: sale,
      items: items,
      user: user,
    );
  }

  /// Batalkan satu transaksi: stok kembali, uang dikembalikan, piutang dihapus.
  ///
  /// Transaksinya tidak dihapus — ia hilang dari daftar ini dan dari seluruh
  /// laporan, tapi jejaknya tetap ada di Buku Kas dan Riwayat Stok. Dialog
  /// konfirmasinya menyebutkan hal itu supaya pemilik toko tahu ke mana harus
  /// mencari kalau nanti bertanya-tanya.
  Future<void> _batalkanTransaksi(SaleWithItems trx) async {
    final alasan = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogBatal(trx: trx),
    );
    if (alasan == null || !mounted) return;

    final hasil = await SaleRepository().batalkan(
      saleId: trx.saleId,
      reason: alasan.isEmpty ? null : alasan,
    );
    if (!mounted) return;

    if (hasil.berhasil) {
      await _muat();
      if (!mounted) return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hasil.berhasil
            ? '${hasil.pesan} · ${hasil.itemKembali} barang kembali ke stok'
                '${hasil.uangKeluar > 0 ? ' · ${Formatters.rupiah(hasil.uangKeluar)} keluar dari kas' : ''}'
            : hasil.pesan),
        backgroundColor: hasil.berhasil ? AppColors.success : AppColors.danger,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: hasil.berhasil ? 4 : 6),
      ),
    );
  }

  int get _totalPenjualan =>
      _data.fold(0, (s, t) => s + t.totalAmount);

  int get _totalLaba => _data.fold(0, (s, t) => s + t.totalProfit);

  int get _totalItem => _data.fold(0, (s, t) => s + t.totalItems);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Transaksi'),
        actions: [
          IconButton(
            tooltip: 'Muat ulang',
            onPressed: _muat,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _muat,
        child: Responsive.centered(
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            children: [
              _tabs(),
              const SizedBox(height: 12),
              _navigasi(),
              const SizedBox(height: 16),
              _ringkasan(),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_data.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 52, color: AppColors.textTertiary),
                      SizedBox(height: 12),
                      Text(
                        'Belum ada transaksi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Transaksi dari menu Kasir akan muncul di sini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._data.map(_kartuTransaksi),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabs() {
    const tabs = [
      (ReportPeriodType.harian, 'Harian'),
      (ReportPeriodType.mingguan, 'Mingguan'),
      (ReportPeriodType.bulanan, 'Bulanan'),
    ];

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bgSoft,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: tabs.map((t) {
          final isActive = _period.type == t.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => _gantiPeriode(_period.withType(t.$1)),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.bgCard : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _navigasi() {
    final canGoNext = _period.next() != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _gantiPeriode(_period.previous()),
            icon: const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              _period.label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext
                ? () => _gantiPeriode(_period.next()!)
                : null,
            icon: Icon(
              Icons.chevron_right,
              color: canGoNext ? AppColors.textSecondary : AppColors.border,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ringkasan() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total penjualan',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_totalPenjualan),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Laba kotor',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              Text(
                Formatters.rupiah(_totalLaba),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.successMid,
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: _angka('${_data.length}', 'Transaksi'),
              ),
              Expanded(
                child: _angka('$_totalItem', 'Barang terjual'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _angka(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  Widget _kartuTransaksi(SaleWithItems trx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trx.customerName ?? 'Pelanggan umum',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Formatters.dateWithDay(trx.createdAt)} · '
                      '${Formatters.time(trx.createdAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${trx.invoiceNumber} · ${trx.paymentMethod.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Formatters.rupiah(trx.totalAmount),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'laba ${Formatters.rupiahCompact(trx.totalProfit)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.successMid,
                    ),
                  ),
                  // Hanya muncul kalau transaksinya memang ada potongan.
                  if (trx.totalDiscount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'hemat ${Formatters.rupiahCompact(trx.totalDiscount)}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentMid,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          if (trx.isDebt) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.handshake_outlined,
                      size: 14, color: AppColors.warningMid),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Hutang · dibayar ${Formatters.rupiah(trx.paidAmount)} · '
                      'sisa ${Formatters.rupiah(trx.sisaBelumDibayar)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningMid,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 18),
          ...trx.lines.map(
            (l) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.productName,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMain,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${l.quantity} x ${Formatters.rupiahCompact(l.sellPrice)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 88,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Harga sebelum potongan baris — dicoret, supaya jelas
                        // kenapa angka di bawahnya lebih kecil dari qty x harga.
                        if (l.discount > 0)
                          Text(
                            Formatters.rupiahCompact(l.subtotal + l.discount),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textTertiary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        Text(
                          Formatters.rupiah(l.subtotal),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: l.discount > 0
                                ? AppColors.successMid
                                : AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _batalkanTransaksi(trx),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Batalkan'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () => _cetakUlangStruk(trx),
                icon: const Icon(Icons.print_outlined, size: 18),
                label: const Text('Cetak struk'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dialog konfirmasi pembatalan transaksi.
///
/// Mengembalikan alasan yang diketik (boleh kosong) kalau pemilik toko
/// menyetujui, dan `null` kalau tidak jadi. Karena alasan kosong tetap berarti
/// "ya", tombol setujunya mengirim string kosong — bukan `null`.
///
/// Isi dialognya sengaja menyebutkan akibatnya satu per satu, termasuk ke mana
/// jejaknya pergi. Pembatalan mengubah stok dan kas, jadi pemilik toko berhak
/// tahu persis apa yang akan terjadi sebelum menekan tombolnya.
class _DialogBatal extends StatefulWidget {
  final SaleWithItems trx;

  const _DialogBatal({required this.trx});

  @override
  State<_DialogBatal> createState() => _DialogBatalState();
}

class _DialogBatalState extends State<_DialogBatal> {
  final _alasan = TextEditingController();

  @override
  void dispose() {
    _alasan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trx = widget.trx;
    return AlertDialog(
      title: const Text('Batalkan transaksi?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${trx.invoiceNumber} · ${Formatters.rupiah(trx.totalAmount)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 12),
            _akibat('Stok ${trx.totalItems} barang dikembalikan'),
            if (trx.paidAmount > 0)
              _akibat('${Formatters.rupiah(trx.paidAmount)} keluar dari kas'),
            if (trx.isDebt)
              _akibat('Piutang dari transaksi ini dihapus'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Transaksinya tidak dihapus. Jejak pembatalannya tetap bisa '
                'dilihat di Buku Kas dan Riwayat Stok.',
                style: TextStyle(fontSize: 12, color: AppColors.infoMid),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _alasan,
              decoration: const InputDecoration(
                labelText: 'Alasan (boleh dikosongkan)',
                hintText: 'mis. salah input',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tidak jadi'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _alasan.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          child: const Text('Ya, batalkan'),
        ),
      ],
    );
  }

  Widget _akibat(String teks) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(fontSize: 13, color: AppColors.textMain),
            ),
          ),
        ],
      ),
    );
  }
}
