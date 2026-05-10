import 'dart:convert';

import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

http.StreamedResponse _streamResponse({
  required int statusCode,
  required String body,
}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    headers: const <String, String>{'content-type': 'text/event-stream'},
  );
}

void main() {
  ChatCompletionRequest request() {
    return const ChatCompletionRequest(
      model: 'openrouter/gpt-4o',
      messages: <ChatCompletionMessage>[
        ChatCompletionMessage(role: 'user', content: 'Hello'),
      ],
      temperature: 0.7,
      maxTokens: 64,
      topP: 1,
      frequencyPenalty: 0,
      presencePenalty: 0,
      stream: false,
    );
  }

  test('stream parses delta chunks and [DONE]', () async {
    late http.BaseRequest capturedRequest;

    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        capturedRequest = request;
        return _streamResponse(
          statusCode: 200,
          body:
              'data: {"choices":[{"delta":{"content":"Hel"}}],"model":"openrouter/gpt-4o"}\n\n'
              'data: {"choices":[{"delta":{"content":"lo"}}],"usage":{"prompt_tokens":10,"completion_tokens":20,"total_tokens":30}}\n\n'
              'data: [DONE]\n\n',
        );
      }),
    );

    final List<ChatCompletionStreamChunk> chunks = await client
        .createChatCompletionStream(
          provider: AIProvider.openRouter,
          apiKey: 'sk-or-v1-test',
          request: request(),
        )
        .toList();

    expect(chunks.length, 3);
    expect(chunks[0].delta, 'Hel');
    expect(chunks[0].model, 'openrouter/gpt-4o');
    expect(chunks[0].isDone, isFalse);

    expect(chunks[1].delta, 'lo');
    expect(chunks[1].promptTokens, 10);
    expect(chunks[1].completionTokens, 20);
    expect(chunks[1].totalTokens, 30);
    expect(chunks[1].isDone, isFalse);

    expect(chunks[2].delta, '');
    expect(chunks[2].isDone, isTrue);

    expect(capturedRequest, isA<http.Request>());
    final http.Request sent = capturedRequest as http.Request;
    expect(sent.body, contains('"stream":true'));
  });

  test('stream parser handles missing fields safely', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _streamResponse(
          statusCode: 200,
          body:
              'data: {"choices":[{}]}\n\n'
              'data: [DONE]\n\n',
        );
      }),
    );

    final List<ChatCompletionStreamChunk> chunks = await client
        .createChatCompletionStream(
          provider: AIProvider.openRouter,
          apiKey: 'sk-or-v1-test',
          request: request(),
        )
        .toList();

    expect(chunks.length, 2);
    expect(chunks[0].delta, '');
    expect(chunks[0].isDone, isFalse);
    expect(chunks[1].isDone, isTrue);
  });

  test('stream throws AppException on non-2xx', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _streamResponse(
          statusCode: 401,
          body: '{"error":"unauthorized"}',
        );
      }),
    );

    await expectLater(
      client
          .createChatCompletionStream(
            provider: AIProvider.openRouter,
            apiKey: 'sk-or-v1-test',
            request: request(),
          )
          .toList(),
      throwsA(isA<AppException>()),
    );
  });
}
