import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/print_settings_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/print_settings_provider.dart';
import '../../shared/services/export_service.dart';
import '../../shared/services/receipt_printer.dart';
import '../../shared/services/receipt_service.dart';

/// Pratinjau struk — kertasnya ditampilkan lebih dulu, persis seperti hasil
/// cetak, sebelum kasir memutuskan mau mencetak atau mengirim ke pelanggan.
///
/// Susunan baris di sini **mengikuti** `ReceiptService.generateReceipt()`
/// baris per baris: logo, nama toko, alamat, telepon, garis pemisah, nomor
/// nota, daftar barang, potongan, total, cara bayar, sampai ucapan penutup.
/// Kalau struk termal diubah, layar ini harus ikut diubah — kalau tidak,
/// pratinjaunya berbohong dan kasir baru sadar setelah kertas tercetak.
///
/// Tiga tindakan tersedia:
/// * **Cetak Struk** — jalur cetak yang sama dengan kasir (`cetakStruk`),
///   jadi tidak ada logika cetak kedua yang bisa menyimpang.
/// * **Bagikan ke WA** — kertas struk ditangkap jadi gambar PNG lalu
///   dibagikan lewat menu bagikan Android (pilih WhatsApp). Teks struk ikut
///   disertakan supaya tetap terbaca walau gambarnya tidak terkirim.
/// * **Simpan** — gambar struk disimpan ke folder dokumen aplikasi.
class StrukPratinjauScreen extends ConsumerStatefulWidget {
  const StrukPratinjauScreen({
    super.key,
    required this.sale,
    required this.items,
    required this.user,
  });

  final SaleModel sale;
  final List<SaleItemModel> items;
  final UserModel user;

  @override
  ConsumerState<StrukPratinjauScreen> createState() =>
      _StrukPratinjauScreenState();
}

class _StrukPratinjauScreenState extends ConsumerState<StrukPratinjauScreen> {
  /// Kunci penanda kertas struk, dipakai saat menangkapnya menjadi gambar.
  final GlobalKey _kunciKertas = GlobalKey();

  /// Menahan ketukan ganda: menangkap gambar butuh waktu, dan dua ketukan
  /// cepat akan menghasilkan dua berkas serta dua menu bagikan.
  bool _sibuk = false;

  /// Ukuran huruf kertas pratinjau.
  ///
  /// Kertas 80 mm memuat 48 karakter per baris, bukan 32. Kalau hurufnya
  /// dibiarkan sama, baris pemisah 48 karakter melebihi lebar kertas di layar
  /// dan pratinjaunya jadi bergaris kuning — bukan lagi gambaran hasil cetak.
  double get _ukuranHuruf =>
      ref.read(printSettingsProvider).lebarKertas == 80 ? 7.8 : 10.5;

  /// Gaya huruf kertas struk.
  ///
  /// Monospace dipilih bukan karena bagus, tapi karena printer termal
  /// mencetak dengan huruf berlebar tetap — kolom harga di kanan baru
  /// sejajar kalau layarnya memakai huruf yang sama.
  TextStyle get _gaya => TextStyle(
        fontFamily: 'monospace',
        fontSize: _ukuranHuruf,
        height: 1.35,
        color: const Color(0xFF111111),
      );

