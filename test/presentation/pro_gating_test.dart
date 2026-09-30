import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/data/services/api_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PRO Tier Gating for Cloud Mode Tests', () {
    late TokenStorage tokenStorage;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      tokenStorage = TokenStorage(const FlutterSecureStorage());
    });

    test('Rejects Cloud mode when account has FREE tier', () async {
      await tokenStorage.saveTokens(
        accessToken: 'mock-token-free',
        refreshToken: 'mock-refresh-free',
        storeId: 'store-free-1',
        userId: 'user-free-1',
      );
      await tokenStorage.saveTier(tier: 'FREE', canCloudSync: false);

      final token = await tokenStorage.getAccessToken();
      final tier = await tokenStorage.getTier();
      final canSync = await tokenStorage.canCloudSync();

      expect(token, isNotNull);
      expect(tier, equals('FREE'));
      expect(canSync, isFalse);

      final canActivateCloud = token != null && tier == 'PRO' && canSync;
      expect(canActivateCloud, isFalse);
    });

    test('Rejects Cloud mode when account tier is not PRO even if token exists', () async {
      await tokenStorage.saveTokens(
        accessToken: 'mock-token-paid',
        refreshToken: 'mock-refresh-paid',
        storeId: 'store-paid-1',
        userId: 'user-paid-1',
      );
      await tokenStorage.saveTier(tier: 'PAID', canCloudSync: false);

      final tier = await tokenStorage.getTier();
      final canSync = await tokenStorage.canCloudSync();

      final canActivateCloud = tier == 'PRO' && canSync;
      expect(canActivateCloud, isFalse);
    });

    test('Allows Cloud mode strictly when account is PRO with canCloudSync true', () async {
      await tokenStorage.saveTokens(
        accessToken: 'mock-token-pro',
        refreshToken: 'mock-refresh-pro',
        storeId: 'store-pro-1',
        userId: 'user-pro-1',
      );
      await tokenStorage.saveTier(tier: 'PRO', canCloudSync: true);

      final token = await tokenStorage.getAccessToken();
      final tier = await tokenStorage.getTier();
      final canSync = await tokenStorage.canCloudSync();

      expect(token, isNotNull);
      expect(tier, equals('PRO'));
      expect(canSync, isTrue);

      final canActivateCloud = token != null && tier == 'PRO' && canSync;
      expect(canActivateCloud, isTrue);
    });
  });
}
