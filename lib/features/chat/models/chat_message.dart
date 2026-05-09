enum ChatMessageRole { system, user, assistant }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.modelId,
    this.providerId,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.estimatedCost,
    this.error,
  });

  final String id;
  final String conversationId;
  final ChatMessageRole role;
  final String content;
  final DateTime createdAt;
  final String? modelId;
  final String? providerId;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final double? estimatedCost;
  final String? error;

  ChatMessage copyWith({
    String? id,
    String? conversationId,
    ChatMessageRole? role,
    String? content,
    DateTime? createdAt,
    String? modelId,
    String? providerId,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    double? estimatedCost,
    String? error,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      modelId: modelId ?? this.modelId,
      providerId: providerId ?? this.providerId,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      totalTokens: totalTokens ?? this.totalTokens,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'conversationId': conversationId,
      'role': roleToString(role),
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'modelId': modelId,
      'providerId': providerId,
      'promptTokens': promptTokens,
      'completionTokens': completionTokens,
      'totalTokens': totalTokens,
      'estimatedCost': estimatedCost,
      'error': error,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      conversationId: json['conversationId'] as String,
      role: roleFromString(json['role'] as String),
      content: json['content'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      modelId: json['modelId'] as String?,
      providerId: json['providerId'] as String?,
      promptTokens: json['promptTokens'] as int?,
      completionTokens: json['completionTokens'] as int?,
      totalTokens: json['totalTokens'] as int?,
      estimatedCost: (json['estimatedCost'] as num?)?.toDouble(),
      error: json['error'] as String?,
    );
  }

  static String roleToString(ChatMessageRole role) {
    return switch (role) {
      ChatMessageRole.system => 'system',
      ChatMessageRole.user => 'user',
      ChatMessageRole.assistant => 'assistant',
    };
  }

  static ChatMessageRole roleFromString(String value) {
    return switch (value) {
      'system' => ChatMessageRole.system,
      'user' => ChatMessageRole.user,
      'assistant' => ChatMessageRole.assistant,
      _ => ChatMessageRole.user,
    };
  }
}
