import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/core/providers/cloud_providers.dart';
import 'package:mobile_pos/core/providers/permission_provider.dart';
import 'package:mobile_pos/data/services/cloud_auth_service.dart';

void main() {
  group('P2.4 Mobile UI RBAC — PermissionProvider Tests', () {
    test('Local Mode grants all permissions by default', () {
      final container = ProviderContainer(
        overrides: [
          isCloudModeProvider.overrideWith((ref) => false),
        ],
      );
      addTearDown(container.dispose);

      final perms = container.read(userPermissionsProvider);
      expect(perms, equals(AppPermissions.all.toSet()));

      // Spot checks on specific permissions
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageProducts)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.createTransaction)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.managePromotions)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.viewReports)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageSettings)),
        isTrue,
      );
      expect(
        container.read(hasAnyPermissionProvider([
          AppPermissions.manageProducts,
          'non_existent_permission',
        ])),
        isTrue,
      );
    });

    test('Cloud Mode with unauthenticated user grants no permissions', () async {
      final container = ProviderContainer(
        overrides: [
          isCloudModeProvider.overrideWith((ref) => true),
          cloudAuthProvider.overrideWith(() => _MockCloudAuthNotifier(null)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cloudAuthProvider.future);

      final perms = container.read(userPermissionsProvider);
      expect(perms, isEmpty);

      expect(
        container.read(hasPermissionProvider(AppPermissions.manageProducts)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.createTransaction)),
        isFalse,
      );
      expect(
        container.read(hasAnyPermissionProvider([
          AppPermissions.createTransaction,
          AppPermissions.manageProducts,
        ])),
        isFalse,
      );
    });

    test('Cloud Mode with Cashier permissions restricts product/promo/report management', () async {
      final cashierUser = CloudUser(
        userId: 'cashier-01',
        username: 'kasir1',
        displayName: 'Kasir Budi',
        storeId: 'store-01',
        storeName: 'Toko Berkah',
        permissions: const [
          AppPermissions.createTransaction,
          AppPermissions.viewSales,
          AppPermissions.manageCustomers,
        ],
      );

      final container = ProviderContainer(
        overrides: [
          isCloudModeProvider.overrideWith((ref) => true),
          cloudAuthProvider.overrideWith(() => _MockCloudAuthNotifier(cashierUser)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cloudAuthProvider.future);

      final perms = container.read(userPermissionsProvider);
      expect(perms, contains(AppPermissions.createTransaction));
      expect(perms, contains(AppPermissions.viewSales));
      expect(perms, contains(AppPermissions.manageCustomers));
      expect(perms.length, equals(3));

      // Allowed actions
      expect(
        container.read(hasPermissionProvider(AppPermissions.createTransaction)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageCustomers)),
        isTrue,
      );

      // Disallowed actions
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageProducts)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageInventory)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.managePromotions)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.viewReports)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageSettings)),
        isFalse,
      );

      // hasAnyPermission
      expect(
        container.read(hasAnyPermissionProvider([
          AppPermissions.manageProducts,
          AppPermissions.createTransaction,
        ])),
        isTrue,
      );
      expect(
        container.read(hasAnyPermissionProvider([
          AppPermissions.manageProducts,
          AppPermissions.managePromotions,
        ])),
        isFalse,
      );
    });

    test('Cloud Mode with Wildcard * grants all permissions (Super Admin)', () async {
      final adminUser = CloudUser(
        userId: 'admin-01',
        username: 'owner',
        displayName: 'Owner Store',
        storeId: 'store-01',
        storeName: 'Toko Berkah',
        permissions: const ['*'],
      );

      final container = ProviderContainer(
        overrides: [
          isCloudModeProvider.overrideWith((ref) => true),
          cloudAuthProvider.overrideWith(() => _MockCloudAuthNotifier(adminUser)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cloudAuthProvider.future);

      final perms = container.read(userPermissionsProvider);
      expect(perms, equals(AppPermissions.all.toSet()));

      expect(
        container.read(hasPermissionProvider(AppPermissions.manageProducts)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageSettings)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.refundTransaction)),
        isTrue,
      );
    });

    test('Cloud Mode with Inventory Manager permissions allows inventory but denies sales', () async {
      final inventoryUser = CloudUser(
        userId: 'inv-01',
        username: 'staf_gudang',
        displayName: 'Staf Gudang',
        storeId: 'store-01',
        storeName: 'Toko Berkah',
        permissions: const [
          AppPermissions.manageProducts,
          AppPermissions.manageInventory,
          AppPermissions.viewProducts,
          AppPermissions.viewInventory,
        ],
      );

      final container = ProviderContainer(
        overrides: [
          isCloudModeProvider.overrideWith((ref) => true),
          cloudAuthProvider.overrideWith(() => _MockCloudAuthNotifier(inventoryUser)),
        ],
      );
      addTearDown(container.dispose);

      await container.read(cloudAuthProvider.future);

      // Allowed actions
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageProducts)),
        isTrue,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.manageInventory)),
        isTrue,
      );

      // Disallowed actions
      expect(
        container.read(hasPermissionProvider(AppPermissions.createTransaction)),
        isFalse,
      );
      expect(
        container.read(hasPermissionProvider(AppPermissions.managePromotions)),
        isFalse,
      );
    });
  });
}

class _MockCloudAuthNotifier extends CloudAuthNotifier {
  final CloudUser? _initialUser;
  _MockCloudAuthNotifier(this._initialUser);

  @override
  Future<CloudUser?> build() async {
    return _initialUser;
  }
}
