import 'package:drift/drift.dart';
import '../../domain/models/printer_device.dart';
import '../../domain/repositories/i_printer_repository.dart';
import '../local/app_database.dart';
import '../local/daos/printer_dao.dart';

class PrinterRepositoryImpl implements IPrinterRepository {
  final PrinterDao _printerDao;

  PrinterRepositoryImpl(this._printerDao);

  PrinterDevice _toDomain(Printer row) {
    return PrinterDevice(
      id: row.id,
      storeId: row.storeId,
      name: row.name,
      connectionType: PrinterConnectionType.fromString(row.connectionType),
      addressReference: row.addressReference,
      role: PrinterRole.fromString(row.role),
      paperSize: PrinterDevice.decodePaperSize(row.configuration),
      receiptCopies: row.receiptCopies,
      kitchenCopies: row.kitchenCopies,
      autoPrint: row.autoPrint,
      active: row.active,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  PrintersCompanion _toCompanion(PrinterDevice device) {
    return PrintersCompanion(
      id: Value(device.id),
      storeId: Value(device.storeId),
      name: Value(device.name),
      connectionType: Value(device.connectionType.toDbString()),
      addressReference: Value(device.addressReference),
      role: Value(device.role.toDbString()),
      receiptCopies: Value(device.receiptCopies),
      kitchenCopies: Value(device.kitchenCopies),
      autoPrint: Value(device.autoPrint),
      active: Value(device.active),
      configuration: Value(device.encodeConfiguration()),
      createdAt: Value(device.createdAt),
      updatedAt: Value(device.updatedAt),
    );
  }

  @override
  Stream<List<PrinterDevice>> watchAllPrinters(String storeId) {
    return _printerDao
        .watchAllPrinters(storeId)
        .map((rows) => rows.map(_toDomain).toList());
  }

  @override
  Future<List<PrinterDevice>> getAllPrinters(String storeId) async {
    final rows = await _printerDao.getAllPrinters(storeId);
    return rows.map(_toDomain).toList();
  }

  @override
  Future<List<PrinterDevice>> getActivePrintersByRole(
      String storeId, PrinterRole role) async {
    final rows =
        await _printerDao.getActivePrintersByRole(storeId, role.toDbString());
    return rows.map(_toDomain).toList();
  }

  @override
  Future<PrinterDevice?> getPrinterById(String id) async {
    final row = await _printerDao.getPrinterById(id);
    if (row == null) return null;
    return _toDomain(row);
  }

  @override
  Future<void> savePrinter(PrinterDevice printer) {
    return _printerDao.upsertPrinter(_toCompanion(printer));
  }

  @override
  Future<void> deletePrinter(String id) {
    return _printerDao.deletePrinter(id);
  }
}
