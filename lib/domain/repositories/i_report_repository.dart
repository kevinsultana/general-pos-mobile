import '../models/sales_report.dart';
import '../models/product_report.dart';
import '../models/inventory_report.dart';

abstract class IReportRepository {
  Future<SalesReport> getSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<ProductSalesReport> getProductSalesReport({
    required String storeId,
    required DateTime startDate,
    required DateTime endDate,
  });

  Future<InventoryReportSummary> getInventoryReport({
    required String storeId,
  });
}
