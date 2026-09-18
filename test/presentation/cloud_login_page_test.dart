import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/presentation/settings/screens/cloud_login_page.dart';

void main() {
  testWidgets('CloudLoginPage renders clean username/password form and hidden custom server settings',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CloudLoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle
    expect(find.text('Masuk ke Cloud POS'), findsOneWidget);
    expect(find.text('Sinkronisasi Cloud'), findsOneWidget);

    // Verify Username and Password are the primary visible fields
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk ke Cloud'), findsOneWidget);

    // Verify Server URL field is NOT visible initially
    expect(find.text('URL Server API'), findsNothing);

    // Verify Advanced Server Settings toggle button exists
    final toggleBtn = find.text('Pengaturan Server Endpoint (Lanjutan)');
    expect(toggleBtn, findsOneWidget);

    // Scroll until visible and tap the toggle button to reveal server settings
    await tester.ensureVisible(toggleBtn);
    await tester.pumpAndSettle();
    await tester.tap(toggleBtn);
    await tester.pumpAndSettle();

    // Now Server URL settings should be visible
    expect(find.text('URL Server API'), findsOneWidget);
    expect(find.text('Sembunyikan Pengaturan Server'), findsOneWidget);
  });
}
