import 'dart:convert';

import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
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

http.StreamedResponse _response({required int statusCode, String body = ''}) {
  return http.StreamedResponse(
    Stream<List<int>>.value(utf8.encode(body)),
    statusCode,
    headers: const <String, String>{'content-type': 'application/json'},
  );
}

void main() {
  test('OpenRouter validation uses /credits and 401 throws AppException', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;

    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return _response(statusCode: 401, body: '{"error":"unauthorized"}');
      }),
    );

    await expectLater(
      () => client.validateApiKey(
        provider: AIProvider.openRouter,
        apiKey: 'sk-or-v1-invalid',
      ),
      throwsA(isA<AppException>()),
    );

    expect(requestedUri.toString(), 'https://openrouter.ai/api/v1/credits');
    expect(requestedHeaders['Authorization'], 'Bearer sk-or-v1-invalid');
    expect(requestedHeaders['Accept'], 'application/json');
    expect(requestedHeaders['HTTP-Referer'], 'https://localhost');
    expect(requestedHeaders['X-Title'], 'AI Chat');
  });

  test('VSEGPT validation uses chat/completions and model-not-found passes', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;

    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return _response(
          statusCode: 400,
          body:
              '{"error":{"message":"Model __aichat_validation_probe__ not found","code":400}}',
        );
      }),
    );

    await client.validateApiKey(
      provider: AIProvider.vsegpt,
      apiKey: 'sk-or-vv-valid',
    );

    expect(
      requestedUri.toString(),
      'https://api.vsegpt.ru/v1/chat/completions',
    );
    expect(requestedHeaders['Authorization'], 'Bearer sk-or-vv-valid');
    expect(requestedHeaders['Content-Type'], 'application/json');
    expect(requestedHeaders['Accept'], 'application/json');
    expect(requestedHeaders.containsKey('HTTP-Referer'), isFalse);
    expect(requestedHeaders.containsKey('X-Title'), isFalse);
  });

  test(
    'VSEGPT wrong key response with user-not-found auth message fails',
    () async {
      final OpenAICompatibleClient client = OpenAICompatibleClient(
        httpClient: _FakeHttpClient((http.BaseRequest request) async {
          return _response(
            statusCode: 400,
            body:
                '{"error":{"message":"User with this API key not found","code":400}}',
          );
        }),
      );

      await expectLater(
        () => client.validateApiKey(
          provider: AIProvider.vsegpt,
          apiKey: 'sk-or-vv-invalid',
        ),
        throwsA(isA<AppException>()),
      );
    },
  );

  test('VSEGPT validation uses chat/completions and 401 throws AppException', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;

    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return _response(statusCode: 401, body: '{"error":"unauthorized"}');
      }),
    );

    await expectLater(
      () => client.validateApiKey(
        provider: AIProvider.vsegpt,
        apiKey: 'sk-or-vv-invalid',
      ),
      throwsA(isA<AppException>()),
    );

    expect(
      requestedUri.toString(),
      'https://api.vsegpt.ru/v1/chat/completions',
    );
    expect(requestedHeaders['Authorization'], 'Bearer sk-or-vv-invalid');
    expect(requestedHeaders['Content-Type'], 'application/json');
    expect(requestedHeaders['Accept'], 'application/json');
    expect(requestedHeaders.containsKey('HTTP-Referer'), isFalse);
    expect(requestedHeaders.containsKey('X-Title'), isFalse);
  });

  test('VSEGPT model-not-found response should pass validation', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(
          statusCode: 400,
          body:
              '{"error":{"message":"Model __aichat_validation_probe__ not found","code":400}}',
        );
      }),
    );

    await client.validateApiKey(
      provider: AIProvider.vsegpt,
      apiKey: 'sk-or-vv-valid',
    );
  });

  test('VSEGPT unknown HTTP 400 error fails validation', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(
          statusCode: 400,
          body: '{"error":{"message":"Bad request","code":400}}',
        );
      }),
    );

    await expectLater(
      () => client.validateApiKey(
        provider: AIProvider.vsegpt,
        apiKey: 'sk-or-vv-invalid',
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('VSEGPT 200 should pass validation', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(statusCode: 200, body: '{"id":"ok"}');
      }),
    );

    await client.validateApiKey(
      provider: AIProvider.vsegpt,
      apiKey: 'sk-or-vv-valid',
    );
  });

  test('VSEGPT invalid JSON on non-2xx fails validation', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(statusCode: 400, body: '{invalid-json');
      }),
    );

    await expectLater(
      () => client.validateApiKey(
        provider: AIProvider.vsegpt,
        apiKey: 'sk-or-vv-invalid',
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('Custom provider validation throws unsupported exception', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(statusCode: 200, body: '{}');
      }),
    );

    await expectLater(
      () => client.validateApiKey(
        provider: const AIProvider(
          id: 'custom',
          name: 'Custom',
          type: AIProviderType.custom,
          baseUrl: 'https://example.com',
          apiKeyPrefix: '',
          currencyCode: 'USD',
        ),
        apiKey: 'custom-key',
      ),
      throwsA(
        isA<AppException>().having(
          (AppException e) => e.message,
          'message',
          'Custom provider validation is not supported yet',
        ),
      ),
    );
  });

  test('fetchModels parses OpenRouter-like response with pricing/context', () async {
    late Uri requestedUri;
    late Map<String, String> requestedHeaders;

    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        requestedUri = request.url;
        requestedHeaders = request.headers;
        return _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'openrouter/alpha',
                'name': 'Alpha',
                'description': 'Fast model',
                'context_length': 131072,
                'pricing': <String, dynamic>{
                  'prompt': '0.0000015',
                  'completion': 0.0000025,
                },
              },
            ],
          }),
        );
      }),
    );

    final List models = await client.fetchModels(
      provider: AIProvider.openRouter,
      apiKey: 'sk-or-v1-valid',
    );

    expect(requestedUri.toString(), 'https://openrouter.ai/api/v1/models');
    expect(requestedHeaders['Authorization'], 'Bearer sk-or-v1-valid');
    expect(requestedHeaders['Accept'], 'application/json');
    expect(requestedHeaders['HTTP-Referer'], 'https://localhost');
    expect(requestedHeaders['X-Title'], 'AI Chat');

    expect(models.length, 1);
    final dynamic model = models.first;
    expect(model.id, 'openrouter/alpha');
    expect(model.name, 'Alpha');
    expect(model.providerId, 'openrouter');
    expect(model.description, 'Fast model');
    expect(model.contextLength, 131072);
    expect(model.promptPrice, 0.0000015);
    expect(model.completionPrice, 0.0000025);
    expect(model.currencyCode, 'USD');
    expect(model.supportsStreaming, isTrue);
  });

  test('fetchModels handles missing optional fields', () async {
    final OpenAICompatibleClient client = OpenAICompatibleClient(
      httpClient: _FakeHttpClient((http.BaseRequest request) async {
        return _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'data': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'vsegpt/basic',
                'top_provider': <String, dynamic>{'context_length': 8192},
              },
            ],
          }),
        );
      }),
    );

    final List models = await client.fetchModels(
      provider: AIProvider.vsegpt,
      apiKey: 'sk-or-vv-valid',
    );

    expect(models.length, 1);
    final dynamic model = models.first;
    expect(model.id, 'vsegpt/basic');
    expect(model.name, 'vsegpt/basic');
    expect(model.contextLength, 8192);
    expect(model.promptPrice, isNull);
    expect(model.completionPrice, isNull);
    expect(model.currencyCode, 'RUB');
  });
}