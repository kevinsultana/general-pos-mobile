import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../../data/local/app_database.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/store_repository_impl.dart';
import '../../data/repositories/transaction_repository_impl.dart';
import '../../domain/repositories/i_inventory_repository.dart';
import '../../domain/repositories/i_product_repository.dart';
import '../../domain/repositories/i_store_repository.dart';
import '../../domain/repositories/i_transaction_repository.dart';
import '../../domain/repositories/i_draft_repository.dart';
import '../../domain/services/transaction_calculator.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../data/repositories/draft_repository_impl.dart';

import '../../data/repositories/customer_repository_impl.dart';
import '../../data/repositories/promotion_repository_impl.dart';
import '../../domain/repositories/i_customer_repository.dart';
import '../../domain/repositories/i_promotion_repository.dart';
import '../../domain/services/promotion_validator.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/repositories/i_report_repository.dart';
import '../../domain/models/sales_report.dart';
import '../../domain/models/product_report.dart';
import '../../domain/models/inventory_report.dart';
import '../../data/services/backup_service.dart';
import '../../data/repositories/backup_repository_impl.dart';
import '../../domain/repositories/i_backup_repository.dart';
import '../../domain/models/backup_info.dart';
import '../../domain/models/printer_device.dart';
import '../../domain/repositories/i_printer_repository.dart';
import '../../data/repositories/printer_repository_impl.dart';
import '../../data/services/printer_service.dart';

import 'cloud_providers.dart';

/// Isolated Local Database (local.sqlite)
final localDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.openLocal();
  ref.onDispose(() => db.close());
  return db;
});

/// Isolated Cloud Cache Database (cloud_cache.sqlite)
final cloudCacheDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.openCloudCache();
  ref.onDispose(() => db.close());
  return db;
});

/// Active database based on operational mode:
/// In Local mode -> provides local.sqlite
/// In Cloud mode -> provides cloud_cache.sqlite
/// Datasets are 100% physically isolated on the filesystem.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final modeAsync = ref.watch(appOperationalModeProvider);
  final mode = modeAsync.valueOrNull ?? AppOperationalMode.local;
  return mode == AppOperationalMode.cloud
      ? ref.watch(cloudCacheDatabaseProvider)
      : ref.watch(localDatabaseProvider);
});

final storeRepositoryProvider = Provider<IStoreRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StoreRepositoryImpl(db.storeDao);
});

/// Active store ID based on operational mode:
/// In Cloud mode -> gets storeId from authenticated cloud user or token storage
/// In Local mode -> defaults to AppConstants.defaultStoreId ('store-default-001')
final activeStoreIdProvider = Provider<String>((ref) {
  final isCloud = ref.watch(isCloudModeProvider);
  if (isCloud) {
    final cloudUser = ref.watch(cloudAuthProvider).valueOrNull;
    if (cloudUser != null && cloudUser.storeId.isNotEmpty) {
      return cloudUser.storeId;
    }
  }
  return AppConstants.defaultStoreId;
});

final currentStoreStreamProvider = StreamProvider.autoDispose<Store?>((ref) async* {
  final storeRepo = ref.watch(storeRepositoryProvider);
  final isCloud = ref.watch(isCloudModeProvider);
  final cloudUser = ref.watch(cloudAuthProvider).valueOrNull;

  if (isCloud && cloudUser != null && cloudUser.storeId.isNotEmpty) {
    final existing = await storeRepo.getStore(cloudUser.storeId);
    if (existing == null) {
      await storeRepo.saveStore(
        StoresCompanion.insert(
          id: cloudUser.storeId,
          name: cloudUser.storeName.isNotEmpty ? cloudUser.storeName : 'Toko Cloud POS',
          ownerName: Value(cloudUser.displayName),
          currency: const Value('IDR'),
          timezone: const Value('Asia/Jakarta'),
          language: const Value('id'),
          businessType: const Value('GENERAL'),
          customerEnabled: const Value(true),
          draftEnabled: const Value(true),
          splitPaymentEnabled: const Value(true),
          refundEnabled: const Value(true),
          cashRoundingEnabled: const Value(true),
          cashRoundingIncrement: const Value(100),
          cashRoundingMode: const Value('ROUND_NEAREST'),
          subscriptionPlan: const Value('PRO'),
          subscriptionStatus: const Value('ACTIVE'),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    yield* storeRepo.watchStore(cloudUser.storeId);
  } else {
    await storeRepo.ensureDefaultStore();
    yield* storeRepo.watchCurrentStore();
  }
});

final productRepositoryProvider = Provider<IProductRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final isCloud = ref.watch(isCloudModeProvider);
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  return ProductRepositoryImpl(
    db.productDao,
    db.categoryDao,
    db: db,
    isCloudMode: isCloud,
    deviceId: deviceId,
  );
});

final inventoryRepositoryProvider = Provider<IInventoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final isCloud = ref.watch(isCloudModeProvider);
  return InventoryRepositoryImpl(db, db.productDao, db.stockMovementDao, null, isCloud);
});

