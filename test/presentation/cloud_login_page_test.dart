import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_pos/presentation/settings/screens/cloud_login_page.dart';

void main() {
  testWidgets('CloudLoginPage renders clean dual-tab form without custom server endpoint settings',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CloudLoginPage(initialTab: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title and Subtitle in Login tab
    expect(find.text('Masuk ke Cloud POS'), findsOneWidget);
    expect(find.text('Sinkronisasi Cloud'), findsOneWidget);

    // Verify Username and Password are visible
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Masuk ke Cloud'), findsOneWidget);

    // Verify Server URL field & Advanced Server Settings toggle are completely removed
    expect(find.text('URL Server API'), findsNothing);
    expect(find.text('Pengaturan Server Endpoint (Lanjutan)'), findsNothing);

    // Switch to Register tab
    final registerTab = find.text('Daftar ke PRO Baru');
    expect(registerTab, findsOneWidget);
    await tester.tap(registerTab);
    await tester.pumpAndSettle();

    // Verify Register tab fields
    expect(find.text('Upgrade Toko ke PRO'), findsOneWidget);
    expect(find.text('Nama Toko'), findsOneWidget);
    expect(find.text('Nama Pemilik Toko'), findsOneWidget);
    expect(find.text('Daftar & Migrasikan ke PRO'), findsOneWidget);

    // Verify Server URL is still not present in Register tab
    expect(find.text('URL Server API'), findsNothing);
    expect(find.text('Pengaturan Server Endpoint (Lanjutan)'), findsNothing);
  });
}
