import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables/store_tables.dart';
import 'tables/category_tables.dart';
import 'tables/product_tables.dart';
import 'tables/inventory_tables.dart';
import 'tables/customer_tables.dart';
import 'tables/transaction_tables.dart';
import 'tables/payment_tables.dart';
import 'tables/refund_tables.dart';
import 'tables/promotion_tables.dart';
import 'tables/printer_tables.dart';
import 'tables/sync_tables.dart';
import 'tables/user_tables.dart';

export '../../domain/models/promotion_ext.dart';

import 'daos/store_dao.dart';
import 'daos/category_dao.dart';
import 'daos/product_dao.dart';
import 'daos/stock_movement_dao.dart';
import 'daos/transaction_dao.dart';
import 'daos/payment_dao.dart';
import 'daos/customer_dao.dart';
import 'daos/promotion_dao.dart';
import 'daos/report_dao.dart';
import 'daos/printer_dao.dart';
import 'daos/sync_event_dao.dart';
import 'daos/user_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Stores,
    Categories,
    Products,
    ProductVariants,
    StockMovements,
    Customers,
    Promotions,
    Transactions,
    TransactionItems,
    Payments,
    PaymentMethods,
    Refunds,
    RefundItems,
    Printers,
    SyncEvents,
    SyncCursors,
    Users,
  ],
  daos: [
    StoreDao,
    CategoryDao,
    ProductDao,
    StockMovementDao,
    TransactionDao,
    PaymentDao,
    CustomerDao,
    PromotionDao,
    ReportDao,
    PrinterDao,
    SyncEventDao,
    UserDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection('local.sqlite'));

  /// Named constructor for Local mode database (local.sqlite).
  AppDatabase.openLocal() : super(_openConnection('local.sqlite'));

  /// Named constructor for Cloud mode database (cloud_cache.sqlite).
  /// Strictly isolated from local.sqlite.
  AppDatabase.openCloudCache() : super(_openConnection('cloud_cache.sqlite'));

  /// Constructor for in-memory database used in unit/integration tests
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await customStatement('''
              CREATE TABLE IF NOT EXISTS "promotions" (
                "id" TEXT NOT NULL PRIMARY KEY,
                "store_id" TEXT NOT NULL,
                "name" TEXT NOT NULL,
                "code" TEXT,
                "discount_type" TEXT NOT NULL,
                "discount_value" INTEGER NOT NULL,
                "min_spend" INTEGER NOT NULL DEFAULT 0,
                "start_date" INTEGER,
                "end_date" INTEGER,
                "product_id" TEXT,
                "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
                "created_at" INTEGER NOT NULL,
                "updated_at" INTEGER NOT NULL
              );
            ''');
          }
          if (from < 3) {
            try {
              await m.addColumn(transactions, transactions.refundedAt);
            } catch (_) {}
          }
          if (from < 4) {
            final storeColumns = [
              'ALTER TABLE "stores" ADD COLUMN "cash_rounding_enabled" INTEGER NOT NULL DEFAULT 0;',
              'ALTER TABLE "stores" ADD COLUMN "cash_rounding_increment" INTEGER NOT NULL DEFAULT 100;',
              'ALTER TABLE "stores" ADD COLUMN "cash_rounding_mode" TEXT NOT NULL DEFAULT \'ROUND_NEAREST\';',
              'ALTER TABLE "stores" ADD COLUMN "subscription_plan" TEXT NOT NULL DEFAULT \'PRO\';',
              'ALTER TABLE "stores" ADD COLUMN "subscription_status" TEXT NOT NULL DEFAULT \'ACTIVE\';',
              'ALTER TABLE "stores" ADD COLUMN "subscription_expires_at" INTEGER;',
            ];
            for (final sql in storeColumns) {
              try {
                await customStatement(sql);
              } catch (_) {}
            }
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');

          // Self-healing: ensure refunded_at & rounding_amount column exist in transactions
          try {
            await customStatement('ALTER TABLE "transactions" ADD COLUMN "refunded_at" INTEGER;');
          } catch (_) {}
          try {
            await customStatement('ALTER TABLE "transactions" ADD COLUMN "rounding_amount" INTEGER NOT NULL DEFAULT 0;');
          } catch (_) {}

          // Self-healing: ensure all columns in stores exist and have non-null values
          final storeColumnAlters = [
            'ALTER TABLE "stores" ADD COLUMN "cash_rounding_enabled" INTEGER NOT NULL DEFAULT 0;',
            'ALTER TABLE "stores" ADD COLUMN "cash_rounding_increment" INTEGER NOT NULL DEFAULT 100;',
            'ALTER TABLE "stores" ADD COLUMN "cash_rounding_mode" TEXT NOT NULL DEFAULT \'ROUND_NEAREST\';',
            'ALTER TABLE "stores" ADD COLUMN "subscription_plan" TEXT NOT NULL DEFAULT \'PRO\';',
            'ALTER TABLE "stores" ADD COLUMN "subscription_status" TEXT NOT NULL DEFAULT \'ACTIVE\';',
            'ALTER TABLE "stores" ADD COLUMN "subscription_expires_at" INTEGER;',
          ];
          for (final sql in storeColumnAlters) {
            try {
              await customStatement(sql);
            } catch (_) {}
          }

          // Backfill any NULL values in existing store records to prevent null check errors
          try {
            await customStatement("UPDATE \"stores\" SET \"subscription_plan\" = 'PRO' WHERE \"subscription_plan\" IS NULL;");
          } catch (_) {}
          try {
            await customStatement("UPDATE \"stores\" SET \"subscription_status\" = 'ACTIVE' WHERE \"subscription_status\" IS NULL;");
          } catch (_) {}
          try {
            await customStatement("UPDATE \"stores\" SET \"cash_rounding_enabled\" = 0 WHERE \"cash_rounding_enabled\" IS NULL;");
          } catch (_) {}
          try {
            await customStatement("UPDATE \"stores\" SET \"cash_rounding_increment\" = 100 WHERE \"cash_rounding_increment\" IS NULL;");
          } catch (_) {}
          try {
            await customStatement("UPDATE \"stores\" SET \"cash_rounding_mode\" = 'ROUND_NEAREST' WHERE \"cash_rounding_mode\" IS NULL;");
          } catch (_) {}

          // Self-healing: ensure tables exist even if migration was skipped
          await customStatement('''
            CREATE TABLE IF NOT EXISTS "promotions" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "store_id" TEXT NOT NULL,
              "name" TEXT NOT NULL,
              "code" TEXT,
              "discount_type" TEXT NOT NULL,
              "discount_value" INTEGER NOT NULL,
              "min_spend" INTEGER NOT NULL DEFAULT 0,
              "start_date" INTEGER,
              "end_date" INTEGER,
              "product_id" TEXT,
              "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "customers" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "store_id" TEXT NOT NULL,
              "name" TEXT NOT NULL,
              "phone" TEXT,
              "email" TEXT,
              "notes" TEXT,
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL
            );
          ''');

          await customStatement('''
            CREATE TABLE IF NOT EXISTS "users" (
              "id" TEXT NOT NULL PRIMARY KEY,
              "store_id" TEXT NOT NULL,
              "username" TEXT NOT NULL,
              "email" TEXT,
              "password_hash" TEXT NOT NULL,
              "display_name" TEXT NOT NULL,
              "role" TEXT NOT NULL DEFAULT 'ADMIN',
              "role_id" TEXT,
              "active" INTEGER NOT NULL DEFAULT 1 CHECK ("active" IN (0, 1)),
              "created_at" INTEGER NOT NULL,
              "updated_at" INTEGER NOT NULL
            );
          ''');

          // Self-healing: reconcile product variant stocks so parent stock == sum(variants)
          try {
            await productDao.reconcileVariantStocks();
          } catch (_) {}
        },
      );

  static LazyDatabase _openConnection(String dbName) {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, dbName));
      return NativeDatabase.createInBackground(file);
    });
  }
}
