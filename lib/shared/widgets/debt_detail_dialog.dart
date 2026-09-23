import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/debt_model.dart';
import '../../data/repositories/debt_repository.dart';
import 'shared_widgets.dart';

/// Dialog rincian satu catatan hutang/piutang.
///
/// Menjawab "ini piutang/utang siapa, barang apa saja, dan berapa sisanya" —
/// jadi satu kartu di halaman Hutang & Piutang, atau satu mutasi "Terima
/// piutang"/"Bayar hutang" di riwayat Kas, bisa diketuk dan langsung jelas
/// asalnya.
///
/// Sengaja dipakai bersama dua layar itu supaya tidak ada dua versi dialog
/// yang bisa saling menyimpang.
class DebtDetailDialog extends StatelessWidget {
  final DebtDetail detail;

  /// Nominal pembayaran yang baru saja dicatat — diisi hanya kalau dialog
  /// dibuka dari riwayat Kas. Kalau null, blok pembayaran tidak ditampilkan.
  final int? paidNow;

  /// Tanggal pembayaran (konteks Kas).
  final DateTime? paidAt;

  /// Catatan pembayaran (konteks Kas).
  final String? paymentNote;

  /// Judul dialog. Default mengikuti jenis catatannya.
  final String? title;

  const DebtDetailDialog({
    super.key,
    required this.detail,
    this.paidNow,
    this.paidAt,
    this.paymentNote,
    this.title,
  });

  bool get _piutang => detail.isPiutang;

  bool get _adaKonteksBayar => paidNow != null;

  String get _labelPihak => _piutang ? 'Pelanggan' : 'Supplier';

  int get _totalBarang =>
      detail.goods.fold(0, (total, barang) => total + barang.subtotal);

  /// Tampilkan dialog dengan rincian yang sudah dimuat lebih dulu.
  static Future<void> show(
    BuildContext context, {
    required DebtDetail detail,
    int? paidNow,
    DateTime? paidAt,
    String? paymentNote,
    String? title,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => DebtDetailDialog(
        detail: detail,
        paidNow: paidNow,
        paidAt: paidAt,
        paymentNote: paymentNote,
        title: title,
      ),
    );
  }

  /// Ambil rinciannya dari database dulu, baru tampilkan dialognya.
  ///
  /// Dipakai halaman Hutang & Piutang, yang hanya memegang [DebtModel] hasil
  /// daftar — daftar barangnya baru diambil saat kartunya diketuk.
  static Future<void> showById(
    BuildContext context,
    int debtId, {
    int? paidNow,
    DateTime? paidAt,
    String? paymentNote,
    String? title,
  }) async {
    final detail = await DebtRepository().getDetail(debtId);
    if (!context.mounted) return;

    if (detail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan tidak ditemukan. Coba muat ulang daftarnya.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await show(
      context,
      detail: detail,
      paidNow: paidNow,
      paidAt: paidAt,
      paymentNote: paymentNote,
      title: title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final telepon = (detail.partyPhone ?? '').trim();
    final catatanBayar = (paymentNote ?? '').trim();
    final accent = _piutang ? AppColors.successMid : AppColors.dangerMid;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _piutang
                  ? AppColors.successLight
                  : AppColors.dangerLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              _piutang ? Icons.south_west : Icons.north_east,
              color: accent,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title ?? (_piutang ? 'Rincian piutang' : 'Rincian hutang'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            barisRincian(_labelPihak, detail.partyName, tebal: true),
            barisRincian(
              'Jenis',
              _piutang ? 'Piutang pelanggan' : 'Hutang ke supplier',
            ),
            if (telepon.isNotEmpty) barisRincian('Telepon', telepon),
            if (detail.invoiceNumber.isNotEmpty)
              barisRincian('No. nota', detail.invoiceNumber),
            const Divider(height: 20),

            if (_adaKonteksBayar) ...[
              barisRincian(
                'Dibayar sekarang',
                Formatters.rupiah(paidNow!),
                tebal: true,
              ),
              if (paidAt != null)
                barisRincian('Tanggal bayar', Formatters.dateTime(paidAt!)),
              if (catatanBayar.isNotEmpty)
                barisRincian('Catatan', catatanBayar),
              const Divider(height: 20),
            ],

            barisRincian('Nilai awal', Formatters.rupiah(detail.amount)),
            barisRincian(
              'Sudah dibayar',
              Formatters.rupiah(detail.paidAmount),
            ),
            barisRincian(
              _piutang ? 'Sisa piutang' : 'Sisa hutang',
              Formatters.rupiah(detail.remaining),
              tebal: true,
            ),
            barisRincian('Status', detail.isLunas ? 'Lunas' : 'Belum lunas'),
            if (detail.dueDate != null)
              barisRincian('Jatuh tempo', Formatters.date(detail.dueDate!)),

            const Divider(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  _piutang ? 'Barang yang dibeli' : 'Barang terkait',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (detail.goods.isEmpty)
              const Text(
                'Tidak ada rincian barang untuk catatan ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              )
            else ...[
              ...detail.goods.map(_barisBarang),
              const Divider(height: 14),
              barisRincian(
                'Total barang (${detail.goods.length} item)',
                Formatters.rupiah(_totalBarang),
                tebal: true,
              ),
            ],

            if (detail.note != null && detail.note!.trim().isNotEmpty) ...[
              const Divider(height: 20),
              barisRincian('Catatan', detail.note!.trim()),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Tutup'),
        ),
      ],
    );
  }
}

/// Satu barang di dalam daftar rincian: nama, jumlah × harga, lalu subtotal.
Widget _barisBarang(DebtGoods barang) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                barang.name,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textMain,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${barang.quantity} × ${Formatters.rupiah(barang.price)}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Formatters.rupiah(barang.subtotal),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMain,
          ),
        ),
      ],
    ),
  );
}
