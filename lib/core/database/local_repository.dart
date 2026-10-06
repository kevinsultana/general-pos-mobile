import 'package:sqflite/sqflite.dart';
import '../models/category_model.dart';
import '../models/customer_model.dart';
import '../models/held_cart_model.dart';
import '../models/product_model.dart';
import '../models/promotion_model.dart';
import '../models/shift_model.dart';
import '../models/tenant_model.dart';
import '../models/transaction_model.dart';
import 'db_helper.dart';

class LocalRepository {
  final DbHelper _dbHelper = DbHelper.instance;

  // ================= TENANT / SESSION =================
  Future<TenantModel?> getActiveTenant() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('local_tenant', limit: 1);
    if (maps.isEmpty) return null;
    return TenantModel.fromMap(maps.first);
  }

  Future<void> saveOrUpdateTenant(TenantModel tenant) async {
    final db = await _dbHelper.database;
    await db.insert(
      'local_tenant',
      tenant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTenantPlan(String tenantId, String plan, String? status) async {
    final db = await _dbHelper.database;
    await db.update(
      'local_tenant',
      {
        'plan': plan,
        'plan_status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tenantId],
    );
  }

  Future<void> clearSession() async {
    final db = await _dbHelper.database;
    await db.delete('local_tenant');
  }

  // ================= SHIFTS =================
  Future<ShiftModel?> getActiveShift(String tenantId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'shifts',
      where: 'tenant_id = ? AND status = ?',
      whereArgs: [tenantId, 'OPEN'],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ShiftModel.fromMap(maps.first);
  }

  Future<void> startShift(ShiftModel shift) async {
    final db = await _dbHelper.database;
    await db.insert('shifts', shift.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateShiftSales({
    required String shiftId,
    required double totalAmount,
    required bool isCash,
  }) async {
    final db = await _dbHelper.database;
    if (isCash) {
      await db.rawUpdate('''
        UPDATE shifts
        SET cash_sales = cash_sales + ?,
            total_sales = total_sales + ?,
            total_transactions = total_transactions + 1
        WHERE id = ?
      ''', [totalAmount, totalAmount, shiftId]);
    } else {
      await db.rawUpdate('''
        UPDATE shifts
        SET non_cash_sales = non_cash_sales + ?,
            total_sales = total_sales + ?,
            total_transactions = total_transactions + 1
        WHERE id = ?
      ''', [totalAmount, totalAmount, shiftId]);
    }
  }

  Future<void> closeShift({
    required String shiftId,
    required double actualCash,
    required double closingCash,
    required double discrepancy,
  }) async {
    final db = await _dbHelper.database;
    await db.update(
      'shifts',
      {
        'status': 'CLOSED',
        'actual_cash': actualCash,
        'closing_cash': closingCash,
        'discrepancy': discrepancy,
        'ended_at': DateTime.now().toIso8601String(),
        'sync_status': 'PENDING',
      },
      where: 'id = ?',
      whereArgs: [shiftId],
    );
  }

  Future<List<ShiftModel>> getShifts(String tenantId, {int limit = 30}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'shifts',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return maps.map((m) => ShiftModel.fromMap(m)).toList();
  }

  // ================= CATEGORIES =================
  Future<List<CategoryModel>> getCategories(String tenantId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'sort_order ASC, name ASC',
    );
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<void> insertCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.insert('categories', category.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateCategory(CategoryModel category) async {
    final db = await _dbHelper.database;
    await db.update('categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await _dbHelper.database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
    await db.update('products', {'category_id': null}, where: 'category_id = ?', whereArgs: [categoryId]);
  }

  // ================= PRODUCTS =================
  Future<List<ProductModel>> getProducts(String tenantId, {String? categoryId}) async {
    final db = await _dbHelper.database;
    String where = 'tenant_id = ?';
    List<dynamic> whereArgs = [tenantId];

    if (categoryId != null && categoryId.isNotEmpty && categoryId != 'ALL') {
      where += ' AND category_id = ?';
      whereArgs.add(categoryId);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<ProductModel?> getProductById(String productId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProductModel.fromMap(maps.first);
  }

  Future<void> insertProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    await db.insert('products', product.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateProduct(ProductModel product) async {
    final db = await _dbHelper.database;
    await db.update('products', product.toMap(), where: 'id = ?', whereArgs: [product.id]);
  }

  Future<void> deleteProduct(String productId) async {
    final db = await _dbHelper.database;
    await db.delete('products', where: 'id = ?', whereArgs: [productId]);
  }

  // ================= CUSTOMERS =================
  Future<List<CustomerModel>> getCustomers(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'customers',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => CustomerModel.fromMap(m)).toList();
  }

  Future<void> insertCustomer(CustomerModel customer) async {
    final db = await _dbHelper.database;
    await db.insert('customers', customer.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteCustomer(String customerId) async {
    final db = await _dbHelper.database;
    await db.delete('customers', where: 'id = ?', whereArgs: [customerId]);
  }

  // ================= PROMOTIONS =================
  Future<List<PromotionModel>> getPromotions(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'promotions',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'name ASC',
    );
    return maps.map((m) => PromotionModel.fromMap(m)).toList();
  }

  Future<PromotionModel?> getPromoByCode(String tenantId, String code) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'promotions',
      where: 'tenant_id = ? AND UPPER(code) = ? AND is_active = 1',
      whereArgs: [tenantId, code.toUpperCase().trim()],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PromotionModel.fromMap(maps.first);
  }

  Future<void> insertPromotion(PromotionModel promo) async {
    final db = await _dbHelper.database;
    await db.insert('promotions', promo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePromotion(String promoId) async {
    final db = await _dbHelper.database;
    await db.delete('promotions', where: 'id = ?', whereArgs: [promoId]);
  }

  // ================= HELD CARTS =================
  Future<List<HeldCartModel>> getHeldCarts(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'held_carts',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => HeldCartModel.fromMap(m)).toList();
  }

  Future<void> saveHeldCart(HeldCartModel heldCart) async {
    final db = await _dbHelper.database;
    await db.insert('held_carts', heldCart.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteHeldCart(String heldCartId) async {
    final db = await _dbHelper.database;
    await db.delete('held_carts', where: 'id = ?', whereArgs: [heldCartId]);
  }

  // ================= TRANSACTIONS =================
  Future<void> createTransaction(TransactionModel transaction, List<TransactionItemModel> items) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('transactions', transaction.toMap());
      for (final item in items) {
        await txn.insert('transaction_items', item.toMap());
      }
    });

    // Update active shift if present
    if (transaction.shiftId != null) {
      await updateShiftSales(
        shiftId: transaction.shiftId!,
        totalAmount: transaction.totalAmount,
        isCash: transaction.paymentMethod == 'CASH',
      );
    }
  }

  Future<List<TransactionModel>> getTransactions(String tenantId, {int limit = 50}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'transactions',
      where: 'tenant_id = ?',
      whereArgs: [tenantId],
      orderBy: 'created_at DESC',
      limit: limit,
    );

    List<TransactionModel> results = [];
    for (final map in maps) {
      final String trxId = map['id'] as String;
      final List<Map<String, dynamic>> itemMaps = await db.query(
        'transaction_items',
        where: 'transaction_id = ?',
        whereArgs: [trxId],
      );
      final items = itemMaps.map((im) => TransactionItemModel.fromMap(im)).toList();
      results.add(TransactionModel.fromMap(map, items: items));
    }
    return results;
  }

  // ================= DASHBOARD & ANALYTICS =================
  Future<Map<String, dynamic>> getDashboardMetrics(String tenantId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Total Penjualan Hari Ini
    final todaySalesResult = await db.rawQuery('''
      SELECT SUM(total_amount) as total_sales, COUNT(id) as total_trx,
             SUM(CASE WHEN payment_method = 'CASH' THEN total_amount ELSE 0 END) as cash_sales,
             SUM(CASE WHEN payment_method != 'CASH' THEN total_amount ELSE 0 END) as non_cash_sales
      FROM transactions
      WHERE tenant_id = ? AND created_at LIKE ?
    ''', [tenantId, '$todayStr%']);

    final totalSales = (todaySalesResult.first['total_sales'] as num?)?.toDouble() ?? 0;
    final totalTrx = (todaySalesResult.first['total_trx'] as num?)?.toInt() ?? 0;
    final cashSales = (todaySalesResult.first['cash_sales'] as num?)?.toDouble() ?? 0;
    final nonCashSales = (todaySalesResult.first['non_cash_sales'] as num?)?.toDouble() ?? 0;

    // Top 5 Produk Terlaris
    final topProductsResult = await db.rawQuery('''
      SELECT ti.product_name, SUM(ti.quantity) as total_qty, SUM(ti.subtotal) as total_revenue
      FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.tenant_id = ?
      GROUP BY ti.product_name
      ORDER BY total_qty DESC
      LIMIT 5
    ''', [tenantId]);

    final activeShift = await getActiveShift(tenantId);

    return {
      'totalSales': totalSales,
      'totalTrx': totalTrx,
      'cashSales': cashSales,
      'nonCashSales': nonCashSales,
      'topProducts': topProductsResult,
      'activeShift': activeShift,
    };
  }

  // ================= SYNC HELPERS =================
  Future<List<CategoryModel>> getPendingCategories(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('categories', where: 'tenant_id = ? AND sync_status = ?', whereArgs: [tenantId, 'PENDING']);
    return maps.map((m) => CategoryModel.fromMap(m)).toList();
  }

  Future<List<ProductModel>> getPendingProducts(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('products', where: 'tenant_id = ? AND sync_status = ?', whereArgs: [tenantId, 'PENDING']);
    return maps.map((m) => ProductModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getPendingTransactions(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('transactions', where: 'tenant_id = ? AND sync_status = ?', whereArgs: [tenantId, 'PENDING']);
    List<TransactionModel> results = [];
    for (final map in maps) {
      final String trxId = map['id'] as String;
      final itemMaps = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
      final items = itemMaps.map((im) => TransactionItemModel.fromMap(im)).toList();
      results.add(TransactionModel.fromMap(map, items: items));
    }
    return results;
  }

  Future<List<TransactionItemModel>> getPendingTransactionItems(String tenantId) async {
    final db = await _dbHelper.database;
    final itemMaps = await db.rawQuery('''
      SELECT ti.* FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.tenant_id = ? AND t.sync_status = 'PENDING'
    ''', [tenantId]);
    return itemMaps.map((im) => TransactionItemModel.fromMap(im)).toList();
  }

  Future<List<ShiftModel>> getPendingShifts(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('shifts', where: 'tenant_id = ? AND sync_status = ?', whereArgs: [tenantId, 'PENDING']);
    return maps.map((m) => ShiftModel.fromMap(m)).toList();
  }

  Future<List<ShiftModel>> getAllShifts(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('shifts', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'started_at DESC');
    return maps.map((m) => ShiftModel.fromMap(m)).toList();
  }

  Future<List<TransactionModel>> getAllTransactions(String tenantId) async {
    final db = await _dbHelper.database;
    final maps = await db.query('transactions', where: 'tenant_id = ?', whereArgs: [tenantId], orderBy: 'created_at DESC');
    List<TransactionModel> results = [];
    for (final map in maps) {
      final String trxId = map['id'] as String;
      final itemMaps = await db.query('transaction_items', where: 'transaction_id = ?', whereArgs: [trxId]);
      final items = itemMaps.map((im) => TransactionItemModel.fromMap(im)).toList();
      results.add(TransactionModel.fromMap(map, items: items));
    }
    return results;
  }

  Future<List<TransactionItemModel>> getAllTransactionItems(String tenantId) async {
    final db = await _dbHelper.database;
    final itemMaps = await db.rawQuery('''
      SELECT ti.* FROM transaction_items ti
      JOIN transactions t ON ti.transaction_id = t.id
      WHERE t.tenant_id = ?
    ''', [tenantId]);
    return itemMaps.map((im) => TransactionItemModel.fromMap(im)).toList();
  }

  Future<int> getPendingSyncCount(String tenantId) async {
    final db = await _dbHelper.database;
    final trxCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM transactions WHERE tenant_id = ? AND sync_status = 'PENDING'",
      [tenantId],
    )) ?? 0;
    final shiftCount = Sqflite.firstIntValue(await db.rawQuery(
      "SELECT COUNT(*) FROM shifts WHERE tenant_id = ? AND sync_status = 'PENDING'",
      [tenantId],
    )) ?? 0;
    return trxCount + shiftCount;
  }

  Future<void> markCategoriesSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE categories SET sync_status = "SYNCED" WHERE id IN (${ids.map((_) => '?').join(',')})', ids);
  }

  Future<void> markProductsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE products SET sync_status = "SYNCED" WHERE id IN (${ids.map((_) => '?').join(',')})', ids);
  }

  Future<void> markTransactionsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE transactions SET sync_status = "SYNCED" WHERE id IN (${ids.map((_) => '?').join(',')})', ids);
  }

  Future<void> markShiftsSynced(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _dbHelper.database;
    await db.rawUpdate('UPDATE shifts SET sync_status = "SYNCED" WHERE id IN (${ids.map((_) => '?').join(',')})', ids);
  }
}
