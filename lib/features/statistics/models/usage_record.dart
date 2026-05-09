class UsageRecord {
  const UsageRecord({
    required this.id,
    this.conversationId,
    this.messageId,
    required this.providerId,
    required this.modelId,
    required this.createdAt,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.estimatedCost = 0,
    required this.currencyCode,
    this.responseTimeMs,
    this.error,
  });

  final String id;
  final String? conversationId;
  final String? messageId;
  final String providerId;
  final String modelId;
  final DateTime createdAt;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final double estimatedCost;
  final String currencyCode;
  final int? responseTimeMs;
  final String? error;

  UsageRecord copyWith({
    String? id,
    String? conversationId,
    String? messageId,
    String? providerId,
    String? modelId,
    DateTime? createdAt,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    double? estimatedCost,
    String? currencyCode,
    int? responseTimeMs,
    String? error,
  }) {
    return UsageRecord(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      messageId: messageId ?? this.messageId,
      providerId: providerId ?? this.providerId,
      modelId: modelId ?? this.modelId,
      createdAt: createdAt ?? this.createdAt,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      currencyCode: currencyCode ?? this.currencyCode,
      responseTimeMs: responseTimeMs ?? this.responseTimeMs,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversationId': conversationId,
      'messageId': messageId,
      'providerId': providerId,
      'modelId': modelId,
      'createdAt': createdAt.toIso8601String(),
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      'estimatedCost': estimatedCost,
      'currencyCode': currencyCode,
      'responseTimeMs': responseTimeMs,
      'error': error,
    };
  }

  factory UsageRecord.fromJson(Map<String, dynamic> json) {
    return UsageRecord(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String?,
      messageId: json['messageId'] as String?,
      providerId: json['providerId'] as String,
      modelId: json['modelId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      promptTokens: json['promptTokens'] as int? ?? 0,
      completionTokens: json['completionTokens'] as int? ?? 0,
      totalTokens: json['totalTokens'] as int? ?? 0,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble() ?? 0,
      currencyCode: json['currencyCode'] as String,
      responseTimeMs: json['responseTimeMs'] as int?,
      error: json['error'] as String?,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'conversation_id': conversationId,
      'message_id': messageId,
      'provider_id': providerId,
      'model_id': modelId,
      'created_at': createdAt.toIso8601String(),
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      'estimated_cost': estimatedCost,
      'currency_code': currencyCode,
      'response_time_ms': responseTimeMs,
      'error': error,
    };
  }

  factory UsageRecord.fromMap(Map<String, Object?> map) {
    return UsageRecord(
      id: map['id'] as String,
      conversationId: map['conversation_id'] as String?,
      messageId: map['message_id'] as String?,
      providerId: map['provider_id'] as String,
      modelId: map['model_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      promptTokens: map['prompt_tokens'] as int? ?? 0,
      completionTokens: map['completion_tokens'] as int? ?? 0,
      totalTokens: map['total_tokens'] as int? ?? 0,
      estimatedCost: (map['estimated_cost'] as num?)?.toDouble() ?? 0,
      currencyCode: map['currency_code'] as String,
      responseTimeMs: map['response_time_ms'] as int?,
      error: map['error'] as String?,
    );
  }
}
