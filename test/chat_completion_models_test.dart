import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatCompletionRequest', () {
    test('uses OpenAI-compatible field names', () {
      const ChatCompletionRequest request = ChatCompletionRequest(
        model: 'gpt-test',
        messages: <ChatCompletionMessage>[
          ChatCompletionMessage(role: 'user', content: 'Hello'),
        ],
        temperature: 0.7,
        maxTokens: 120,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        stream: false,
      );

      final Map<String, dynamic> json = request.toJson();

      expect(json['model'], 'gpt-test');
      expect(json['messages'], isA<List<dynamic>>());
      expect(json['temperature'], 0.7);
      expect(json['max_tokens'], 120);
      expect(json['top_p'], 1.0);
      expect(json['frequency_penalty'], 0.0);
      expect(json['presence_penalty'], 0.0);
      expect(json['stream'], false);
    });

    test('omits max_tokens when null', () {
      const ChatCompletionRequest request = ChatCompletionRequest(
        model: 'gpt-test',
        messages: <ChatCompletionMessage>[
          ChatCompletionMessage(role: 'user', content: 'Hello'),
        ],
        temperature: 0.7,
        maxTokens: null,
        topP: 1.0,
        frequencyPenalty: 0.0,
        presencePenalty: 0.0,
        stream: false,
      );

      final Map<String, dynamic> json = request.toJson();

      expect(json.containsKey('max_tokens'), isFalse);
    });
  });

  group('ChatCompletionResponse', () {
    test('extracts content and usage', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'model': 'gpt-test',
        'choices': <dynamic>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': 'Hi from assistant'},
          },
        ],
        'usage': <String, dynamic>{
          'prompt_tokens': 10,
          'completion_tokens': 20,
          'total_tokens': 30,
        },
      };

      final ChatCompletionResponse response = ChatCompletionResponse.fromJson(
        json,
        providerId: 'openrouter',
      );

      expect(response.content, 'Hi from assistant');
      expect(response.model, 'gpt-test');
      expect(response.providerId, 'openrouter');
      expect(response.promptTokens, 10);
      expect(response.completionTokens, 20);
      expect(response.totalTokens, 30);
    });

    test('handles missing usage safely', () {
      final Map<String, dynamic> json = <String, dynamic>{
        'choices': <dynamic>[
          <String, dynamic>{
            'message': <String, dynamic>{'content': 'No usage block'},
          },
        ],
      };

      final ChatCompletionResponse response = ChatCompletionResponse.fromJson(
        json,
      );

      expect(response.content, 'No usage block');
      expect(response.promptTokens, isNull);
      expect(response.completionTokens, isNull);
      expect(response.totalTokens, isNull);
    });
  });
}