final transactionRepositoryProvider = Provider<ITransactionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final isCloud = ref.watch(isCloudModeProvider);
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  return TransactionRepositoryImpl(db, null, isCloud, deviceId);
});

final draftRepositoryProvider = Provider<IDraftRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DraftRepositoryImpl(db);
});

final customerRepositoryProvider = Provider<ICustomerRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final isCloud = ref.watch(isCloudModeProvider);
  final deviceId = ref.watch(deviceIdProvider).valueOrNull;
  return CustomerRepositoryImpl(
    db.customerDao,
    db: db,
    isCloudMode: isCloud,
    deviceId: deviceId,
  );
});

final promotionRepositoryProvider = Provider<IPromotionRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PromotionRepositoryImpl(db.promotionDao);
});

final promotionValidatorProvider = Provider<PromotionValidator>((ref) {
  return const PromotionValidator();
});

final transactionCalculatorProvider = Provider<TransactionCalculator>((ref) {
  return const TransactionCalculator();
});

final draftListStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final draftRepo = ref.watch(draftRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return draftRepo.watchDrafts(storeId);
});

final transactionListStreamProvider = StreamProvider.autoDispose<List<Transaction>>((ref) {
  final trxRepo = ref.watch(transactionRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return trxRepo.watchTransactions(storeId);
});

final customerListStreamProvider = StreamProvider.autoDispose<List<Customer>>((ref) {
  final customerRepo = ref.watch(customerRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return customerRepo.watchCustomers(storeId);
});

final promotionListStreamProvider = StreamProvider.autoDispose<List<Promotion>>((ref) {
  final promoRepo = ref.watch(promotionRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return promoRepo.watchPromotions(storeId);
});

final reportRepositoryProvider = Provider<IReportRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ReportRepositoryImpl(db.reportDao);
});

final backupServiceProvider = Provider<BackupService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BackupService(db);
});

final backupRepositoryProvider = Provider<IBackupRepository>((ref) {
  final service = ref.watch(backupServiceProvider);
  return BackupRepositoryImpl(service);
});

final backupListProvider = FutureProvider.autoDispose<List<BackupFileInfo>>((ref) {
  final repo = ref.watch(backupRepositoryProvider);
  return repo.listBackups();
});

class DateRangeParams {
  final DateTime startDate;
  final DateTime endDate;
  final String storeId;

  const DateRangeParams({
    required this.startDate,
    required this.endDate,
    this.storeId = AppConstants.defaultStoreId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DateRangeParams &&
          runtimeType == other.runtimeType &&
          startDate == other.startDate &&
          endDate == other.endDate &&
          storeId == other.storeId;

  @override
  int get hashCode => Object.hash(startDate, endDate, storeId);
}

final salesReportProvider = FutureProvider.autoDispose.family<SalesReport, DateRangeParams>((ref, params) {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getSalesReport(
    storeId: params.storeId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

final productSalesReportProvider = FutureProvider.autoDispose.family<ProductSalesReport, DateRangeParams>((ref, params) {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getProductSalesReport(
    storeId: params.storeId,
    startDate: params.startDate,
    endDate: params.endDate,
  );
});

final inventoryReportProvider = FutureProvider.autoDispose.family<InventoryReportSummary, String>((ref, storeId) {
  final repo = ref.watch(reportRepositoryProvider);
  return repo.getInventoryReport(storeId: storeId);
});

final printerRepositoryProvider = Provider<IPrinterRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PrinterRepositoryImpl(db.printerDao);
});

final printerServiceProvider = Provider<PrinterService>((ref) {
  final repo = ref.watch(printerRepositoryProvider);
  return PrinterService(repo);
});

final printerListStreamProvider =
    StreamProvider.autoDispose<List<PrinterDevice>>((ref) {
  final repo = ref.watch(printerRepositoryProvider);
  final storeId = ref.watch(activeStoreIdProvider);
  return repo.watchAllPrinters(storeId);
});




