import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resetAllAppData clears key/pin/settings state', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final SettingsController controller = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );

    await controller.saveApiKey('sk-or-v1-secret');
    await controller.setupPin('1234');
    await controller.updateSystemPrompt('custom prompt');

    await controller.resetAllAppData();

    expect(controller.apiKey, isEmpty);
    expect(controller.settings.isApiKeyValidated, isFalse);
    expect(controller.settings.selectedProviderId, isNull);
    expect(controller.settings.selectedModelId, isNull);
    expect(controller.settings.baseUrl, isNull);
    expect(controller.settings.systemPrompt, isEmpty);
    expect(controller.isLocked, isTrue);
    expect(controller.isPinSetupRequired, isFalse);
  });
}
