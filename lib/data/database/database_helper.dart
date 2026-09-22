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
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'tokoku.db';
  static const _dbVersion = 2;

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

  /// Migrasi dari versi lama. Data yang sudah ada tidak boleh hilang.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createV2Tables(db);
      await _addColumnIfMissing(db, 'users', 'store_phone', 'TEXT');
      await _addColumnIfMissing(db, 'users', 'logo_path', 'TEXT');
      await _seedPaymentMethods(db);
    }
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
