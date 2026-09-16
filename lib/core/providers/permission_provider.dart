import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'cloud_providers.dart';

/// Centralized permission keys matching Backend SYSTEM_PERMISSIONS (be/src/config/permissions.ts).
class AppPermissions {
  // STORE & SETTINGS
  static const manageStore = 'manage_store';
  static const manageSettings = 'manage_store';
  static const viewStore = 'view_store';

  // USERS & ROLES
  static const manageUsers = 'manage_users';
  static const viewUsers = 'view_users';
  static const manageRoles = 'manage_roles';

  // PRODUCTS & CATEGORIES
  static const manageProducts = 'manage_products';
  static const viewProducts = 'view_products';
  static const manageCategories = 'manage_categories';

  // INVENTORY
  static const manageInventory = 'manage_inventory';
  static const viewInventory = 'view_inventory';

  // SALES / TRANSACTIONS / REFUNDS
  static const createTransaction = 'create_transaction';
  static const viewSales = 'view_sales';
  static const cancelTransaction = 'cancel_transaction';
  static const refundTransaction = 'refund_transaction';
  static const manageCustomers = 'manage_customers';

  // PROMOTIONS
  static const managePromotions = 'manage_promotions';
  static const viewPromotions = 'view_promotions';

  // PRINTERS
  static const managePrinters = 'manage_printers';

  // REPORTS
  static const viewReports = 'view_reports';

  // AUDIT & SYNC
  static const viewAuditLogs = 'view_audit_logs';
  static const syncData = 'sync_data';

  /// All system permissions
  static const all = [
    manageStore,
    viewStore,
    manageUsers,
    viewUsers,
    manageRoles,
    manageProducts,
    viewProducts,
    manageCategories,
    manageInventory,
    viewInventory,
    createTransaction,
    viewSales,
    cancelTransaction,
    refundTransaction,
    manageCustomers,
    managePromotions,
    viewPromotions,
    managePrinters,
    viewReports,
    viewAuditLogs,
    syncData,
  ];
}

/// Returns the active set of permissions for the current session.
/// In Local Mode (standalone offline), the user is the device owner, so all permissions are granted.
/// In Cloud Mode, permissions are determined by the active CloudUser session.
final userPermissionsProvider = Provider<Set<String>>((ref) {
  final isCloud = ref.watch(isCloudModeProvider);
  if (!isCloud) {
    // Standalone local register: full owner privileges
    return AppPermissions.all.toSet();
  }

  final cloudUser = ref.watch(cloudAuthProvider).valueOrNull;
  if (cloudUser == null) {
    return <String>{};
  }

  // Support wildcard '*' permission for superusers
  if (cloudUser.permissions.contains('*')) {
    return AppPermissions.all.toSet();
  }

  return cloudUser.permissions.toSet();
});

/// Evaluates if the current user has a specific permission.
final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final permissions = ref.watch(userPermissionsProvider);
  return permissions.contains(permission);
});

/// Evaluates if the current user has ANY of the specified permissions.
final hasAnyPermissionProvider =
    Provider.family<bool, List<String>>((ref, permissionsList) {
  final permissions = ref.watch(userPermissionsProvider);
  return permissionsList.any((p) => permissions.contains(p));
});
