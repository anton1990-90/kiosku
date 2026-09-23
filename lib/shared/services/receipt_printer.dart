import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/sale_item_model.dart';
import '../../data/models/sale_model.dart';
import '../../data/models/user_model.dart';
import '../../features/kasir/printer_selection_screen.dart';
import 'bluetooth_printer_service.dart';
import 'receipt_service.dart';

/// Cetak struk ke printer termal Bluetooth.
///
/// Satu tempat untuk dua pemakai: kasir (setelah transaksi selesai) dan
/// riwayat transaksi (cetak ulang). Sengaja disatukan supaya kedua jalur tidak
/// bisa menyimpang — sebelumnya logika cetak hanya ada di dalam layar kasir,
/// sehingga struk yang sudah lewat tidak bisa dicetak lagi sama sekali.
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
  final device = await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
  );

  if (device == null) return false;

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
    );
    await BluetoothPrinterService.instance.printBytes(device, bytes);
    await BluetoothPrinterService.instance.disconnect(device);

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
