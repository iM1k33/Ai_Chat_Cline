// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
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

  testWidgets('PIN setup gate renders after validated API key with no PIN', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStorageService.appSettingsKey: jsonEncode(<String, dynamic>{
        'selectedProviderId': 'openrouter',
        'selectedModelId': 'openrouter/free',
        'baseUrl': 'https://openrouter.ai/api/v1',
        'systemPrompt': '',
        'themeMode': 'system',
        'locale': 'system',
        'includeMessageContentInLogs': false,
        'modelParameters': <String, dynamic>{},
        'isApiKeyValidated': true,
      }),
      SecureStorageService.apiKeyKey: 'sk-or-v1-test-key',
    });

    await tester.pumpWidget(const AIChatApp());
    await tester.pumpAndSettle();

    expect(find.text('Set 4-digit PIN'), findsOneWidget);
  });

  testWidgets('PIN unlock gate renders when validated API key and PIN exist', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      SettingsStorageService.appSettingsKey: jsonEncode(<String, dynamic>{
        'selectedProviderId': 'openrouter',
        'selectedModelId': 'openrouter/free',
        'baseUrl': 'https://openrouter.ai/api/v1',
        'systemPrompt': '',
        'themeMode': 'system',
        'locale': 'system',
        'includeMessageContentInLogs': false,
        'modelParameters': <String, dynamic>{},
        'isApiKeyValidated': true,
      }),
      SecureStorageService.apiKeyKey: 'sk-or-v1-test-key',
      SecureStorageService.pinKey: '1234',
    });

    await tester.pumpWidget(const AIChatApp());
    await tester.pumpAndSettle();

    expect(find.text('Unlock app'), findsOneWidget);
  });
}
