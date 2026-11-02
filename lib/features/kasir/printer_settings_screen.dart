import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/print_settings_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/print_settings_provider.dart';
import '../../shared/services/bluetooth_printer_service.dart';
import '../../shared/services/print_settings_service.dart';
import '../../shared/services/receipt_service.dart';
import 'printer_selection_screen.dart';

/// Pengaturan cetak struk: ukuran kertas, isi struk, dan printer tersimpan.
///
/// Ada karena printer termal tidak seragam. Dua printer yang sama-sama disebut
/// "58 mm" bisa punya lebar cetak 32 atau 33 karakter, dan printer 80 mm ada
/// yang hanya mencetak 40 karakter. Kalau aplikasi menganggap semuanya sama,
/// hasilnya baris terpotong di kanan — nominal uang yang paling sering jadi
/// korban. Di layar ini pemilik memilih sendiri ukuran yang cocok, lalu
/// mencetak contoh struk untuk membuktikannya sebelum dipakai berjualan.
///
/// Semua perubahan langsung disimpan; tidak ada tombol Simpan.
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  /// Menahan ketukan ganda saat mencetak contoh.
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(printSettingsProvider.notifier).siap();
    });
  }

  // ---------------------------------------------------------------------------
  // Aksi
  // ---------------------------------------------------------------------------

  Future<void> _ubah(PrintSettings baru) async {
    await ref.read(printSettingsProvider.notifier).ubah(baru);
  }

  /// Cetak struk contoh berisi satu barang Rp 10.000 x 3 = Rp 30.000.
  ///
  /// Angka itu dipilih bukan sembarang: "Rp 30.000" adalah nominal yang dulu
  /// terpotong menjadi "Rp 30.0", jadi contoh ini sekaligus jadi bukti bahwa
  /// perbaikannya benar-benar sampai ke kertas.
  Future<void> _cetakContoh() async {
    if (_sibuk) return;
    final pengaturan = ref.read(printSettingsProvider);
    final user = ref.read(authProvider).user;
    setState(() => _sibuk = true);
    try {
      final printer = await Navigator.push<PrinterDevice>(
        context,
        MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
      );
      if (printer == null) return;

      final bytes = await ReceiptService.instance.generateReceipt(
        sale: _contohPenjualan(),
        items: _contohBarang(),
        storeName: user?.storeName ?? 'Toko Saya',
        storeAddress: user?.storeAddress,
        storePhone: user?.storePhone,
        logoPath: user?.logoPath,
        qrisPath: user?.qrisPath,
        bankName: user?.bankName,
        bankAccountNumber: user?.bankAccountNumber,
        bankAccountName: user?.bankAccountName,
        receiptFooter: user?.receiptFooter,
        paperWidth: pengaturan.lebarKertas,
        cetakLogo: pengaturan.cetakLogo,
        cetakQris: pengaturan.cetakQris,
        gayaTotal: pengaturan.gayaTotal,
        barisKosong: pengaturan.barisKosong,
        marginKanan: pengaturan.marginKanan,
      );
      await BluetoothPrinterService.instance.cetak(printer, bytes);
      await BluetoothPrinterService.instance.putus(printer);
      await PrintSettingsService.instance.simpanPrinter(printer);
      await ref.read(printSettingsProvider.notifier).muatUlang();
      _pesan('Contoh struk terkirim. Periksa hasilnya di kertas.');
    } catch (e) {
      _pesan('Gagal mencetak: ${_pesanGalat(e)}', gagal: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _lupakanPrinter() async {
    await ref.read(printSettingsProvider.notifier).lupakanPrinter();
    _pesan('Printer tersimpan dilupakan.');
  }

  SaleModel _contohPenjualan() {
    return SaleModel(
      invoiceNumber: 'CONTOH-001',
      userId: 0,
      totalAmount: 30000,
      totalProfit: 0,
      totalItems: 3.0,
      paymentMethod: 'tunai',
      paidAmount: 50000,
      changeAmount: 20000,
      createdAt: DateTime.now(),
    );
  }

  List<SaleItemModel> _contohBarang() {
    return [
      SaleItemModel(
        saleId: 0,
        productId: 1,
        productName: 'Contoh barang',
        costPrice: 0,
        sellPrice: 10000,
        quantity: 3.0,
        subtotal: 30000,
      ),
    ];
  }

  /// Pesan galat yang bisa dibaca, bukan dump kelas platform.
  String _pesanGalat(Object e) {
    if (e is PlatformException) {
      return e.message ?? e.code;
    }
    return e.toString();
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

  // ---------------------------------------------------------------------------
  // Tampilan
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final pengaturan = ref.watch(printSettingsProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      appBar: AppBar(
        title: const Text('Pengaturan Cetak'),
        backgroundColor: AppColors.bgCard,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          _judul('Ukuran kertas'),
          _kartu(
            anak: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _pilihanKertas(58, pengaturan)),
                    const SizedBox(width: 10),
                    Expanded(child: _pilihanKertas(80, pengaturan)),
                  ],
                ),
                const SizedBox(height: 10),
                _catatan(
                  'Pilih sesuai printer Anda. Kalau hasil cetak masih terpotong '
                  'di kanan, pakai 58 mm — sebagian printer "80 mm" hanya '
                  'mencetak 40 karakter, bukan 48.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _judul('Isi struk'),
          _kartu(
            anak: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pengaturan.cetakLogo,
                  activeColor: AppColors.primary,
                  title: const Text(
                    'Cetak logo toko',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  subtitle: const Text(
                    'Logo berwarna otomatis dicetak hitam putih',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (nilai) =>
                      _ubah(pengaturan.copyWith(cetakLogo: nilai)),
                ),
                const Divider(height: 1, color: AppColors.border),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pengaturan.cetakQris,
                  activeColor: AppColors.primary,
                  title: const Text(
                    'Cetak gambar QRIS',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  subtitle: const Text(
                    'Matikan kalau printer lambat atau gambar sering gagal',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (nilai) =>
                      _ubah(pengaturan.copyWith(cetakQris: nilai)),
                ),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                _label('Baris total'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _pilihanTotal(GayaTotal.besar, pengaturan)),
                    const SizedBox(width: 10),
                    Expanded(child: _pilihanTotal(GayaTotal.normal, pengaturan)),
                  ],
                ),
                const SizedBox(height: 14),
                _barisKosong(pengaturan),
                const Divider(height: 20, color: AppColors.border),
                _marginKanan(pengaturan),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _judul('Pratinjau struk'),
          _pratinjau(pengaturan, user),
          const SizedBox(height: 18),
          _judul('Printer'),
          _kartu(
            anak: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: pengaturan.ingatPrinter,
                  activeColor: AppColors.primary,
                  title: const Text(
                    'Ingat printer terakhir',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                    ),
                  ),
                  subtitle: const Text(
                    'Langsung tersambung tanpa memilih ulang. Kalau printer '
                    'mati, layar pilih printer tetap muncul.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  onChanged: (nilai) =>
                      _ubah(pengaturan.copyWith(ingatPrinter: nilai)),
                ),
                const Divider(height: 1, color: AppColors.border),
                if (pengaturan.adaPrinterTersimpan)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.print_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (pengaturan.printerNama ?? '').trim().isEmpty
                                ? pengaturan.printerId!
                                : pengaturan.printerNama!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMain,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _lupakanPrinter,
                          child: const Text('Lupakan'),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Belum ada printer tersimpan. Printer dicatat otomatis '
                      'setelah berhasil mencetak.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _sibuk ? null : _cetakContoh,
              icon: _sibuk
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.print, size: 20),
              label: Text(_sibuk ? 'Menyiapkan...' : 'Cetak contoh struk'),
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
          _catatan(
            'Contoh struk berisi satu barang Rp 10.000 x 3 = Rp 30.000. '
            'Kalau nominalnya tercetak penuh dan jamnya muncul, pengaturan ini '
            'sudah cocok untuk printer Anda.',
          ),
        ],
      ),
    );
  }

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
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        teks,
        style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
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

  /// Satu pilihan ukuran kertas.
  Widget _pilihanKertas(int lebar, PrintSettings pengaturan) {
    final terpilih = pengaturan.lebarKertas == lebar;
    final karakter = ReceiptService.karakterPerBaris(lebar);
    return InkWell(
      onTap: () => _ubah(pengaturan.copyWith(lebarKertas: lebar)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: terpilih ? AppColors.primaryLight : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: terpilih ? AppColors.primary : AppColors.border,
            width: terpilih ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$lebar mm',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: terpilih ? AppColors.primaryDark : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$karakter karakter',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Satu pilihan gaya baris total.
  Widget _pilihanTotal(GayaTotal gaya, PrintSettings pengaturan) {
    final terpilih = pengaturan.gayaTotal == gaya;
    final keterangan =
        gaya == GayaTotal.besar ? 'TOTAL lalu angka besar' : 'Satu baris ringkas';
    return InkWell(
      onTap: () => _ubah(pengaturan.copyWith(gayaTotal: gaya)),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: terpilih ? AppColors.primaryLight : AppColors.bgSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: terpilih ? AppColors.primary : AppColors.border,
            width: terpilih ? 1.5 : 0.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              gaya.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: terpilih ? AppColors.primaryDark : AppColors.textMain,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              keterangan,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pengatur jumlah baris kosong sebelum kertas dipotong.
  Widget _barisKosong(PrintSettings pengaturan) {
    final nilai = pengaturan.barisKosong;
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Baris kosong sebelum dipotong',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Ruang untuk menyobek kertas',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: nilai <= 0
              ? null
              : () => _ubah(pengaturan.copyWith(barisKosong: nilai - 1)),
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.textSecondary,
        ),
        SizedBox(
          width: 22,
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
          onPressed: nilai >= 8
              ? null
              : () => _ubah(pengaturan.copyWith(barisKosong: nilai + 1)),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
        ),
      ],
    );
  }

  /// Pengatur jarak nominal dari tepi kanan kertas.
  ///
  /// Ini obat untuk keluhan "nominal terpotong di ujung". Kalau dua karakter
  /// masih kurang, pemilik bisa menaikkannya sendiri tanpa menunggu rilis
  /// baru — setiap printer punya selisih tepi yang berbeda.
  Widget _marginKanan(PrintSettings pengaturan) {
    final nilai = pengaturan.marginKanan;
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jarak dari tepi kanan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMain,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Naikkan kalau ujung nominal masih terpotong',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: nilai <= 0
              ? null
              : () => _ubah(pengaturan.copyWith(marginKanan: nilai - 1)),
          icon: const Icon(Icons.remove_circle_outline),
          color: AppColors.textSecondary,
        ),
        SizedBox(
          width: 34,
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
          onPressed: nilai >= 6
              ? null
              : () => _ubah(pengaturan.copyWith(marginKanan: nilai + 1)),
          icon: const Icon(Icons.add_circle_outline),
          color: AppColors.primary,
        ),
      ],
    );
  }

  /// Kertas pratinjau — susunannya mengikuti `ReceiptService.generateReceipt`.
  Widget _pratinjau(PrintSettings pengaturan, UserModel? user) {
    final lebar = ReceiptService.lebarTeks(
      ReceiptService.karakterPerBaris(pengaturan.lebarKertas),
      pengaturan.marginKanan,
    );
    final ukuran = pengaturan.lebarKertas == 80 ? 8.0 : 10.0;
    const warna = Color(0xFF111111);
    final gaya = TextStyle(
      fontFamily: 'monospace',
      fontSize: ukuran,
      height: 1.45,
      color: warna,
    );
    final tebal = gaya.copyWith(fontWeight: FontWeight.w700);
    final garis = '-' * lebar;
    final sekarang = DateTime.now();

    final isi = <Widget>[];

    if (pengaturan.cetakLogo && (user?.logoPath ?? '').trim().isNotEmpty) {
      // Bukan gambarnya, hanya penanda tempat: logo dicetak hitam putih oleh
      // `ReceiptService`, dan menampilkan versi berwarnanya di sini justru
      // membuat pratinjau berbohong. Hasil aslinya dilihat lewat "Cetak
      // contoh struk".
      isi.add(
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.image_outlined, size: 16, color: Colors.black45),
              SizedBox(width: 4),
              Text(
                'logo toko',
                style: TextStyle(fontSize: 9, color: Colors.black45),
              ),
            ],
          ),
        ),
      );
    }

    isi.add(
      Text(
        user?.storeName ?? 'Toko Saya',
        textAlign: TextAlign.center,
        style: gaya.copyWith(fontSize: ukuran * 1.5, fontWeight: FontWeight.w800),
      ),
    );
    final alamat = (user?.storeAddress ?? '').trim();
    if (alamat.isNotEmpty) {
      isi.add(Text(alamat, textAlign: TextAlign.center, style: gaya));
    }
    isi.add(Text(garis, textAlign: TextAlign.center, style: gaya));
    isi.add(Text('STRUK PENJUALAN', textAlign: TextAlign.center, style: tebal));
    isi.add(Text(garis, textAlign: TextAlign.center, style: gaya));
    isi.add(Text('No: CONTOH-001', style: gaya));
    isi.add(Text('Tanggal: ${Formatters.date(sekarang)}', style: gaya));
    isi.add(Text('Jam: ${Formatters.time(sekarang)}', style: gaya));
    isi.add(Text(garis, textAlign: TextAlign.center, style: gaya));
    isi.add(Text('Contoh barang', style: gaya));
    isi.add(
      Text(
        ReceiptService.duaKolom('3 pcs x Rp 10.000', 'Rp 30.000', lebar),
        style: gaya,
      ),
    );
    isi.add(Text(garis, textAlign: TextAlign.center, style: gaya));

    if (pengaturan.gayaTotal == GayaTotal.besar) {
      isi.add(Text('TOTAL', style: tebal));
      isi.add(
        Text(
          'Rp 30.000',
          textAlign: TextAlign.right,
          style: tebal.copyWith(fontSize: ukuran * 1.6),
        ),
      );
    } else {
      isi.add(
        Text(
          ReceiptService.duaKolom('TOTAL', 'Rp 30.000', lebar),
          style: tebal,
        ),
      );
    }

    isi.add(Text('Tunai: Rp 50.000', style: gaya));
    isi.add(Text('Kembali: Rp 20.000', style: gaya));
    isi.add(Text('Bayar: TUNAI', style: gaya));
    isi.add(Text('Item: 3', style: gaya));
    isi.add(Text(garis, textAlign: TextAlign.center, style: gaya));
    isi.add(
      Text(
        ReceiptService.footerStruk(user?.receiptFooter),
        textAlign: TextAlign.center,
        style: gaya,
      ),
    );
    isi.add(
      Text(
        'Powered by TokoKu',
        textAlign: TextAlign.center,
        style: gaya.copyWith(fontSize: ukuran * 0.85, color: const Color(0xFF555555)),
      ),
    );

    // `Center` bukan hiasan: anak `ListView` dipaksa selebar layar, jadi
    // `width: 300` pada Container di bawah akan diabaikan tanpa pembungkus ini
    // dan kertas pratinjaunya melebar penuh.
    return Center(
      child: Container(
        width: 300,
        // Padding kanan mengikuti margin yang dipilih, supaya pratinjau
        // memperlihatkan jarak nominal ke tepi kertas — bukan hanya teksnya.
        padding: EdgeInsets.fromLTRB(
          12,
          14,
          12 + pengaturan.marginKanan * ukuran * 0.6,
          16,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(3),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: isi,
        ),
      ),
    );
  }
}
