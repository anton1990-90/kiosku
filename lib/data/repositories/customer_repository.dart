import 'package:sqflite/sqflite.dart';

import '../database/database_helper.dart';
import '../models/customer_model.dart';

/// Repositori pelanggan — buku pelanggan yang bisa diedit pengguna.
///
/// Dua hal yang sengaja dijaga di sini:
///
///  * **Nama pelanggan tidak pernah dibaca ulang dari tabel ini untuk sebuah
///    transaksi.** `debts.party_name` dan `sales.customer_name` menyimpan
///    rekaman nama saat transaksi terjadi; mengubah nama pelanggan hari ini
///    tidak boleh mengubah struk kemarin. Tabel ini hanya menyimpan identitas
///    dan kontak.
///  * **Menghapus pelanggan tidak menghapus riwayatnya.** Penghubungnya
///    dikosongkan saja, sama seperti `SupplierRepository.delete`. Riwayat
///    penjualan dan piutang adalah catatan uang, bukan data pelanggan.
class CustomerRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<List<CustomerModel>> getAll({String? search}) async {
    final db = await _db.database;
    final trimmed = search?.trim() ?? '';
    final results = await db.query(
      'customers',
      where: trimmed.isEmpty ? null : 'name LIKE ?',
      whereArgs: trimmed.isEmpty ? null : ['%$trimmed%'],
      orderBy: 'name ASC',
    );
    return results.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<CustomerModel?> getById(int id) async {
    final db = await _db.database;
    final results = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return CustomerModel.fromMap(results.first);
  }

  /// Nama pelanggan saja — dipakai untuk saran saat kasir mengetik nama.
  Future<List<String>> getNames() async {
    final db = await _db.database;
    final results = await db.rawQuery(
      'SELECT name FROM customers ORDER BY name ASC',
    );
    return results.map((m) => m['name'] as String).toList();
  }

  /// Daftar pelanggan beserta ringkasan hutang dan belanjanya.
  ///
  /// Angka-angkanya dihitung dengan subquery, bukan `JOIN` ke `debts` dan
  /// `sales` sekaligus: menggabungkan keduanya dalam satu query akan
  /// mengalikan barisnya (satu pelanggan × jumlah hutang × jumlah nota),
  /// sehingga jumlahnya membengkak tanpa terlihat salah.
  ///
  /// Penjualan dibaca dari view `sales_aktif`, jadi transaksi yang dibatalkan
  /// tidak ikut terhitung — aturan yang sama dengan seluruh laporan lain.
  Future<List<CustomerRingkasan>> getRingkasan({String? search}) async {
    final db = await _db.database;
    final trimmed = search?.trim() ?? '';

    final rows = await db.rawQuery('''
      SELECT c.id, c.name, c.phone, c.address, c.note,
             c.created_at, c.updated_at,
        (SELECT COALESCE(SUM(d.amount - d.paid_amount), 0)
           FROM debts d
          WHERE d.customer_id = c.id
            AND d.type = 'piutang'
            AND d.amount > d.paid_amount) AS total_piutang,
        (SELECT COALESCE(SUM(s.total_amount), 0)
           FROM sales_aktif s
          WHERE s.customer_id = c.id) AS total_belanja,
        (SELECT COUNT(*)
           FROM sales_aktif s
          WHERE s.customer_id = c.id) AS jumlah_transaksi,
        (SELECT MAX(s.created_at)
           FROM sales_aktif s
          WHERE s.customer_id = c.id) AS terakhir
      FROM customers c
      ${trimmed.isEmpty ? '' : 'WHERE c.name LIKE ?'}
      ORDER BY c.name ASC
    ''', trimmed.isEmpty ? [] : ['%$trimmed%']);

    return rows.map((r) {
      final terakhir = r['terakhir'] as String?;
      return CustomerRingkasan(
        customer: CustomerModel.fromMap(r),
        totalPiutang: (r['total_piutang'] as int?) ?? 0,
        totalBelanja: (r['total_belanja'] as int?) ?? 0,
        jumlahTransaksi: (r['jumlah_transaksi'] as int?) ?? 0,
        transaksiTerakhir:
            terakhir == null ? null : DateTime.tryParse(terakhir),
      );
    }).toList();
  }

  Future<int> insert(CustomerModel customer) async {
    final db = await _db.database;
    return await db.insert('customers', customer.toMap());
  }

  Future<int> update(CustomerModel customer) async {
    final db = await _db.database;
    return await db.update(
      'customers',
      customer.copyWith(updatedAt: DateTime.now()).toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  /// Hapus pelanggan. Riwayat transaksinya TIDAK ikut terhapus — penghubungnya
  /// dikosongkan dulu, dan namanya tetap tersimpan di tiap nota serta catatan
  /// piutang.
  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.transaction((txn) async {
      await txn.update(
        'debts',
        {'customer_id': null},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      await txn.update(
        'sales',
        {'customer_id': null},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      return txn.delete('customers', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<int> count() async {
    final db = await _db.database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM customers');
    return (rows.first['c'] as int?) ?? 0;
  }

  /// Cari pelanggan bernama persis [nama]; buat baru kalau belum ada.
  ///
  /// Menerima [exec] supaya bisa dipanggil **di dalam** transaksi penjualan.
  /// Pelanggan baru harus lahir dalam transaksi yang sama dengan penjualannya:
  /// kalau tidak, penjualan bisa merujuk pelanggan yang gagal tersimpan.
  ///
  /// Mengembalikan `null` kalau namanya kosong — transaksi tanpa nama
  /// (mis. pembeli yang tidak mau disebut) tidak boleh membuat pelanggan
  /// bernama kosong yang lalu menumpuk di buku pelanggan.
  ///
  /// Pencocokan memakai nama persis (setelah dipangkas), bukan `LIKE`, supaya
  /// "Bu Siti" tidak dianggap sama dengan "Bu Siti Mulyani".
  Future<int?> pastikanPelanggan(DatabaseExecutor exec, String? nama) async {
    final trimmed = (nama ?? '').trim();
    if (trimmed.isEmpty) return null;

    final ada = await exec.query(
      'customers',
      columns: ['id'],
      where: 'name = ?',
      whereArgs: [trimmed],
      limit: 1,
    );
    if (ada.isNotEmpty) return ada.first['id'] as int;

    final now = DateTime.now().toIso8601String();
    return exec.insert('customers', {
      'name': trimmed,
      'created_at': now,
      'updated_at': now,
    });
  }
}
