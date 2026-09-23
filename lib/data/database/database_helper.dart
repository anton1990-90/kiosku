import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// SQLite database helper — the backbone of offline-first architecture.
/// All data is stored locally: users, products, sales, debts, notes,
/// suppliers, payment methods. No internet required after initial setup.
///
/// Riwayat versi:
///   1 — users, products, sales, sale_items
///   2 — + debts, debt_payments, notes, suppliers, payment_methods,
///       kolom store_phone & logo_path pada users
///   3 — + cash_transactions (kas), expenses (beban), prive,
///       stock_movements (riwayat stok), kolom penghubung hutang↔penjualan
///       dan hutang↔produk
///   4 — + kolom pembayaran pada users: qris_path (gambar QRIS),
///       bank_name, bank_account_number, bank_account_name
///   5 — + kolom pada products: unit (satuan: pcs, kg, liter, …) dan
///       photo_path (foto barang dari galeri; emoji tetap jadi cadangan),
///       serta sale_items.unit (satuan yang direkam saat barang terjual)
///   6 — + kolom diskon: sales.discount (potongan nota) dan
///       sale_items.discount (potongan per baris). Sejak versi ini
///       `sale_items.subtotal` menyimpan harga SETELAH potongan baris, dan
///       `sales.total_amount` adalah jumlah yang benar-benar dibayar.
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'tokoku.db';
  static const _dbVersion = 6;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  // ---------------------------------------------------------------- create

  Future<void> _onCreate(Database db, int version) async {
    await _createBaseTables(db);
    await _createV2Tables(db);
    await _createV3Tables(db);
    await _upgradeV4(db);
    await _upgradeV5(db);
    await _upgradeV6(db);
    await _seedProducts(db);
    await _seedPaymentMethods(db);
  }

  /// Tabel versi 1.
  Future<void> _createBaseTables(Database db) async {
    // Users table — email-based authentication + info toko
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        store_name TEXT NOT NULL,
        store_address TEXT,
        store_phone TEXT,
        logo_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Products table
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        cost_price INTEGER NOT NULL,
        sell_price INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 5,
        supplier TEXT,
        emoji TEXT DEFAULT '📦',
        barcode TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Sales (transactions) table
    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_number TEXT NOT NULL,
        user_id INTEGER NOT NULL,
        customer_name TEXT,
        total_amount INTEGER NOT NULL,
        total_profit INTEGER NOT NULL,
        total_items INTEGER NOT NULL,
        payment_method TEXT NOT NULL DEFAULT 'tunai',
        paid_amount INTEGER NOT NULL,
        change_amount INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');

    // Sale items (line items per transaction)
    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        cost_price INTEGER NOT NULL,
        sell_price INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal INTEGER NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_sales_created_at ON sales(created_at)',
    );
    await db.execute(
      'CREATE INDEX idx_sale_items_sale_id ON sale_items(sale_id)',
    );
  }

  /// Tabel versi 2 — hutang, catatan, supplier, metode pembayaran.
  Future<void> _createV2Tables(Database db) async {
    // Suppliers — data pemasok yang bisa diedit
    await db.execute('''
      CREATE TABLE suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        address TEXT,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Payment methods — bisa diaktifkan/dinonaktifkan pengguna
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Debts — piutang pelanggan & hutang ke supplier
    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        party_name TEXT NOT NULL,
        party_phone TEXT,
        type TEXT NOT NULL DEFAULT 'piutang',
        amount INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'belum_lunas',
        supplier_id INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_debts_status ON debts(status, type)',
    );

    // Debt payments — riwayat pembayaran cicilan
    await db.execute('''
      CREATE TABLE debt_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        debt_id INTEGER NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (debt_id) REFERENCES debts(id) ON DELETE CASCADE
      )
    ''');

    // Notes — catatan bebas untuk pemilik toko
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        body TEXT,
        color TEXT NOT NULL DEFAULT 'teal',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  // --------------------------------------------------------------- upgrade

  /// Tabel versi 3 — kas, beban, prive, dan riwayat stok.
  ///
  /// Semua `CREATE TABLE` memakai `IF NOT EXISTS` supaya aman dijalankan
  /// berkali-kali (baik dari `onCreate` maupun `onUpgrade`).
  Future<void> _createV3Tables(Database db) async {
    // Kas — setiap uang masuk dan keluar dari toko.
    // `date` disimpan ISO-8601 supaya bisa difilter per hari/bulan.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category TEXT NOT NULL,
        note TEXT,
        ref_type TEXT,
        ref_id INTEGER,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_date ON cash_transactions(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cash_type ON cash_transactions(type, date)',
    );

    // Beban operasional — dipakai untuk menyusun laporan laba rugi.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        amount INTEGER NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(date)',
    );

    // Prive — pengambilan uang toko oleh pemilik (bukan beban usaha).
    await db.execute('''
      CREATE TABLE IF NOT EXISTS prive (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount INTEGER NOT NULL,
        note TEXT,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_prive_date ON prive(date)',
    );

    // Riwayat keluar-masuk stok — jejak setiap penambahan/pengurangan.
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        total_cost INTEGER NOT NULL DEFAULT 0,
        note TEXT,
        ref_type TEXT,
        ref_id INTEGER,
        date TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_mov_date ON stock_movements(date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stock_mov_product '
      'ON stock_movements(product_id, date)',
    );

    // Kolom penghubung. Ditambahkan di sini supaya tabel versi 1 & 2 tetap
    // utuh dan tidak ada data lama yang perlu ditulis ulang.
    await _addColumnIfMissing(db, 'sales', 'is_debt', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sales', 'debt_id', 'INTEGER');
    await _addColumnIfMissing(db, 'debts', 'sale_id', 'INTEGER');
    await _addColumnIfMissing(db, 'debts', 'product_id', 'INTEGER');
  }

  /// Kolom versi 4 — data pembayaran non-tunai milik toko.
  ///
  /// Dipakai supaya saat pelanggan membayar dengan QRIS atau transfer bank,
  /// gambar QRIS dan nomor rekening toko bisa ditampilkan di kasir dan struk.
  Future<void> _upgradeV4(Database db) async {
    await _addColumnIfMissing(db, 'users', 'qris_path', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'bank_name', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'bank_account_number', 'TEXT');
    await _addColumnIfMissing(db, 'users', 'bank_account_name', 'TEXT');
  }

  /// Kolom versi 5 — satuan dan foto barang.
  ///
  /// `unit` dipakai supaya struk menulis "2 kg" dan bukan sekadar "2". Nilai
  /// awalnya `pcs` supaya produk lama tetap punya satuan yang masuk akal.
  ///
  /// `photo_path` menyimpan path foto barang yang dipilih dari galeri. Kalau
  /// kosong, tampilan kembali memakai `emoji` — jadi produk lama tidak perlu
  /// disunting satu per satu.
  ///
  /// `sale_items.unit` merekam satuan **saat barang terjual**, bukan dibaca
  /// ulang dari tabel `products`. Dengan begitu struk lama tetap benar
  /// walaupun pemilik mengganti satuan produknya kemudian — perlakuan yang
  /// sama dengan `cost_price` dan `sell_price` di tabel yang sama.
  ///
  /// Semuanya ditambahkan lewat `_addColumnIfMissing`, jadi `CREATE TABLE
  /// products` dan `CREATE TABLE sale_items` tidak berubah dan data yang sudah
  /// ada di HP pelanggan aman.
  Future<void> _upgradeV5(Database db) async {
    await _addColumnIfMissing(db, 'products', 'unit', "TEXT NOT NULL DEFAULT 'pcs'");
    await _addColumnIfMissing(db, 'products', 'photo_path', 'TEXT');
    await _addColumnIfMissing(db, 'sale_items', 'unit', "TEXT NOT NULL DEFAULT 'pcs'");
  }

  /// Kolom versi 6 — potongan harga.
  ///
  /// Dua tingkat, karena begitulah cara toko sungguhan berjualan:
  ///   * `sale_items.discount` — potongan per barang ("beli 2 kurang 500")
  ///   * `sales.discount`      — potongan seluruh nota ("borongan kurang 2000")
  ///
  /// Nilainya rupiah, bukan persen: pemilik toko menyebut potongan dalam
  /// rupiah, dan persen menuntut pembulatan yang bisa bikin total tidak cocok
  /// dengan uang yang benar-benar diterima.
  ///
  /// Sejak versi ini `sale_items.subtotal` adalah harga **setelah** potongan
  /// barisnya, dan `sales.total_amount` adalah jumlah yang benar-benar
  /// dibayar. Dengan begitu seluruh laporan yang membaca `total_amount`
  /// otomatis ikut benar tanpa perlu diubah.
  Future<void> _upgradeV6(Database db) async {
    await _addColumnIfMissing(db, 'sales', 'discount', 'INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'sale_items', 'discount', 'INTEGER NOT NULL DEFAULT 0');
  }

  /// Migrasi dari versi lama. Data yang sudah ada tidak boleh hilang.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
      await _addColumnIfMissing(db, 'users', 'store_phone', 'TEXT');
      await _addColumnIfMissing(db, 'users', 'logo_path', 'TEXT');
      await _seedPaymentMethods(db);
    }
    if (oldVersion < 3) {
      await _createV3Tables(db);
    }
    if (oldVersion < 4) {
      await _upgradeV4(db);
    }
    if (oldVersion < 5) {
      await _upgradeV5(db);
    }
    if (oldVersion < 6) {
      await _upgradeV6(db);
    }
  }

  /// Hapus seluruh data usaha — produk, penjualan, hutang, kas, beban,
  /// prive, catatan, supplier, dan riwayat stok.
  ///
  /// Dipakai oleh menu "Reset semua data" di Profil. Akun pengguna dan
  /// profil toko (nama, alamat, logo, QRIS, rekening) **tidak** dihapus, dan
  /// daftar metode pembayaran tetap ada supaya kasir langsung bisa dipakai.
  ///
  /// Urutan penghapusan mengikuti foreign key — baris anak dulu, baru induk,
  /// karena `PRAGMA foreign_keys = ON` aktif.
  Future<void> resetBusinessData() async {
    final db = await database;

    const urutan = [
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

    await db.transaction((txn) async {
      for (final table in urutan) {
        await txn.delete(table);
      }

      // Nomor id kembali mulai dari 1, seperti aplikasi yang baru dipasang.
      final adaSequence = await txn.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name = 'sqlite_sequence'",
      );
      if (adaSequence.isNotEmpty) {
        for (final table in urutan) {
          await txn.delete(
            'sqlite_sequence',
            where: 'name = ?',
            whereArgs: [table],
          );
        }
      }
    });
  }

  /// `ALTER TABLE ... ADD COLUMN` gagal kalau kolom sudah ada, jadi dicek dulu.
  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String column,
    String type,
  ) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type');
    }
  }

  // ----------------------------------------------------------------- seeds

  Future<void> _seedPaymentMethods(Database db) async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM payment_methods'),
    );
    if ((count ?? 0) > 0) return;

    const methods = [
      ['tunai', 'Tunai', 1],
      ['qris', 'QRIS', 2],
      ['transfer', 'Transfer Bank', 3],
      ['ewallet', 'E-Wallet', 4],
    ];
    for (final m in methods) {
      await db.insert('payment_methods', {
        'code': m[0],
        'name': m[1],
        'is_active': 1,
        'sort_order': m[2],
      });
    }
  }

  Future<void> _seedProducts(Database db) async {
    final now = DateTime.now().toIso8601String();
    final products = [
      ['Beras Premium 5kg', 'Sembako', 55000, 65000, 24, 5, 'PT Cap Ayam', '🍚', '8991002101234'],
      ['Minyak Goreng 2L', 'Sembako', 32000, 38000, 12, 5, 'PT Indofood', '🛢️', '8991002101235'],
      ['Gula Pasir 1kg', 'Sembako', 13000, 16000, 3, 5, 'PT Indofood', '🧂', '8991002101236'],
      ['Telur Ayam 1kg', 'Sembako', 24000, 28000, 18, 5, null, '🥚', '8991002101237'],
      ['Mie Instan (isi 10)', 'Snack', 28000, 34000, 40, 10, 'PT Indofood', '🍜', '8991002101238'],
      ['Kopi Sachet (isi 10)', 'Minuman', 14000, 18000, 22, 5, null, '☕', '8991002101239'],
      ['Susu Kental Manis', 'Minuman', 9000, 11000, 15, 5, null, '🥛', '8991002101240'],
      ['Sabun Mandi', 'Kebutuhan', 3500, 4500, 0, 10, 'PT Unilever', '🧴', '8991002101241'],
      ['Mentega 200g', 'Kebutuhan', 12000, 14500, 2, 5, 'PT Blue Band', '🧈', '8991002101242'],
      ['Garam 1kg', 'Sembako', 3000, 4500, 20, 5, null, '🧂', '8991002101243'],
      ['Tepung Terigu 1kg', 'Sembako', 10000, 13000, 8, 5, null, '🌾', '8991002101244'],
      ['Air Mineral 600ml', 'Minuman', 2000, 3500, 50, 10, null, '💧', '8991002101245'],
    ];

    for (final p in products) {
      await db.insert('products', {
        'name': p[0] as String,
        'category': p[1] as String,
        'cost_price': p[2] as int,
        'sell_price': p[3] as int,
        'stock': p[4] as int,
        'min_stock': p[5] as int,
        'supplier': p[6],
        'emoji': p[7] as String,
        'barcode': p[8] as String,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
