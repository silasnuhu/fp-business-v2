// Render check for the redesigned Business Tools hub.
// Purpose: catch build-time exceptions (missing assets, null providers,
// layout errors) that would leave the screen blank on a device.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:whoxa/featuers/provider/theme_provider.dart';
import 'package:whoxa/screens/settings/business_tools_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        if (call.method == 'readAll') return <String, String>{};
        return null;
      },
    );
  });

  testWidgets('Business tools hub renders its rows', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<ThemeProvider>(
        create: (_) => ThemeProvider(),
        child: const MaterialApp(home: BusinessToolsScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final ex = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION: $ex');

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .toList();
    // ignore: avoid_print
    print('TEXTS: $texts');

    expect(ex, isNull, reason: 'screen threw while building');
    expect(find.text('Business tools'), findsOneWidget);
    expect(find.text('Catalog'), findsOneWidget);
    expect(find.text('Labels'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Social media links'), findsOneWidget);
  });
}
