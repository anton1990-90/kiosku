import 'dart:convert';
import 'dart:io';

import '../../data/database/database_helper.dart';
import '../../data/models/user_model.dart';
import 'export_service.dart';
import 'xlsx_builder.dart';

/// Backup seluruh data aplikasi ke satu berkas Excel berisi banyak lembar.
///
/// Satu lembar per jenis data supaya mudah dibaca dan diolah lagi di Excel:
/// Produk, Penjualan, Item Penjualan, Hutang & Piutang, Pembayaran Hutang,
/// Kas, Beban, Prive, Riwayat Stok, Supplier, Catatan, plus satu lembar
/// Ringkasan.
///
/// Semua kolom uang ditulis sebagai **angka** (bukan teks "Rp 65.000") supaya
/// bisa langsung dijumlahkan di Excel. Kolom tanggal ditulis apa adanya dalam
/// format ISO-8601 seperti yang tersimpan di database, sehingga urutannya
/// tetap benar kalau diurutkan.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  /// Versi format berkas cadangan. Naikkan kalau isinya berubah bentuk,
  /// supaya berkas lama masih bisa dikenali dan ditolak dengan jelas
  /// daripada dipulihkan setengah jalan.
  static const int formatCadangan = 1;

  /// Urutan tabel untuk **pemulihan**: induk lebih dulu, anak belakangan.
  ///
  /// Kebalikan dari urutan penghapusan di `DatabaseHelper.resetBusinessData()`,
  /// karena `PRAGMA foreign_keys = ON` aktif. Salah urutan = gagal kunci asing.
  static const List<String> tabelCadangan = [
    'products',
    'suppliers',
    'sales',
    'debts',
    'notes',
    'cash_transactions',
    'expenses',
    'prive',
    'stock_movements',
    'debt_payments',
    'sale_items',
    'payment_methods',
  ];

  /// Urutan **penghapusan**: anak lebih dulu, baru induk.
  ///
  /// Sama persis dengan `resetBusinessData()`. `payment_methods` sengaja tidak
  /// ikut dihapus — daftarnya sudah ada di setiap perangkat dan dipulihkan
  /// dengan cara mencocokkan `code`, bukan dengan menghapus lalu menanam ulang.
  static const List<String> urutanHapus = [
    'sale_items',
    'debt_payments',
    'stock_movements',
    'cash_transactions',
    'expenses',
    'prive',
    'sales',
    'debts',
    'notes',
    'suppliers',
    'products',
  ];

  /// Susun seluruh data usaha sebagai peta yang siap diubah jadi JSON.
  ///
  /// Semua nilai diambil apa adanya dari database, jadi angka tetap angka dan
  /// tanggal tetap teks ISO-8601. Tidak ada pembulatan atau pemformatan yang
  /// bisa mengubah nilai aslinya.
  Future<Map<String, dynamic>> susunData({required UserModel user}) async {
    final db = await DatabaseHelper.instance.database;

    final tabel = <String, List<Map<String, Object?>>>{};
    for (final nama in tabelCadangan) {
      tabel[nama] = await db.query(nama);
    }

    return {
      'aplikasi': 'TokoKu',
      'format': formatCadangan,
      'dibuat': DateTime.now().toIso8601String(),
      'toko': {
        'nama': user.storeName,
        'alamat': user.storeAddress,
        'telepon': user.storePhone,
        'logo': user.logoPath,
        'qris': user.qrisPath,
        'bankNama': user.bankName,
        'bankNomor': user.bankAccountNumber,
        'bankAtasNama': user.bankAccountName,
      },
      'jumlah': {
        for (final entry in tabel.entries) entry.key: entry.value.length,
      },
      'tabel': tabel,
    };
  }

  /// Nama berkas cadangan otomatis — sengaja tetap, lihat [createBackupJson].
  static const String namaCadanganOtomatis = 'cadangan-otomatis';

  /// Tulis berkas cadangan JSON yang bisa dibaca kembali aplikasi.
  ///
  /// Ini yang dipakai fitur "Pulihkan data". Berkas `.xlsx` dari
  /// [createBackup] tetap ada untuk dibuka di Excel, tapi tidak dipakai
  /// memulihkan karena membacanya kembali butuh penafsir ZIP/XML sendiri.
  ///
  /// Kalau [otomatis] benar, namanya sengaja TETAP (`cadangan-otomatis.json`)
  /// supaya cadangan harian saling menimpa dan tidak menumpuk ratusan berkas
  /// di penyimpanan HP. Cadangan manual tetap memakai stempel waktu, jadi
  /// beberapa salinan lama bisa disimpan berdampingan.
  Future<File> createBackupJson({
    required UserModel user,
    bool otomatis = false,
  }) async {
    final data = await susunData(user: user);
    final isi = const JsonEncoder.withIndent('  ').convert(data);
    final nama = otomatis
        ? namaCadanganOtomatis
        : ExportService.safeName(
            'cadangan-${user.storeName}-${_stempelWaktu(DateTime.now())}',
          );
    return ExportService.instance.writeJson(filename: nama, isi: isi);
  }

  /// Berkas cadangan otomatis yang ada di HP ini, atau `null` kalau belum ada.
  ///
  /// Cadangan otomatis ditulis ke folder privat aplikasi, dan pemilih berkas
  /// Android tidak bisa menampilkan folder itu. Jadi berkas ini hanya bisa
  /// dipulihkan lewat jalur ini, bukan lewat "pilih berkas".
  ///
  /// Berkasnya sengaja TIDAK dihapus setelah dipulihkan: kalau pemulihannya
  /// ternyata salah pilih, cadangan aslinya masih ada untuk dicoba lagi.
  Future<File?> cadanganOtomatis() async {
    final berkas = await ExportService.instance
        .berkasEkspor(namaCadanganOtomatis);
    return await berkas.exists() ? berkas : null;
  }

  /// Susun berkas backup dan simpan ke folder ekspor.
  Future<File> createBackup({required UserModel user}) async {
    final db = await DatabaseHelper.instance.database;

    final products = await db.query('products', orderBy: 'id ASC');
    // Cadangan harus memuat SEMUA transaksi, termasuk yang dibatalkan — kalau
    // tidak, memulihkan cadangan akan menghidupkan kembali transaksi batal
    // sebagai transaksi biasa dan laporan jadi salah setelah pemulihan.
    final sales = await db.query('sales_semua', orderBy: 'id ASC');
    final saleItems = await db.query('sale_items', orderBy: 'id ASC');
    final debts = await db.query('debts', orderBy: 'id ASC');
    final debtPayments = await db.query('debt_payments', orderBy: 'id ASC');
    final cash = await db.query(
      'cash_transactions',
      orderBy: 'date ASC, id ASC',
    );
    final expenses = await db.query('expenses', orderBy: 'date ASC, id ASC');
    final prive = await db.query('prive', orderBy: 'date ASC, id ASC');
    final stockMoves = await db.query(
      'stock_movements',
      orderBy: 'date ASC, id ASC',
    );
    final suppliers = await db.query('suppliers', orderBy: 'id ASC');
    final notes = await db.query('notes', orderBy: 'id ASC');

    // Peta bantuan supaya lembar anak bisa menampilkan nomor nota / nama
    // pihak tanpa perlu query tambahan per baris.
    final invoiceById = <int, String>{};
    for (final s in sales) {
      final id = _int(s['id']);
      if (id != null) invoiceById[id] = _teks(s['invoice_number']);
    }

    final debtById = <int, Map<String, Object?>>{};
    for (final d in debts) {
      final id = _int(d['id']);
      if (id != null) debtById[id] = d;
    }

    final sheets = <XlsxSheet>[
      _ringkasan(user, products, sales, debts, cash),
      _produk(products),
      _penjualan(sales),
      _itemPenjualan(saleItems, invoiceById),
      _hutang(debts),
      _pembayaranHutang(debtPayments, debtById),
      _kas(cash),
      _beban(expenses),
      _prive(prive),
      _riwayatStok(stockMoves),
      _supplier(suppliers),
      _catatan(notes),
    ];

    final bytes = XlsxBuilder.build(sheets);
    final nama = ExportService.safeName(
      'backup-${user.storeName}-${_stempelWaktu(DateTime.now())}',
    );

    return ExportService.instance.writeXlsx(filename: nama, bytes: bytes);
  }

  /// Nama berkas memakai tanggal & jam supaya backup lama tidak tertimpa.
  static String _stempelWaktu(DateTime dt) {
    String dua(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}${dua(dt.month)}${dua(dt.day)}-'
        '${dua(dt.hour)}${dua(dt.minute)}';
  }

  // -------------------------------------------------------------- lembar

  static XlsxSheet _ringkasan(
    UserModel user,
    List<Map<String, Object?>> products,
    List<Map<String, Object?>> sales,
    List<Map<String, Object?>> debts,
    List<Map<String, Object?>> cash,
  ) {
    var totalPenjualan = 0;
    var totalLaba = 0;
    for (final s in sales) {
      totalPenjualan += _int(s['total_amount']) ?? 0;
      totalLaba += _int(s['total_profit']) ?? 0;
    }

    var piutang = 0;
    var hutang = 0;
    for (final d in debts) {
      if (_teks(d['status']) == 'lunas') continue;
      final sisa = (_int(d['amount']) ?? 0) - (_int(d['paid_amount']) ?? 0);
      if (sisa <= 0) continue;
      if (_teks(d['type']) == 'piutang') {
        piutang += sisa;
      } else {
        hutang += sisa;
      }
    }

    var saldoKas = 0;
    for (final c in cash) {
      final jumlah = _int(c['amount']) ?? 0;
      saldoKas += _teks(c['type']) == 'in' ? jumlah : -jumlah;
    }

    final rows = <List<Object?>>[
      ['Keterangan', 'Nilai'],
      ['Nama usaha', user.storeName],
      ['Alamat', _teks(user.storeAddress)],
      ['Telepon', _teks(user.storePhone)],
      ['Email', user.email],
      ['Akun dibuat', user.createdAt.toIso8601String()],
      ['Waktu backup', DateTime.now().toIso8601String()],
      ['Jumlah produk', products.length],
      ['Jumlah transaksi', sales.length],
      ['Total penjualan', totalPenjualan],
      ['Total laba', totalLaba],
      ['Piutang belum lunas', piutang],
      ['Hutang belum lunas', hutang],
      ['Saldo kas', saldoKas],
      [
        'Catatan',
        'Kolom uang ditulis sebagai angka. Kolom tanggal memakai format '
            'ISO-8601 (YYYY-MM-DDThh:mm:ss) supaya urutannya benar.',
      ],
    ];

    return XlsxSheet(name: 'Ringkasan', rows: rows);
  }

  static XlsxSheet _produk(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Produk',
      rows: [
        [
          'ID', 'Nama', 'Kategori', 'Harga beli', 'Harga jual', 'Stok',
          'Stok minimum', 'Supplier', 'Barcode', 'Emoji', 'Dibuat', 'Diubah',
        ],
        for (final p in rows)
          [
            _int(p['id']),
            _teks(p['name']),
            _teks(p['category']),
            _int(p['cost_price']) ?? 0,
            _int(p['sell_price']) ?? 0,
            _int(p['stock']) ?? 0,
            _int(p['min_stock']) ?? 0,
            _teks(p['supplier']),
            _teks(p['barcode']),
            _teks(p['emoji']),
            _teks(p['created_at']),
            _teks(p['updated_at']),
          ],
      ],
    );
  }

  static XlsxSheet _penjualan(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Penjualan',
      rows: [
        [
          'ID', 'No nota', 'Pelanggan', 'Total', 'Laba', 'Jumlah item',
          'Metode bayar', 'Dibayar', 'Kembalian', 'Hutang?', 'Tanggal',
        ],
        for (final s in rows)
          [
            _int(s['id']),
            _teks(s['invoice_number']),
            _teks(s['customer_name']),
            _int(s['total_amount']) ?? 0,
            _int(s['total_profit']) ?? 0,
            _int(s['total_items']) ?? 0,
            _teks(s['payment_method']),
            _int(s['paid_amount']) ?? 0,
            _int(s['change_amount']) ?? 0,
            (_int(s['is_debt']) ?? 0) == 1 ? 'Ya' : 'Tidak',
            _teks(s['created_at']),
          ],
      ],
    );
  }

  static XlsxSheet _itemPenjualan(
    List<Map<String, Object?>> rows,
    Map<int, String> invoiceById,
  ) {
    return XlsxSheet(
      name: 'Item Penjualan',
      rows: [
        [
          'ID', 'No nota', 'Produk', 'Harga beli', 'Harga jual', 'Qty',
          'Subtotal', 'Laba',
        ],
        for (final i in rows)
          [
            _int(i['id']),
            invoiceById[_int(i['sale_id'])] ?? '',
            _teks(i['product_name']),
            _int(i['cost_price']) ?? 0,
            _int(i['sell_price']) ?? 0,
            _int(i['quantity']) ?? 0,
            _int(i['subtotal']) ?? 0,
            ((_int(i['sell_price']) ?? 0) - (_int(i['cost_price']) ?? 0)) *
                (_int(i['quantity']) ?? 0),
          ],
      ],
    );
  }

  static XlsxSheet _hutang(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Hutang & Piutang',
      rows: [
        [
          'ID', 'Nama', 'Telepon', 'Jenis', 'Nilai', 'Sudah dibayar', 'Sisa',
          'Status', 'Jatuh tempo', 'Catatan', 'Dibuat', 'Diubah',
        ],
        for (final d in rows)
          [
            _int(d['id']),
            _teks(d['party_name']),
            _teks(d['party_phone']),
            _teks(d['type']) == 'piutang' ? 'Piutang' : 'Hutang',
            _int(d['amount']) ?? 0,
            _int(d['paid_amount']) ?? 0,
            ((_int(d['amount']) ?? 0) - (_int(d['paid_amount']) ?? 0))
                    .clamp(0, 1 << 62)
                    .toInt(),
            _teks(d['status']) == 'lunas' ? 'Lunas' : 'Belum lunas',
            _teks(d['due_date']),
            _teks(d['note']),
            _teks(d['created_at']),
            _teks(d['updated_at']),
          ],
      ],
    );
  }

  static XlsxSheet _pembayaranHutang(
    List<Map<String, Object?>> rows,
    Map<int, Map<String, Object?>> debtById,
  ) {
    return XlsxSheet(
      name: 'Pembayaran Hutang',
      rows: [
        ['ID', 'Nama pihak', 'Jenis', 'Jumlah', 'Catatan', 'Tanggal'],
        for (final p in rows)
          [
            _int(p['id']),
            _teks(debtById[_int(p['debt_id'])]?['party_name']),
            _teks(debtById[_int(p['debt_id'])]?['type']) == 'piutang'
                ? 'Piutang'
                : 'Hutang',
            _int(p['amount']) ?? 0,
            _teks(p['note']),
            _teks(p['created_at']),
          ],
      ],
    );
  }

  static XlsxSheet _kas(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Kas',
      rows: [
        [
          'ID', 'Tanggal', 'Jenis', 'Kategori', 'Jumlah', 'Catatan', 'Sumber',
        ],
        for (final c in rows)
          [
            _int(c['id']),
            _teks(c['date']),
            _teks(c['type']) == 'in' ? 'Masuk' : 'Keluar',
            _teks(c['category']),
            _int(c['amount']) ?? 0,
            _teks(c['note']),
            _teks(c['ref_type']).isEmpty ? 'manual' : _teks(c['ref_type']),
          ],
      ],
    );
  }

  static XlsxSheet _beban(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Beban',
      rows: [
        ['ID', 'Tanggal', 'Kategori', 'Jumlah', 'Catatan'],
        for (final e in rows)
          [
            _int(e['id']),
            _teks(e['date']),
            _teks(e['category']),
            _int(e['amount']) ?? 0,
            _teks(e['note']),
          ],
      ],
    );
  }

  static XlsxSheet _prive(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Prive',
      rows: [
        ['ID', 'Tanggal', 'Jumlah', 'Catatan'],
        for (final p in rows)
          [
            _int(p['id']),
            _teks(p['date']),
            _int(p['amount']) ?? 0,
            _teks(p['note']),
          ],
      ],
    );
  }

  static XlsxSheet _riwayatStok(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Riwayat Stok',
      rows: [
        [
          'ID', 'Tanggal', 'Produk', 'Jenis', 'Jumlah', 'Total biaya',
          'Catatan', 'Sumber',
        ],
        for (final m in rows)
          [
            _int(m['id']),
            _teks(m['date']),
            _teks(m['product_name']),
            _teks(m['type']),
            _int(m['quantity']) ?? 0,
            _int(m['total_cost']) ?? 0,
            _teks(m['note']),
            _teks(m['ref_type']),
          ],
      ],
    );
  }

  static XlsxSheet _supplier(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Supplier',
      rows: [
        ['ID', 'Nama', 'Telepon', 'Alamat', 'Catatan', 'Dibuat'],
        for (final s in rows)
          [
            _int(s['id']),
            _teks(s['name']),
            _teks(s['phone']),
            _teks(s['address']),
            _teks(s['note']),
            _teks(s['created_at']),
          ],
      ],
    );
  }

  static XlsxSheet _catatan(List<Map<String, Object?>> rows) {
    return XlsxSheet(
      name: 'Catatan',
      rows: [
        ['ID', 'Judul', 'Isi', 'Disematkan', 'Dibuat', 'Diubah'],
        for (final n in rows)
          [
            _int(n['id']),
            _teks(n['title']),
            _teks(n['body']),
            (_int(n['is_pinned']) ?? 0) == 1 ? 'Ya' : 'Tidak',
            _teks(n['created_at']),
            _teks(n['updated_at']),
          ],
      ],
    );
  }

  // ------------------------------------------------------------- bantuan

  static String _teks(Object? nilai) {
    if (nilai == null) return '';
    return nilai.toString();
  }

  static int? _int(Object? nilai) {
    if (nilai is int) return nilai;
    if (nilai is num) return nilai.toInt();
    if (nilai is String) return int.tryParse(nilai);
    return null;
  }
}
