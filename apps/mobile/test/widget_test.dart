import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:clivora/app.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://test.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('CLIVORA app shows splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ClivoraApp()));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CLIVORA'), findsOneWidget);
    expect(find.text('Your Business Operating System'), findsOneWidget);

    // Complete splash navigation timer to avoid pending timers in test teardown.
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump();
  });
}
