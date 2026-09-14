import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile_pos/main.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('App smoke test - Mode selection and local home flow', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: GeneralPosApp()));
    await tester.pumpAndSettle();

    // Verify initial screen is Mode Selection Screen
    expect(find.text('Mode Lokal (Offline POS)'), findsOneWidget);
    expect(find.text('Mode Cloud (Online Sync)'), findsOneWidget);

    // Tap Masuk Mode Lokal to enter HomeScreen
    await tester.tap(find.text('Masuk Mode Lokal'));
    await tester.pumpAndSettle();

    // Verify that HomeScreen title and components are rendered
    expect(find.text('UMKM POS'), findsWidgets);
    expect(find.text('PHASE 0'), findsOneWidget);
    expect(find.text('Pembulatan Tunai'), findsOneWidget);
  });
}
