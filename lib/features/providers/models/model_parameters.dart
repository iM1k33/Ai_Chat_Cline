class ModelParameters {
  const ModelParameters({
    this.temperature = 0.7,
    this.maxTokens,
    this.topP = 1.0,
    this.frequencyPenalty = 0.0,
    this.presencePenalty = 0.0,
    this.streamingEnabled = true,
  });

  final double temperature;
  final int? maxTokens;
  final double topP;
  final double frequencyPenalty;
  final double presencePenalty;
  final bool streamingEnabled;

  factory ModelParameters.defaults() {
    return const ModelParameters();
  }

  ModelParameters copyWith({
    double? temperature,
    int? maxTokens,
    double? topP,
    double? frequencyPenalty,
    double? presencePenalty,
    bool? streamingEnabled,
  }) {
    return ModelParameters(
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      topP: topP ?? this.topP,
      frequencyPenalty: frequencyPenalty ?? this.frequencyPenalty,
      presencePenalty: presencePenalty ?? this.presencePenalty,
      streamingEnabled: streamingEnabled ?? this.streamingEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'temperature': temperature,
      'maxTokens': maxTokens,
      'topP': topP,
      'frequencyPenalty': frequencyPenalty,
      'presencePenalty': presencePenalty,
      'streamingEnabled': streamingEnabled,
    };
  }

  factory ModelParameters.fromJson(Map<String, dynamic> json) {
    return ModelParameters(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      maxTokens: json['maxTokens'] as int?,
      topP: (json['topP'] as num?)?.toDouble() ?? 1.0,
      frequencyPenalty: (json['frequencyPenalty'] as num?)?.toDouble() ?? 0.0,
      presencePenalty: (json['presencePenalty'] as num?)?.toDouble() ?? 0.0,
      streamingEnabled: json['streamingEnabled'] as bool? ?? true,
    );
  }
}
