class ChatCompletionResponse {
  const ChatCompletionResponse({
    required this.content,
    this.model,
    this.providerId,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
  });

  final String content;
  final String? model;
  final String? providerId;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;

  factory ChatCompletionResponse.fromJson(
    Map<String, dynamic> json, {
    String? providerId,
  }) {
    final List<dynamic>? choices = json['choices'] as List<dynamic>?;
    String content = '';

    if (choices != null && choices.isNotEmpty) {
      final Object? firstChoice = choices.first;
      if (firstChoice is Map<String, dynamic>) {
        final Object? message = firstChoice['message'];
        if (message is Map<String, dynamic>) {
          content = (message['content'] as String?) ?? '';
        }
      }
    }

    final Map<String, dynamic>? usage = json['usage'] as Map<String, dynamic>?;

    return ChatCompletionResponse(
      content: content,
      model: json['model'] as String?,
      providerId: providerId,
      promptTokens: (usage?['prompt_tokens'] as num?)?.toInt(),
      completionTokens: (usage?['completion_tokens'] as num?)?.toInt(),
      totalTokens: (usage?['total_tokens'] as num?)?.toInt(),
    );
  }
}

class ChatCompletionStreamChunk {
  const ChatCompletionStreamChunk({
    required this.delta,
    this.model,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    required this.isDone,
  });

  final String delta;
  final String? model;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final bool isDone;
}
