import '../models/printer_device.dart';

abstract class IPrinterRepository {
  Stream<List<PrinterDevice>> watchAllPrinters(String storeId);
  Future<List<PrinterDevice>> getAllPrinters(String storeId);
  Future<List<PrinterDevice>> getActivePrintersByRole(String storeId, PrinterRole role);
  Future<PrinterDevice?> getPrinterById(String id);
  Future<void> savePrinter(PrinterDevice printer);
  Future<void> deletePrinter(String id);
}
