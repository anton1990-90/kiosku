import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/print_settings_model.dart';
import 'bluetooth_printer_service.dart';

/// Menyimpan & membaca [PrintSettings] dari SharedPreferences.
///
/// Dipakai dua tempat: layar Pengaturan Cetak (lewat provider) dan jalur cetak
/// struk. Jalur cetak sengaja membaca langsung dari sini, bukan dari provider,
/// karena `cetakStruk()` dipanggil dari luar pohon widget (riwayat transaksi)
/// dan tidak punya akses ke `ref`. Satu sumber kebenaran, dua pembaca.
class PrintSettingsService {
  PrintSettingsService._();
  static final PrintSettingsService instance = PrintSettingsService._();

  static const String _kLebar = 'cetak_lebar_kertas';
  static const String _kGayaTotal = 'cetak_gaya_total';
  static const String _kLogo = 'cetak_logo';
  static const String _kQris = 'cetak_qris';
  static const String _kBarisKosong = 'cetak_baris_kosong';
  static const String _kIngatPrinter = 'cetak_ingat_printer';
  static const String _kPrinterId = 'cetak_printer_id';
  static const String _kPrinterNama = 'cetak_printer_nama';
  static const String _kPrinterJenis = 'cetak_printer_jenis';

  /// Lebar kertas yang diizinkan. Nilai lain di luar ini diabaikan supaya
  /// berkas preferensi yang rusak tidak menghasilkan struk tak terbaca.
  static const List<int> lebarDidukung = [58, 80];

  Future<PrintSettings> muat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lebar = prefs.getInt(_kLebar) ?? 58;
      final baris = prefs.getInt(_kBarisKosong) ?? 3;
      return PrintSettings(
        lebarKertas: lebarDidukung.contains(lebar) ? lebar : 58,
        gayaTotal: GayaTotal.dariKode(prefs.getString(_kGayaTotal)),
        cetakLogo: prefs.getBool(_kLogo) ?? true,
        cetakQris: prefs.getBool(_kQris) ?? true,
        barisKosong: baris < 0 ? 0 : (baris > 8 ? 8 : baris),
        ingatPrinter: prefs.getBool(_kIngatPrinter) ?? false,
        printerId: prefs.getString(_kPrinterId),
        printerNama: prefs.getString(_kPrinterNama),
        printerJenis: prefs.getString(_kPrinterJenis) ?? 'klasik',
      );
    } catch (_) {
      // Penyimpanan tidak terbaca: struk tetap harus bisa dicetak, jadi
      // pakai pengaturan bawaan alih-alih menggagalkan pencetakan.
      return const PrintSettings();
    }
  }

  Future<void> simpan(PrintSettings pengaturan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLebar, pengaturan.lebarKertas);
      await prefs.setString(_kGayaTotal, pengaturan.gayaTotal.kode);
      await prefs.setBool(_kLogo, pengaturan.cetakLogo);
      await prefs.setBool(_kQris, pengaturan.cetakQris);
      await prefs.setInt(_kBarisKosong, pengaturan.barisKosong);
      await prefs.setBool(_kIngatPrinter, pengaturan.ingatPrinter);
      await prefs.setString(_kPrinterJenis, pengaturan.printerJenis);
      if (pengaturan.adaPrinterTersimpan) {
        await prefs.setString(_kPrinterId, pengaturan.printerId!);
        await prefs.setString(_kPrinterNama, pengaturan.printerNama ?? '');
      } else {
        await prefs.remove(_kPrinterId);
        await prefs.remove(_kPrinterNama);
      }
    } catch (_) {
      // Gagal menyimpan bukan alasan menggagalkan pencetakan.
    }
  }

  /// Catat printer yang barusan dipakai supaya bisa disambung otomatis.
  Future<void> simpanPrinter(PrinterDevice alat) async {
    final sekarang = await muat();
    await simpan(
      sekarang.copyWith(
        printerId: alat.id,
        printerNama: alat.nama,
        printerJenis: alat.jenis == JenisPrinter.ble ? 'ble' : 'klasik',
      ),
    );
  }

  Future<void> lupakanPrinter() async {
    final sekarang = await muat();
    await simpan(sekarang.tanpaPrinter());
  }
}
