import 'package:aichatcline/features/providers/models/ai_provider.dart';

class ProviderDetector {
  const ProviderDetector._();

  static AIProvider detectByApiKey(String apiKey) {
    final AIProvider? detected = tryDetectByApiKey(apiKey);
    if (detected != null) {
      return detected;
    }

    return const AIProvider(
      id: 'custom',
      name: 'Custom OpenAI-compatible',
      type: AIProviderType.custom,
      baseUrl: '',
      apiKeyPrefix: '',
      currencyCode: 'USD',
    );
  }

  static AIProvider? tryDetectByApiKey(String apiKey) {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (trimmed.startsWith('sk-or-v1-')) {
      return AIProvider.openRouter;
    }

    if (trimmed.startsWith('sk-or-vv-')) {
      return AIProvider.vsegpt;
    }

    return null;
  }
}
