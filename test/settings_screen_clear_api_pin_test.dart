import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/settings/ui/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('clear API key requires PIN before confirmation', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );
    final ModelCatalogController modelCatalogController =
        ModelCatalogController(
          aiClient: OpenAICompatibleClient(),
          settingsController: settingsController,
        );

    await settingsController.saveApiKey('sk-or-v1-very-secret');
    await settingsController.setupPin('1234');
    await settingsController.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          controller: settingsController,
          modelCatalogController: modelCatalogController,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byKey(const Key('settings_clear_api_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Confirm PIN'), findsOneWidget);
    expect(find.byKey(const Key('confirm_clear_api_dialog')), findsNothing);

    await tester.tap(find.byKey(const Key('pin_digit_1')));
    await tester.tap(find.byKey(const Key('pin_digit_2')));
    await tester.tap(find.byKey(const Key('pin_digit_3')));
    await tester.tap(find.byKey(const Key('pin_digit_4')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final Finder confirmDialog = find.byKey(
      const Key('confirm_clear_api_dialog'),
    );
    expect(confirmDialog, findsOneWidget);

    await tester.tap(
      find.descendant(of: confirmDialog, matching: find.text('Cancel')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(settingsController.apiKey, isNotEmpty);
  });
}
