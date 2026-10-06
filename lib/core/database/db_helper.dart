import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('omnipos_local.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Tabel Local Tenant & Auth Session
    await db.execute('''
      CREATE TABLE local_tenant (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT NOT NULL,
        plan TEXT NOT NULL DEFAULT 'FREE',
        plan_status TEXT,
        owner_name TEXT,
        branch_id TEXT,
        branch_name TEXT,
        token TEXT,
        logo_url TEXT,
        receipt_show_logo INTEGER DEFAULT 1,
        rounding_mode INTEGER DEFAULT 0,
        printer_width INTEGER DEFAULT 58,
        receipt_font_size TEXT DEFAULT 'NORMAL',
        updated_at TEXT
      )
    ''');

    // 2. Tabel Kategori Menu
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        sync_status TEXT DEFAULT 'PENDING',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 3. Tabel Produk
    await db.execute('''
      CREATE TABLE products (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        category_id TEXT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        cost_price REAL DEFAULT 0,
        image_url TEXT,
        is_active INTEGER DEFAULT 1,
        sync_status TEXT DEFAULT 'PENDING',
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    // 4. Tabel Shift Kasir
    await db.execute('''
      CREATE TABLE shifts (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        branch_id TEXT,
        cashier_name TEXT NOT NULL,
        starting_cash REAL NOT NULL,
        cash_sales REAL DEFAULT 0,
        non_cash_sales REAL DEFAULT 0,
        total_sales REAL DEFAULT 0,
        total_transactions INTEGER DEFAULT 0,
        closing_cash REAL,
        actual_cash REAL,
        discrepancy REAL,
        status TEXT DEFAULT 'OPEN',
        started_at TEXT NOT NULL,
        ended_at TEXT,
        sync_status TEXT DEFAULT 'PENDING'
      )
    ''');

    // 5. Tabel Pelanggan
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        address TEXT,
        notes TEXT,
        sync_status TEXT DEFAULT 'PENDING',
        created_at TEXT
      )
    ''');

    // 6. Tabel Kupon & Promo Diskon
    await db.execute('''
      CREATE TABLE promotions (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        name TEXT NOT NULL,
        code TEXT NOT NULL,
        discount_type TEXT NOT NULL,
        discount_value REAL NOT NULL,
        min_order_amount REAL DEFAULT 0,
        max_discount_amount REAL,
        is_active INTEGER DEFAULT 1,
        sync_status TEXT DEFAULT 'PENDING'
      )
    ''');

    // 7. Tabel Keranjang Tersimpan (Hold Cart)
    await db.execute('''
      CREATE TABLE held_carts (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        label TEXT NOT NULL,
        cart_json TEXT NOT NULL,
        customer_name TEXT,
        total_amount REAL NOT NULL,
        total_items INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // 8. Tabel Transaksi Penjualan
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        tenant_id TEXT NOT NULL,
        branch_id TEXT,
        shift_id TEXT,
        customer_id TEXT,
        receipt_number TEXT NOT NULL,
        customer_name TEXT,
        customer_phone TEXT,
        total_amount REAL NOT NULL,
        discount_amount REAL DEFAULT 0,
        promo_code TEXT,
        cash_paid REAL NOT NULL,
        change_amount REAL NOT NULL,
        payment_method TEXT DEFAULT 'CASH',
        sync_status TEXT DEFAULT 'PENDING',
        created_at TEXT
      )
    ''');

    // 9. Tabel Item Transaksi
    await db.execute('''
      CREATE TABLE transaction_items (
        id TEXT PRIMARY KEY,
        transaction_id TEXT NOT NULL,
        product_id TEXT,
        product_name TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        notes TEXT,
        FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shifts (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          branch_id TEXT,
          cashier_name TEXT NOT NULL,
          starting_cash REAL NOT NULL,
          cash_sales REAL DEFAULT 0,
          non_cash_sales REAL DEFAULT 0,
          total_sales REAL DEFAULT 0,
          total_transactions INTEGER DEFAULT 0,
          closing_cash REAL,
          actual_cash REAL,
          discrepancy REAL,
          status TEXT DEFAULT 'OPEN',
          started_at TEXT NOT NULL,
          ended_at TEXT,
          sync_status TEXT DEFAULT 'PENDING'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          name TEXT NOT NULL,
          phone TEXT,
          email TEXT,
          address TEXT,
          notes TEXT,
          sync_status TEXT DEFAULT 'PENDING',
          created_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS promotions (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          name TEXT NOT NULL,
          code TEXT NOT NULL,
          discount_type TEXT NOT NULL,
          discount_value REAL NOT NULL,
          min_order_amount REAL DEFAULT 0,
          max_discount_amount REAL,
          is_active INTEGER DEFAULT 1,
          sync_status TEXT DEFAULT 'PENDING'
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS held_carts (
          id TEXT PRIMARY KEY,
          tenant_id TEXT NOT NULL,
          label TEXT NOT NULL,
          cart_json TEXT NOT NULL,
          customer_name TEXT,
          total_amount REAL NOT NULL,
          total_items INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN shift_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN customer_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN discount_amount REAL DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN promo_code TEXT');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE local_tenant ADD COLUMN logo_url TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_tenant ADD COLUMN receipt_show_logo INTEGER DEFAULT 1');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_tenant ADD COLUMN rounding_mode INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_tenant ADD COLUMN printer_width INTEGER DEFAULT 58');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE local_tenant ADD COLUMN receipt_font_size TEXT DEFAULT "NORMAL"');
      } catch (_) {}
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
