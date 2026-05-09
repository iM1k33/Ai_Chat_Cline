class ChatCompletionRequest {
  const ChatCompletionRequest({
    required this.model,
    required this.messages,
    required this.temperature,
    this.maxTokens,
    required this.topP,
    required this.frequencyPenalty,
    required this.presencePenalty,
    required this.stream,
  });

  final String model;
  final List<ChatCompletionMessage> messages;
  final double temperature;
  final int? maxTokens;
  final double topP;
  final double frequencyPenalty;
  final double presencePenalty;
  final bool stream;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{
      'model': model,
      'messages': messages.map((message) => message.toJson()).toList(),
      'temperature': temperature,
      'top_p': topP,
      'frequency_penalty': frequencyPenalty,
      'presence_penalty': presencePenalty,
      'stream': stream,
    };

    if (maxTokens != null) {
      data['max_tokens'] = maxTokens;
    }

    return data;
  }
}

class ChatCompletionMessage {
  const ChatCompletionMessage({required this.role, required this.content});

  final String role;
  final String content;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'role': role, 'content': content};
  }
}
