import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppSettings.fromJson defaults isApiKeyValidated to false when missing', () {
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
  });
}