import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:clivora/app.dart';

void main() {
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
