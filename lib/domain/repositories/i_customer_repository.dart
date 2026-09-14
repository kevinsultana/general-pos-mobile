import '../../data/local/app_database.dart';

abstract class ICustomerRepository {
  Future<List<Customer>> getCustomers(String storeId);

  Stream<List<Customer>> watchCustomers(String storeId);

  Future<List<Customer>> searchCustomers(String storeId, String query);

  Future<Customer?> getCustomerById(String id);

  Future<String> createCustomer({
    required String storeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
  });

  Future<void> updateCustomer({
    required String id,
    required String storeId,
    required String name,
    String? phone,
    String? email,
    String? notes,
  });

  Future<void> deleteCustomer(String id);
}
