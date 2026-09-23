import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/cash_model.dart';
import '../models/debt_model.dart';
import '../models/sale_item_model.dart';
import '../models/sale_model.dart';

/// Sale repository — handles transaction creation and history queries.
/// All offline: transactions are stored locally in SQLite.
///
/// Satu transaksi penjualan menyentuh beberapa tabel sekaligus supaya semua
/// laporan konsisten:
///   * `sales` + `sale_items` — nota dan rincian barang
///   * `products`             — stok berkurang
///   * `stock_movements`      — jejak stok keluar
///   * `cash_transactions`    — uang yang benar-benar diterima
///   * `debts`                — piutang, kalau pelanggan belum bayar penuh
class SaleRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  /// Create a new sale transaction with all line items.
  /// Also reduces product stock for each item.
  ///
  /// [isDebt] menandai transaksi yang dicatat sebagai hutang pelanggan.
  /// Kalau [paidAmount] kurang dari total, sisa otomatis dibuatkan catatan
  /// piutang — jadi tidak perlu dicatat dua kali secara manual.
  ///
  /// [discount] adalah potongan untuk seluruh nota, di luar potongan per baris
  /// yang sudah dikurangi di dalam `items`. Nilainya memotong total yang harus
  /// dibayar **dan** laba, karena uang yang benar-benar masuk memang lebih
  /// sedikit.
  Future<SaleModel> createSale({
    required int userId,
    required List<SaleItemModel> items,
    String? customerName,
    required String paymentMethod,
    required int paidAmount,
    bool isDebt = false,
    DateTime? dueDate,
    int discount = 0,
  }) async {
    final db = await _db.database;

    // Harga semua barang setelah potongan per baris.
    final hargaBarang = items.fold(0, (sum, i) => sum + i.subtotal);

    // Potongan nota dibatasi harga barang, supaya total tidak pernah negatif
    // walau kasir salah mengetik angka.
    final potonganNota = discount < 0
        ? 0
        : (discount > hargaBarang ? hargaBarang : discount);

    final totalAmount = hargaBarang - potonganNota;

    // Laba barang dikurangi potongan nota — uang masuknya memang lebih sedikit.
    final labaBarang = items.fold(0, (sum, i) => sum + i.profit);
    final totalProfit = labaBarang - potonganNota;

    final totalItems = items.fold(0, (sum, i) => sum + i.quantity);

    // Pembayaran tidak boleh negatif atau melebihi total.
    final dibayar = paidAmount < 0
        ? 0
        : (paidAmount > totalAmount ? totalAmount : paidAmount);
    final changeAmount = dibayar - totalAmount > 0 ? dibayar - totalAmount : 0;
    final sisa = totalAmount - dibayar;
    final catatPiutang = isDebt && sisa > 0;

    final invoiceNumber = _generateInvoiceNumber();
    final now = DateTime.now();

    final sale = SaleModel(
      invoiceNumber: invoiceNumber,
      userId: userId,
      customerName: customerName,
      totalAmount: totalAmount,
      totalProfit: totalProfit,
      totalItems: totalItems,
      paymentMethod: paymentMethod,
      paidAmount: dibayar,
      changeAmount: changeAmount,
      isDebt: catatPiutang,
      discount: potonganNota,
      createdAt: now,
    );

    int? saleId;
    int? debtId;

    await db.transaction((txn) async {
      saleId = await txn.insert('sales', sale.toMap());

      for (final item in items) {
        await txn.insert('sale_items', {
          ...item.toMap(),
          'sale_id': saleId,
        });
        await txn.rawUpdate(
          'UPDATE products SET stock = stock - ?, updated_at = ? WHERE id = ?',
          [item.quantity, now.toIso8601String(), item.productId],
        );
        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'product_name': item.productName,
          'type': 'out',
          'quantity': item.quantity,
          'total_cost': item.costPrice * item.quantity,
          'note': 'Penjualan $invoiceNumber',
          'ref_type': 'sale',
          'ref_id': saleId,
          'date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
      }

      // Piutang pelanggan — hanya dibuat kalau memang belum dibayar penuh.
      if (catatPiutang) {
        debtId = await txn.insert('debts', {
          'party_name': (customerName == null || customerName.trim().isEmpty)
              ? 'Pelanggan'
              : customerName.trim(),
          'type': DebtType.piutang,
          'amount': totalAmount,
          'paid_amount': dibayar,
          'note': 'Hutang dari transaksi $invoiceNumber',
          'due_date': dueDate?.toIso8601String(),
          'status': DebtStatus.belumLunas,
          'sale_id': saleId,
          'product_id': items.length == 1 ? items.first.productId : null,
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        await txn.update(
          'sales',
          {'debt_id': debtId},
          where: 'id = ?',
          whereArgs: [saleId],
        );
      }

      // Uang yang benar-benar masuk ke kas hari ini.
      if (dibayar > 0) {
        await txn.insert('cash_transactions', {
          'type': CashType.masuk,
          'amount': dibayar,
          'category': CashCategory.penjualan,
          'note': catatPiutang
              ? 'Pembayaran sebagian $invoiceNumber'
              : 'Penjualan $invoiceNumber',
          'ref_type': 'sale',
          'ref_id': saleId,
          'date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
      }
    });

    return SaleModel(
      id: saleId,
      invoiceNumber: sale.invoiceNumber,
      userId: sale.userId,
      customerName: sale.customerName,
      totalAmount: sale.totalAmount,
      totalProfit: sale.totalProfit,
      totalItems: sale.totalItems,
      paymentMethod: sale.paymentMethod,
      paidAmount: sale.paidAmount,
      changeAmount: sale.changeAmount,
      isDebt: sale.isDebt,
      debtId: debtId,
      createdAt: sale.createdAt,
    );
  }

  /// Batalkan transaksi penjualan.
  ///
  /// Transaksinya **tidak dihapus**. Statusnya berubah jadi 'batal' dan seluruh
  /// akibatnya dibalik dengan catatan baru, semuanya dalam SATU transaksi
  /// database — kalau ada satu langkah yang gagal, tidak ada yang setengah jalan:
  ///
  ///   1. stok setiap barang dikembalikan, dengan jejak di `stock_movements`
  ///   2. uang yang pernah masuk dikeluarkan lagi di `cash_transactions`
  ///   3. piutang yang lahir dari transaksi ini dihapus
  ///
  /// Karena seluruh laporan membaca view `sales_aktif` yang menyaring status,
  /// transaksi ini langsung hilang dari semua laporan **tanpa satu pun query
  /// laporan perlu diubah**.
  ///
  /// Piutang yang **sudah ada pembayarannya** membuat pembatalan ditolak:
  /// pembayaran itu uang yang benar-benar diterima, dan menghapusnya diam-diam
  /// akan membuat kas tidak cocok. Karena `debt_payments` memakai
  /// `ON DELETE CASCADE`, menghapus piutangnya akan ikut menghapus riwayat
  /// pembayaran tanpa peringatan — jadi penolakan ini yang menjaga, bukan kunci
  /// asingnya.
  Future<({bool berhasil, String pesan, int itemKembali, int uangKeluar})>
      batalkan({required int saleId, String? reason}) async {
    final db = await _db.database;

    // Dibaca lewat `sales_semua`: transaksi yang sudah dibatalkan harus tetap
    // bisa ditemukan, kalau tidak pembatalan kedua kali akan tampak "berhasil".
    final sale = await getSaleById(saleId);
    if (sale == null) {
      return (
        berhasil: false,
        pesan: 'Transaksi tidak ditemukan',
        itemKembali: 0,
        uangKeluar: 0,
      );
    }
    if (sale.dibatalkan) {
      return (
        berhasil: false,
        pesan: 'Transaksi ${sale.invoiceNumber} sudah dibatalkan',
        itemKembali: 0,
        uangKeluar: 0,
      );
    }

    final piutangDenganBayar = await db.rawQuery('''
      SELECT COUNT(*) AS c
      FROM debt_payments dp
      INNER JOIN debts d ON d.id = dp.debt_id
      WHERE d.sale_id = ?
    ''', [saleId]);
    final adaPembayaran = (Sqflite.firstIntValue(piutangDenganBayar) ?? 0) > 0;
    if (adaPembayaran) {
      return (
        berhasil: false,
        pesan: 'Piutang dari transaksi ini sudah ada pembayarannya. '
            'Batalkan pembayarannya dulu di menu Hutang & Piutang.',
        itemKembali: 0,
        uangKeluar: 0,
      );
    }

    final items = await getSaleItems(saleId);
    final now = DateTime.now();
    final alasan = (reason ?? '').trim();
    final catatan = alasan.isEmpty
        ? 'Pembatalan ${sale.invoiceNumber}'
        : 'Pembatalan ${sale.invoiceNumber} — $alasan';

    var itemKembali = 0;
    var uangKeluar = 0;

    await db.transaction((txn) async {
      await txn.update(
        'sales',
        {
          'status': SaleStatus.batal,
          'cancel_reason': alasan.isEmpty ? null : alasan,
        },
        where: 'id = ?',
        whereArgs: [saleId],
      );

      for (final item in items) {
        await txn.rawUpdate(
          'UPDATE products SET stock = stock + ?, updated_at = ? WHERE id = ?',
          [item.quantity, now.toIso8601String(), item.productId],
        );
        await txn.insert('stock_movements', {
          'product_id': item.productId,
          'product_name': item.productName,
          'type': 'in',
          'quantity': item.quantity,
          'total_cost': item.costPrice * item.quantity,
          'note': catatan,
          'ref_type': 'sale_cancel',
          'ref_id': saleId,
          'date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
        itemKembali += item.quantity;
      }

      // Uang yang pernah masuk dikembalikan ke pelanggan.
      if (sale.paidAmount > 0) {
        await txn.insert('cash_transactions', {
          'type': CashType.keluar,
          'amount': sale.paidAmount,
          'category': CashCategory.penjualan,
          'note': catatan,
          'ref_type': 'sale_cancel',
          'ref_id': saleId,
          'date': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });
        uangKeluar = sale.paidAmount;
      }

      // Piutang dari transaksi ini tidak boleh hidup lebih lama daripada
      // transaksinya. Disaring lewat `sale_id`, bukan `debt_id` saja, supaya
      // tidak ada piutang yang tertinggal kalau penghubungnya kosong.
      await txn.delete('debts', where: 'sale_id = ?', whereArgs: [saleId]);
    });

    return (
      berhasil: true,
      pesan: 'Transaksi ${sale.invoiceNumber} dibatalkan',
      itemKembali: itemKembali,
      uangKeluar: uangKeluar,
    );
  }

  /// Generate invoice number: TK-YYYYMMDD-HHMMSS
  String _generateInvoiceNumber() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'TK-$datePart-$timePart';
  }

  /// Get sales for a specific date range.
  Future<List<SaleModel>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    int limit = 100,
  }) async {
    final db = await _db.database;
    String where = '';
    List<dynamic> args = [];

    if (startDate != null) {
      where = "created_at >= ?";
      args.add(startDate.toIso8601String());
    }
    if (endDate != null) {
      final endFilter =
          endDate.add(const Duration(days: 1));
      where = where.isEmpty
          ? "created_at < ?"
          : "$where AND created_at < ?";
      args.add(endFilter.toIso8601String());
    }

    final results = await db.query(
      'sales_aktif',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return results.map((m) => SaleModel.fromMap(m)).toList();
  }

  /// Ambil satu penjualan berdasarkan id.
  ///
  /// Dipakai untuk mencetak ulang struk dari riwayat transaksi: riwayat hanya
  /// menyimpan ringkasan, sedangkan pembuat struk memerlukan model penjualan
  /// yang utuh (invoice, metode bayar, jumlah dibayar, dan kembalian).
  ///
  /// Membaca `sales_semua`, bukan `sales_aktif`: transaksi yang sudah
  /// dibatalkan tetap harus bisa ditemukan, kalau tidak proses pembatalannya
  /// sendiri tidak bisa memeriksa status yang sekarang.
  Future<SaleModel?> getSaleById(int saleId) async {
    final db = await _db.database;
    final results = await db.query(
      'sales_semua',
      where: 'id = ?',
      whereArgs: [saleId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return SaleModel.fromMap(results.first);
  }

  /// Get sale items for a specific sale.
  Future<List<SaleItemModel>> getSaleItems(int saleId) async {
    final db = await _db.database;
    final results = await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return results.map((m) => SaleItemModel.fromMap(m)).toList();
  }

  /// Get today's total sales amount.
  Future<int> getTodaySalesTotal() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_aktif WHERE created_at >= ? AND created_at < ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get today's transaction count.
  Future<int> getTodayTransactionCount() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      'SELECT COUNT(*) as c FROM sales_aktif WHERE created_at >= ? AND created_at < ?',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get weekly sales data (last 7 days) for chart.
  Future<List<({String day, int total})>> getWeeklySales() async {
    final db = await _db.database;
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    final results = <({String day, int total})>[];
    final dayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    for (var i = 0; i < 7; i++) {
      final day = startOfWeek.add(Duration(days: i));
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final result = await db.rawQuery(
        'SELECT COALESCE(SUM(total_amount), 0) as total FROM sales_aktif WHERE created_at >= ? AND created_at < ?',
        [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      );
      results.add((
        day: dayNames[i],
        total: Sqflite.firstIntValue(result) ?? 0,
      ));
    }
    return results;
  }
}
