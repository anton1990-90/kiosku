import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/print_settings_model.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../features/kasir/printer_selection_screen.dart';
import 'bluetooth_printer_service.dart';
import 'print_settings_service.dart';
import 'receipt_service.dart';

/// Cetak struk ke printer termal Bluetooth.
///
/// Satu tempat untuk dua pemakai: kasir (setelah transaksi selesai) dan
/// riwayat transaksi (cetak ulang). Sengaja disatukan supaya kedua jalur tidak
/// bisa menyimpang — sebelumnya logika cetak hanya ada di dalam layar kasir,
/// sehingga struk yang sudah lewat tidak bisa dicetak lagi sama sekali.
///
/// Ukuran kertas dan pilihan lain dibaca dari [PrintSettingsService] setiap
/// kali mencetak, bukan dikirim pemanggil: struk yang sama harus tercetak
/// dengan ukuran kertas yang sedang dipakai HP ini, termasuk saat dicetak ulang
/// dari riwayat transaksi berminggu-minggu kemudian.
///
/// Mengembalikan `true` kalau struk benar-benar terkirim ke printer, dan
/// `false` kalau pemilik membatalkan pemilihan printer. Galat cetak sudah
/// dilaporkan lewat SnackBar di sini, jadi pemanggil tidak perlu menangani
/// apa pun selain nilai kembaliannya.
Future<bool> cetakStruk({
  required BuildContext context,
  required SaleModel sale,
  required List<SaleItemModel> items,
  required UserModel user,
}) async {
  final pengaturan = await PrintSettingsService.instance.muat();
  if (!context.mounted) return false;
  final printer = await _printerSiap(context, pengaturan);

  if (printer == null) return false;

  try {
    final bytes = await ReceiptService.instance.generateReceipt(
      sale: sale,
      items: items,
      storeName: user.storeName,
      storeAddress: user.storeAddress,
      storePhone: user.storePhone,
      logoPath: user.logoPath,
      qrisPath: user.qrisPath,
      bankName: user.bankName,
      bankAccountNumber: user.bankAccountNumber,
      bankAccountName: user.bankAccountName,
      receiptFooter: user.receiptFooter,
      paperWidth: pengaturan.lebarKertas,
      cetakLogo: pengaturan.cetakLogo,
      cetakQris: pengaturan.cetakQris,
      gayaTotal: pengaturan.gayaTotal,
      barisKosong: pengaturan.barisKosong,
      marginKanan: pengaturan.marginKanan,
    );
    await BluetoothPrinterService.instance.cetak(printer, bytes);
    await BluetoothPrinterService.instance.putus(printer);
    // Dicatat supaya Pengaturan Cetak bisa menampilkan printer terakhir dan
    // bisa menyambung otomatis kalau pemilik menyalakan "ingat printer".
    await PrintSettingsService.instance.simpanPrinter(printer);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Struk berhasil dicetak'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mencetak: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    return false;
  }
}

/// Printer yang akan dipakai: printer terakhir (kalau diingat), atau hasil
/// pemilihan pengguna.
///
/// Menyambung otomatis sengaja **tidak** dijadikan bawaan. Kalau printer
/// sedang mati, percobaan sambung memakan waktu belasan detik sebelum akhirnya
/// tetap menampilkan layar pilih — dan kasir mengira aplikasinya menggantung.
Future<PrinterDevice?> _printerSiap(
  BuildContext context,
  PrintSettings pengaturan,
) async {
  final id = (pengaturan.printerId ?? '').trim();

  if (pengaturan.ingatPrinter && id.isNotEmpty) {
    final tersimpan = PrinterDevice(
      id: id,
      nama: pengaturan.printerNama ?? '',
      jenis: pengaturan.printerJenis == 'ble'
          ? JenisPrinter.ble
          : JenisPrinter.klasik,
      terpasang: true,
    );
    try {
      await BluetoothPrinterService.instance
          .sambung(tersimpan)
          .timeout(const Duration(seconds: 12));
      return tersimpan;
    } catch (_) {
      // Printer mati, di luar jangkauan, atau sudah dipasangkan ulang.
      // Jatuh ke pemilihan manual — bukan galat yang perlu ditampilkan.
    }
    if (!context.mounted) return null;
  }

  final hasil = await Navigator.push<PrinterDevice>(
    context,
    MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
  );
  return hasil;
}
