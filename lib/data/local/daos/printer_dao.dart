import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/printer_tables.dart';

part 'printer_dao.g.dart';

@DriftAccessor(tables: [Printers])
class PrinterDao extends DatabaseAccessor<AppDatabase> with _$PrinterDaoMixin {
  PrinterDao(super.db);

  Future<void> healOrphanPrinters(String storeId) async {
    try {
      if (storeId != 'store-default-01' && storeId.isNotEmpty) {
        await (update(printers)
              ..where((tbl) =>
                  tbl.storeId.equals('store-default-01') |
                  tbl.storeId.equals('store-default-001') |
                  tbl.storeId.equals('')))
            .write(PrintersCompanion(storeId: Value(storeId)));
      }
    } catch (_) {}
  }

  Stream<List<Printer>> watchAllPrinters(String storeId) async* {
    await healOrphanPrinters(storeId);
    yield* (select(printers)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<List<Printer>> getAllPrinters(String storeId) async {
    await healOrphanPrinters(storeId);
    return (select(printers)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) |
              tbl.storeId.equals('store-default-01'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .get();
  }

  Future<List<Printer>> getActivePrintersByRole(String storeId, String role) {
    return (select(printers)
          ..where((tbl) =>
              tbl.storeId.equals(storeId) &
              tbl.active.equals(true) &
              (tbl.role.equals(role) | tbl.role.equals('BOTH'))))
        .get();
  }

  Future<Printer?> getPrinterById(String id) {
    return (select(printers)..where((tbl) => tbl.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertPrinter(PrintersCompanion printer) {
    return into(printers).insertOnConflictUpdate(printer);
  }

  Future<int> deletePrinter(String id) {
    return (delete(printers)..where((tbl) => tbl.id.equals(id))).go();
  }
}
