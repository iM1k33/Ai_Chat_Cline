import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/services/provider_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderDetector', () {
    test('sk-or-v1-abc detects OpenRouter', () {
      final AIProvider provider = ProviderDetector.detectByApiKey(
        'sk-or-v1-abc',
      );

      expect(provider.id, AIProvider.openRouter.id);
      expect(provider.type, AIProviderType.openRouter);
    });

    test('sk-or-vv-abc detects VSEGPT', () {
      final AIProvider provider = ProviderDetector.detectByApiKey(
        'sk-or-vv-abc',
      );

      expect(provider.id, AIProvider.vsegpt.id);
      expect(provider.type, AIProviderType.vsegpt);
    });

    test('whitespace around key is ignored', () {
      final AIProvider provider = ProviderDetector.detectByApiKey(
        '  sk-or-v1-abc  ',
      );

      expect(provider.id, AIProvider.openRouter.id);
      expect(provider.type, AIProviderType.openRouter);
    });

    test('unknown key returns custom from detectByApiKey', () {
      final AIProvider provider = ProviderDetector.detectByApiKey(
        'unknown-key',
      );

      expect(provider.id, 'custom');
      expect(provider.name, 'Custom OpenAI-compatible');
      expect(provider.type, AIProviderType.custom);
      expect(provider.baseUrl, '');
      expect(provider.apiKeyPrefix, '');
      expect(provider.currencyCode, 'USD');
    });

    test('unknown key returns null from tryDetectByApiKey', () {
      final AIProvider? provider = ProviderDetector.tryDetectByApiKey(
        'unknown-key',
      );

      expect(provider, isNull);
    });

    test('empty key returns null from tryDetectByApiKey', () {
      final AIProvider? provider = ProviderDetector.tryDetectByApiKey('   ');

      expect(provider, isNull);
    });
  });
}
