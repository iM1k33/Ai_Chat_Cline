enum AIProviderType { openRouter, vsegpt, custom }

class AIProvider {
  const AIProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.apiKeyPrefix,
    required this.currencyCode,
  });

  static const AIProvider openRouter = AIProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    type: AIProviderType.openRouter,
    baseUrl: 'https://openrouter.ai/api/v1',
    apiKeyPrefix: 'sk-or-v1-',
    currencyCode: 'USD',
  );

  static const AIProvider vsegpt = AIProvider(
    id: 'vsegpt',
    name: 'VSEGPT',
    type: AIProviderType.vsegpt,
    baseUrl: 'https://api.vsegpt.ru/v1',
    apiKeyPrefix: 'sk-or-vv-',
    currencyCode: 'RUB',
  );

  final String id;
  final String name;
  final AIProviderType type;
  final String baseUrl;
  final String apiKeyPrefix;
  final String currencyCode;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'type': typeToString(type),
      'baseUrl': baseUrl,
      'apiKeyPrefix': apiKeyPrefix,
      'currencyCode': currencyCode,
    };
  }

  factory AIProvider.fromJson(Map<String, dynamic> json) {
    return AIProvider(
      id: json['id'] as String,
      name: json['name'] as String,
      type: typeFromString(json['type'] as String),
      baseUrl: json['baseUrl'] as String,
      apiKeyPrefix: json['apiKeyPrefix'] as String,
      currencyCode: json['currencyCode'] as String,
    );
  }

  static String typeToString(AIProviderType type) {
    return switch (type) {
      AIProviderType.openRouter => 'openRouter',
      AIProviderType.vsegpt => 'vsegpt',
      AIProviderType.custom => 'custom',
    };
  }

  static AIProviderType typeFromString(String value) {
    return switch (value) {
      'openRouter' => AIProviderType.openRouter,
      'vsegpt' => AIProviderType.vsegpt,
      'custom' => AIProviderType.custom,
      _ => AIProviderType.custom,
    };
  }
}
