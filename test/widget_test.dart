// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aichatcline/app/app.dart';

void main() {
  testWidgets('Initial setup gate renders before validated API key', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    // Build our app and trigger a frame.
    await tester.pumpWidget(const AIChatApp());
    await tester.pumpAndSettle();

    expect(find.text('Set up AI provider'), findsOneWidget);
    expect(
      find.text(
        'Enter your API key. The provider and base URL will be detected automatically.',
      ),
      findsOneWidget,
    );
    expect(find.text('Validate / Continue'), findsOneWidget);
  });
}
