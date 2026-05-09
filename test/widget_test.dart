// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aichatcline/app/app.dart';

void main() {
  testWidgets('AI Chat app shell renders', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AIChatApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('AI Chat'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
    expect(find.text('New chat'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
  });
}
