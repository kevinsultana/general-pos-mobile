import '../../domain/models/sales_report.dart';
import '../../domain/models/product_report.dart';
import '../../domain/models/inventory_report.dart';
import '../../domain/repositories/i_report_repository.dart';
import '../local/daos/report_dao.dart';

class ReportRepositoryImpl implements IReportRepository {
  final ReportDao _reportDao;

  ReportRepositoryImpl(this._reportDao);

  @override
  Future<SalesReport> getSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _reportDao.getSalesReport(
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<ProductSalesReport> getProductSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    return _reportDao.getProductSalesReport(
      storeId: storeId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  Future<InventoryReportSummary> getInventoryReport({
    required String storeId,
  }) {
    return _reportDao.getInventoryReport(storeId: storeId);
  }
}
