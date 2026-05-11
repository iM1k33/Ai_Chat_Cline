import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppSettings.fromJson defaults isApiKeyValidated to false when missing',
    () {
      final Map<String, dynamic> json = <String, dynamic>{
        'selectedProviderId': 'openrouter',
        'selectedModelId': null,
        'systemPrompt': '',
        'themeMode': 'system',
        'locale': 'system',
        'includeMessageContentInLogs': false,
        'modelParameters': <String, dynamic>{},
      };

      final AppSettings settings = AppSettings.fromJson(json);
      expect(settings.isApiKeyValidated, false);
    },
  );

  test('AppSettings baseUrl roundtrip via toJson/fromJson', () {
    const AppSettings source = AppSettings(
      selectedProviderId: 'openrouter',
      selectedModelId: 'openrouter/free',
      baseUrl: 'https://openrouter.ai/api/v1',
      isApiKeyValidated: true,
    );

    final Map<String, dynamic> json = source.toJson();
    final AppSettings restored = AppSettings.fromJson(json);

    expect(restored.baseUrl, 'https://openrouter.ai/api/v1');
    expect(restored.selectedProviderId, 'openrouter');
    expect(restored.selectedModelId, 'openrouter/free');
    expect(restored.isApiKeyValidated, true);
  });

  test('AppSettings.fromJson safely handles missing baseUrl', () {
    final AppSettings restored = AppSettings.fromJson(<String, dynamic>{
      'selectedProviderId': 'vsegpt',
      'selectedModelId': 'openai/gpt-3.5-turbo',
      'systemPrompt': '',
      'themeMode': 'system',
      'locale': 'system',
      'includeMessageContentInLogs': false,
      'modelParameters': <String, dynamic>{},
      'isApiKeyValidated': true,
    });

    expect(restored.baseUrl, isNull);
    expect(restored.isApiKeyValidated, true);
  });
}