  TextStyle get _gayaTebal => _gaya.copyWith(fontWeight: FontWeight.w700);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppColors.success, size: 22),
            SizedBox(width: 8),
            Text('Transaksi Berhasil'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Selesai'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                children: [
                  _kertasStruk(),
                  const SizedBox(height: 14),
                  const Text(
                    'Pratinjau struk — hasil cetak akan sama seperti ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _barisTombol(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Kertas struk
  // ---------------------------------------------------------------------------

  /// Kertas putih selebar kertas termal 58mm.
  ///
  /// [RepaintBoundary] membungkus seluruh isi kertas supaya bisa ditangkap
  /// menjadi satu gambar utuh — bukan potongan yang sedang terlihat di layar.
  Widget _kertasStruk() {
    final pengaturan = ref.read(printSettingsProvider);
    return RepaintBoundary(
      key: _kunciKertas,
      child: Container(
        width: 300,
        // Padding kanan mengikuti "jarak dari tepi kanan" di Pengaturan Cetak,
        // supaya pratinjau menunjukkan nominal yang tidak menempel di tepi.
        padding: EdgeInsets.fromLTRB(
          14,
          16,
          14 + pengaturan.marginKanan * _ukuranHuruf * 0.6,
          18,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _isiStruk(),
        ),
      ),
    );
  }

  /// Isi kertas, urut dari atas ke bawah seperti yang tercetak.
  List<Widget> _isiStruk() {
    final sale = widget.sale;
    final user = widget.user;
    // Pratinjau wajib memakai pengaturan yang sama dengan jalur cetak.
    final pengaturan = ref.watch(printSettingsProvider);
    final lebar = ReceiptService.lebarTeks(
      ReceiptService.karakterPerBaris(pengaturan.lebarKertas),
      pengaturan.marginKanan,
    );
    final baris = <Widget>[];

    // Logo usaha — paling atas, di tengah.
    final logo = (user.logoPath ?? '').trim();
    if (pengaturan.cetakLogo && logo.isNotEmpty && File(logo).existsSync()) {
      baris.add(
        Center(
          child: Image.file(
            File(logo),
            height: 56,
            fit: BoxFit.contain,
          ),
        ),
      );
      baris.add(const SizedBox(height: 6));
    }

    // Nama toko — dua kali lipat ukuran huruf lain, seperti di struk.
    baris.add(
      Text(
        user.storeName,
        textAlign: TextAlign.center,
        style: _gaya.copyWith(
          fontSize: _ukuranHuruf * 1.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final alamat = (user.storeAddress ?? '').trim();
    if (alamat.isNotEmpty) {
      baris.add(Text(alamat, textAlign: TextAlign.center, style: _gaya));
    }
    final telepon = (user.storePhone ?? '').trim();
    if (telepon.isNotEmpty) {
      baris.add(
        Text('Telp: $telepon', textAlign: TextAlign.center, style: _gaya),
      );
    }

    baris.add(_garis());
    baris.add(
      Text(
        'STRUK PENJUALAN',
        textAlign: TextAlign.center,
        style: _gayaTebal,
      ),
    );
    baris.add(_garis());

    // Nomor, tanggal, dan jam dicetak di baris terpisah — sama seperti struk
    // termal. Dulu ketiganya dipaksa satu baris, dan di kertas 58 mm jamnya
    // yang terpotong.
    baris.add(Text('No: ${sale.invoiceNumber}', style: _gaya));
    baris.add(Text('Tanggal: ${Formatters.date(sale.createdAt)}', style: _gaya));
    baris.add(Text('Jam: ${Formatters.time(sale.createdAt)}', style: _gaya));

    final pelanggan = (sale.customerName ?? '').trim();
    if (pelanggan.isNotEmpty) {
      baris.add(Text('Pelanggan: $pelanggan', style: _gaya));
    }

    baris.add(_garis());

    // Barang yang dibeli.
    for (final item in widget.items) {
      baris.add(
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(item.productName, style: _gaya),
        ),
      );
      baris.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${Formatters.jumlah(item.quantity)} ${item.unit} x '
                '${Formatters.rupiah(item.sellPrice)}',
                style: _gaya,
              ),
            ),
            Text(Formatters.rupiah(item.subtotal), style: _gaya),
          ],
        ),
      );
      // Potongan per barang hanya muncul kalau memang ada — struk biasa
      // tidak boleh bertambah panjang tanpa alasan.
      if (item.discount > 0) {
        baris.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: Text('  Potongan', style: _gaya)),
              Text('-${Formatters.rupiah(item.discount)}', style: _gaya),
            ],
          ),
        );
      }
    }

    baris.add(_garis());

    // Potongan seluruh nota, di luar potongan per baris di atas.
    if (sale.discount > 0) {
      baris.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text('Potongan nota', style: _gaya)),
            Text('-${Formatters.rupiah(sale.discount)}', style: _gaya),
          ],
        ),
      );
    }

    // Total — mengikuti gaya yang dipilih di Pengaturan Cetak. Gaya "angka
    // besar" menaruh label dan nominal di baris terpisah supaya nominalnya
    // tidak terpotong, persis seperti yang dicetak printer.
    if (pengaturan.gayaTotal == GayaTotal.besar) {
      baris.add(
        Text(
          'TOTAL',
          style: _gaya.copyWith(
            fontSize: _ukuranHuruf * 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      baris.add(
        Text(
          Formatters.rupiah(sale.totalAmount),
          textAlign: TextAlign.right,
          style: _gaya.copyWith(
            fontSize: _ukuranHuruf * 1.7,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    } else {
      baris.add(
        Text(
          ReceiptService.duaKolom(
            'TOTAL',
            Formatters.rupiah(sale.totalAmount),
            lebar,
          ),
          style: _gaya.copyWith(
            fontSize: _ukuranHuruf * 1.35,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }
    baris.add(Text('Tunai: ${Formatters.rupiah(sale.paidAmount)}', style: _gaya));
    baris.add(
      Text('Kembali: ${Formatters.rupiah(sale.changeAmount)}', style: _gaya),
    );
    baris.add(Text('Bayar: ${sale.paymentMethod.toUpperCase()}', style: _gaya));
    baris.add(Text('Item: ${Formatters.jumlah(sale.totalItems)}', style: _gaya));

    // Sisa piutang — pelanggan perlu tahu masih ada tanggungan.
    if (sale.isDebt && sale.unpaidAmount > 0) {
      baris.add(
        Text(
          'BELUM DIBAYAR: ${Formatters.rupiah(sale.unpaidAmount)}',
          style: _gayaTebal,
        ),
      );
    }

    baris.add(_garis());

    // Cara bayar non-tunai — sama seperti yang dicetak.
    final metode = sale.paymentMethod.toLowerCase();
    final qris = (user.qrisPath ?? '').trim();
    if (metode == 'qris' &&
        pengaturan.cetakQris &&
        qris.isNotEmpty &&
        File(qris).existsSync()) {
      baris.add(
        Text(
          'PEMBAYARAN QRIS',
          textAlign: TextAlign.center,
          style: _gayaTebal,
        ),
      );
      baris.add(const SizedBox(height: 4));
      baris.add(
        Center(
          child: Image.file(
            File(qris),
            height: 110,
            fit: BoxFit.contain,
          ),
        ),
      );
      baris.add(
        Text(
          'Scan QRIS di atas untuk membayar',
          textAlign: TextAlign.center,
          style: _gaya,
        ),
      );
      baris.add(_garis());
    }

    final nomorRek = (user.bankAccountNumber ?? '').trim();
    if (metode == 'transfer' && nomorRek.isNotEmpty) {
      baris.add(
        Text(
          'TRANSFER BANK',
          textAlign: TextAlign.center,
          style: _gayaTebal,
        ),
      );
      final bank = (user.bankName ?? '').trim();
      if (bank.isNotEmpty) {
        baris.add(Text('Bank    : $bank', style: _gaya));
      }
      baris.add(Text('No. rek : $nomorRek', style: _gaya));
      final pemilik = (user.bankAccountName ?? '').trim();
      if (pemilik.isNotEmpty) {
        baris.add(Text('a.n.    : $pemilik', style: _gaya));
      }
      baris.add(_garis());
    }

    baris.add(
      Text(
        ReceiptService.footerStruk(user.receiptFooter),
        textAlign: TextAlign.center,
        style: _gaya,
      ),
    );
    baris.add(
      Text(
        'Powered by TokoKu',
        textAlign: TextAlign.center,
        style: _gaya.copyWith(
          fontSize: _ukuranHuruf * 0.85,
          color: const Color(0xFF555555),
        ),
      ),
    );

    return baris;
  }

  /// Garis pemisah selebar kertas yang sedang dipakai (32 atau 48 karakter,
  /// dikurangi margin kanan).
  Widget _garis() {
    final pengaturan = ref.read(printSettingsProvider);
    final lebar = ReceiptService.lebarTeks(
      ReceiptService.karakterPerBaris(pengaturan.lebarKertas),
      pengaturan.marginKanan,
    );
    return Text(
      '-' * lebar,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: _ukuranHuruf,
        height: 1.2,
        color: const Color(0xFF111111),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tiga tindakan
  // ---------------------------------------------------------------------------

  Widget _barisTombol() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _sibuk ? null : _cetak,
                icon: const Icon(Icons.print, size: 20),
                label: const Text('Cetak Struk'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _sibuk ? null : _bagikan,
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Bagikan ke WA'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _sibuk ? null : _simpan,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Simpan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMain,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cetak ke printer termal Bluetooth.
  ///
  /// Memakai `cetakStruk()` — jalur yang sama dengan cetak ulang dari riwayat
  /// transaksi, jadi tidak ada dua versi logika cetak yang bisa menyimpang.
  Future<void> _cetak() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      await cetakStruk(
        context: context,
        sale: widget.sale,
        items: widget.items,
        user: widget.user,
      );
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Bagikan gambar struk lewat menu bagikan Android (pilih WhatsApp).
  Future<void> _bagikan() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      final berkas = await _tulisGambar();
      if (berkas == null) {
        _pesan('Gagal membuat gambar struk', gagal: true);
        return;
      }
      await ExportService.instance.share(
        berkas,
        subject: 'Struk ${widget.sale.invoiceNumber}',
        text: _teksStruk(),
      );
    } catch (e) {
      _pesan('Gagal membagikan struk: $e', gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Simpan gambar struk ke folder dokumen aplikasi.
  Future<void> _simpan() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      final berkas = await _tulisGambar();
      if (berkas == null) {
        _pesan('Gagal membuat gambar struk', gagal: true);
        return;
      }
      _pesan('Struk disimpan di ${berkas.path}');
    } catch (e) {
      _pesan('Gagal menyimpan struk: $e', gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Teks struk untuk pesan WhatsApp — dibuat oleh [ReceiptService] yang sama
  /// dengan versi cetak, supaya isinya tidak berbeda.
  String _teksStruk() {
    final user = widget.user;
    return ReceiptService.instance.generateTextReceipt(
      sale: widget.sale,
      items: widget.items,
      storeName: user.storeName,
      storeAddress: user.storeAddress,
      storePhone: user.storePhone,
      bankName: user.bankName,
      bankAccountNumber: user.bankAccountNumber,
      bankAccountName: user.bankAccountName,
      receiptFooter: user.receiptFooter,
    );
  }

  /// Tulis kertas struk menjadi berkas PNG, kembalikan `null` kalau gagal.
  Future<File?> _tulisGambar() async {
    final data = await _tangkapPng();
    if (data == null) return null;

    final basis = await getApplicationDocumentsDirectory();
    final folder = Directory('${basis.path}/struk');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final nama = ExportService.safeName('struk ${widget.sale.invoiceNumber}');
    final berkas = File('${folder.path}/$nama.png');
    await berkas.writeAsBytes(data, flush: true);
    return berkas;
  }

  /// Tangkap kertas struk menjadi PNG.
  ///
  /// `pixelRatio: 3` dipakai supaya tulisan tetap tajam saat gambarnya dibuka
  /// di layar HP pelanggan — bukan pecah seperti tangkapan layar biasa.
  Future<Uint8List?> _tangkapPng() async {
    final konteks = _kunciKertas.currentContext;
    if (konteks == null) return null;

    final objek = konteks.findRenderObject();
    if (objek is! RenderRepaintBoundary) return null;

    final gambar = await objek.toImage(pixelRatio: 3);
    try {
      final data = await gambar.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return data.buffer.asUint8List();
    } finally {
      gambar.dispose();
    }
  }

  void _pesan(String teks, {bool gagal = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(teks),
        backgroundColor: gagal ? AppColors.danger : AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
