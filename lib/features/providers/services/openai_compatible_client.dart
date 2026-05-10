import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_model.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:http/http.dart' as http;

class OpenAICompatibleClient {
  OpenAICompatibleClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<List<AIModel>> fetchModels({
    required AIProvider provider,
    required String apiKey,
  }) async {
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AppException('API key is required');
    }

    final String baseUrl = provider.baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AppException('Provider base URL is required');
    }

    final Uri uri = Uri.parse('$baseUrl/models');
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $trimmedKey',
      'Accept': 'application/json',
    };

    if (provider.type == AIProviderType.openRouter) {
      headers['HTTP-Referer'] = 'https://localhost';
      headers['X-Title'] = 'AI Chat';
    }

    try {
      final http.Response response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode > 299) {
        throw AppException(
          'Failed to load models: HTTP ${response.statusCode}. ${_bodySnippet(response.body)}',
          code: 'http_${response.statusCode}',
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppException('Invalid models response format');
      }

      final Object? data = decoded['data'];
      if (data is! List<dynamic>) {
        throw const AppException('Models response does not contain a valid data list');
      }

      final List<AIModel> models = <AIModel>[];
      for (final Object? item in data) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final String id = (item['id'] as String?)?.trim() ?? '';
        if (id.isEmpty) {
          continue;
        }

        final String name = ((item['name'] as String?)?.trim().isNotEmpty ?? false)
            ? (item['name'] as String).trim()
            : id;

        final Object? topProviderRaw = item['top_provider'];
        final Map<String, dynamic>? topProvider =
            topProviderRaw is Map<String, dynamic> ? topProviderRaw : null;

        final Object? pricingRaw = item['pricing'];
        final Map<String, dynamic>? pricing =
            pricingRaw is Map<String, dynamic> ? pricingRaw : null;

        final Object? contextLengthRaw = item['context_length'] ??
            topProvider?['context_length'];

        final Object? supportsStreamingRaw =
            item['supports_streaming'] ?? item['streaming'];

        models.add(
          AIModel(
            id: id,
            name: name,
            providerId: provider.id,
            description: item['description'] as String?,
            contextLength: _parseInt(contextLengthRaw),
            promptPrice: _parseDouble(pricing?['prompt']),
            completionPrice: _parseDouble(pricing?['completion']),
            currencyCode: provider.type == AIProviderType.vsegpt ? 'RUB' : 'USD',
            supportsStreaming: supportsStreamingRaw is bool
                ? supportsStreamingRaw
                : true,
          ),
        );
      }

      return models;
    } on TimeoutException catch (e) {
      throw AppException(
        'Models request timed out',
        code: 'timeout',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AppException(
        'Invalid models response format',
        code: 'invalid_response',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        'Failed to load models',
        code: 'request_failed',
        cause: e,
      );
    }
  }

  Future<ChatCompletionResponse> createChatCompletion({
    required AIProvider provider,
    required String apiKey,
    required ChatCompletionRequest request,
  }) async {
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AppException('API key is required');
    }

    final String baseUrl = provider.baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AppException('Provider base URL is required');
    }

    final Uri uri = Uri.parse('$baseUrl/chat/completions');

    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $trimmedKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (provider.type == AIProviderType.openRouter) {
      headers['HTTP-Referer'] = 'https://localhost';
      headers['X-Title'] = 'AI Chat';
    }

    try {
      final http.Response response = await _httpClient
          .post(uri, headers: headers, body: jsonEncode(request.toJson()))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode < 200 || response.statusCode > 299) {
        final String snippet = _bodySnippet(response.body);
        throw AppException(
          'Chat completion request failed: HTTP ${response.statusCode}. $snippet',
          code: 'http_${response.statusCode}',
        );
      }

      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const AppException('Invalid chat completion response format');
      }

      return ChatCompletionResponse.fromJson(decoded, providerId: provider.id);
    } on TimeoutException catch (e) {
      throw AppException(
        'Chat completion request timed out',
        code: 'timeout',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        'Failed to create chat completion request',
        code: 'request_failed',
        cause: e,
      );
    }
  }

  Stream<ChatCompletionStreamChunk> createChatCompletionStream({
    required AIProvider provider,
    required String apiKey,
    required ChatCompletionRequest request,
  }) {
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AppException('API key is required');
    }

    final String baseUrl = provider.baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AppException('Provider base URL is required');
    }

    final Uri uri = Uri.parse('$baseUrl/chat/completions');

    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $trimmedKey',
      'Content-Type': 'application/json',
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
    };

    if (provider.type == AIProviderType.openRouter) {
      headers['HTTP-Referer'] = 'https://localhost';
      headers['X-Title'] = 'AI Chat';
    }

    final Map<String, dynamic> requestBody = Map<String, dynamic>.from(
      request.toJson(),
    );
    requestBody['stream'] = true;

    final http.Request streamedRequest = http.Request('POST', uri)
      ..headers.addAll(headers)
      ..body = jsonEncode(requestBody);

    final StreamController<ChatCompletionStreamChunk> controller =
        StreamController<ChatCompletionStreamChunk>();

    unawaited(
      () async {
        try {
          final http.StreamedResponse response = await _httpClient
              .send(streamedRequest)
              .timeout(const Duration(seconds: 60));

          if (response.statusCode < 200 || response.statusCode > 299) {
            final String errorBody = await response.stream.bytesToString();
            throw AppException(
              'Chat completion stream request failed: HTTP ${response.statusCode}. ${_bodySnippet(errorBody)}',
              code: 'http_${response.statusCode}',
            );
          }

          final Stream<String> lines = response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter());

          final StringBuffer eventDataBuffer = StringBuffer();

          await for (final String rawLine in lines) {
            final String line = rawLine.trimRight();
            if (line.isEmpty) {
              _emitStreamChunkFromEventData(
                eventDataBuffer.toString(),
                controller,
              );
              eventDataBuffer.clear();
              continue;
            }

            if (line.startsWith('data:')) {
              eventDataBuffer.writeln(line.substring(5).trimLeft());
            }
          }

          _emitStreamChunkFromEventData(eventDataBuffer.toString(), controller);

          if (!controller.isClosed) {
            await controller.close();
          }
        } on TimeoutException catch (e) {
          if (!controller.isClosed) {
            controller.addError(
              AppException(
                'Chat completion stream request timed out',
                code: 'timeout',
                cause: e,
              ),
            );
            await controller.close();
          }
        } on AppException catch (e) {
          if (!controller.isClosed) {
            controller.addError(e);
            await controller.close();
          }
        } catch (e) {
          if (!controller.isClosed) {
            controller.addError(
              AppException(
                'Failed to create chat completion stream request',
                code: 'request_failed',
                cause: e,
              ),
            );
            await controller.close();
          }
        }
      }(),
    );

    return controller.stream;
  }

  Future<void> validateApiKey({
    required AIProvider provider,
    required String apiKey,
  }) async {
    final String trimmedKey = apiKey.trim();
    if (trimmedKey.isEmpty) {
      throw const AppException('API key is required');
    }

    final String baseUrl = provider.baseUrl.trim();
    if (baseUrl.isEmpty) {
      throw const AppException('Provider base URL is required');
    }

    switch (provider.type) {
      case AIProviderType.openRouter:
        await _validateOpenRouterKey(baseUrl: baseUrl, apiKey: trimmedKey);
        return;
      case AIProviderType.vsegpt:
        await _validateVsegptKey(baseUrl: baseUrl, apiKey: trimmedKey);
        return;
      case AIProviderType.custom:
        throw const AppException(
          'Custom provider validation is not supported yet',
          code: 'validation_failed',
        );
    }
  }

  Future<void> _validateOpenRouterKey({
    required String baseUrl,
    required String apiKey,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/credits');
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Accept': 'application/json',
      'HTTP-Referer': 'https://localhost',
      'X-Title': 'AI Chat',
    };

    await _executeValidationRequest(uri: uri, headers: headers);
  }

  Future<void> _validateVsegptKey({
    required String baseUrl,
    required String apiKey,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/chat/completions');
    final Map<String, String> headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final Map<String, dynamic> probeBody = <String, dynamic>{
      'model': '__aichat_validation_probe__',
      'messages': <Map<String, String>>[
        <String, String>{'role': 'user', 'content': 'ping'},
      ],
      'max_tokens': 1,
      'temperature': 0,
      'stream': false,
    };

    final String encodedProbeBody = jsonEncode(probeBody);

    try {
      final http.Response response = await _httpClient
          .post(uri, headers: headers, body: encodedProbeBody)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode <= 299) {
        return;
      }

      final String extractedMessage = _extractValidationErrorMessage(
        response.body,
      );

      if (_looksLikeVsegptAuthError(extractedMessage)) {
        throw AppException(
          'API key validation failed with status ${response.statusCode}: ${_bodySnippet(extractedMessage)}',
          code: 'validation_failed',
        );
      }

      if (_looksLikeVsegptModelOrRequestError(extractedMessage)) {
        return;
      }

      throw AppException(
        'API key validation failed with status ${response.statusCode}: ${_bodySnippet(extractedMessage)}',
        code: 'validation_failed',
      );
    } on TimeoutException catch (e) {
      throw AppException(
        'API key validation timed out',
        code: 'validation_failed',
        cause: e,
      );
    } on SocketException catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.message)}',
        code: 'validation_failed',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.message)}',
        code: 'validation_failed',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AppException(
        'API key validation failed: Invalid response format',
        code: 'validation_failed',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.toString())}',
        code: 'validation_failed',
        cause: e,
      );
    }
  }

  Future<void> _executeValidationRequest({
    required Uri uri,
    required Map<String, String> headers,
    void Function(String body)? bodyValidator,
  }) async {
    try {
      final http.Response response = await _httpClient
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode < 200 || response.statusCode > 299) {
        final String snippet = _bodySnippet(response.body);
        throw AppException(
          'API key validation failed with status ${response.statusCode}: $snippet',
          code: 'validation_failed',
        );
      }

      if (bodyValidator != null) {
        bodyValidator(response.body);
      }
    } on TimeoutException catch (e) {
      throw AppException(
        'API key validation timed out',
        code: 'validation_failed',
        cause: e,
      );
    } on SocketException catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.message)}',
        code: 'validation_failed',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.message)}',
        code: 'validation_failed',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.message)}',
        code: 'validation_failed',
        cause: e,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException(
        'API key validation network error: ${_safeErrorText(e.toString())}',
        code: 'validation_failed',
        cause: e,
      );
    }
  }

  void _emitStreamChunkFromEventData(
    String rawEventData,
    StreamController<ChatCompletionStreamChunk> controller,
  ) {
    final String eventData = rawEventData.trim();
    if (eventData.isEmpty || controller.isClosed) {
      return;
    }

    if (eventData == '[DONE]') {
      controller.add(
        const ChatCompletionStreamChunk(delta: '', isDone: true),
      );
      return;
    }

    Object? decoded;
    try {
      decoded = jsonDecode(eventData);
    } on FormatException catch (e) {
      throw AppException(
        'Invalid stream chunk format',
        code: 'invalid_response',
        cause: e,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      return;
    }

    String delta = '';
    final Object? choices = decoded['choices'];
    if (choices is List<dynamic> && choices.isNotEmpty) {
      final Object? firstChoice = choices.first;
      if (firstChoice is Map<String, dynamic>) {
        final Object? deltaRaw = firstChoice['delta'];
        if (deltaRaw is Map<String, dynamic>) {
          final Object? content = deltaRaw['content'];
          if (content is String) {
            delta = content;
          }
        }
      }
    }

    final Map<String, dynamic>? usage =
        decoded['usage'] as Map<String, dynamic>?;

    controller.add(
      ChatCompletionStreamChunk(
        delta: delta,
        model: decoded['model'] as String?,
        promptTokens: (usage?['prompt_tokens'] as num?)?.toInt(),
        completionTokens: (usage?['completion_tokens'] as num?)?.toInt(),
        totalTokens: (usage?['total_tokens'] as num?)?.toInt(),
        isDone: false,
      ),
    );
  }

  String _bodySnippet(String body) {
    final String trimmed = body.trim();
    if (trimmed.isEmpty) {
      return 'Empty response body';
    }

    if (trimmed.length <= 300) {
      return trimmed;
    }

    return '${trimmed.substring(0, 300)}...';
  }

  String _extractValidationErrorMessage(String responseBody) {
    final String snippet = _bodySnippet(responseBody);
    if (responseBody.trim().isEmpty) {
      return snippet;
    }

    try {
      final Object? decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final Object? error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final Object? message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message.trim();
          }
          final Object? code = error['code'];
          if (code != null) {
            return code.toString();
          }
        }

        if (error is String && error.trim().isNotEmpty) {
          return error.trim();
        }

        final Object? message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message.trim();
        }

        final Object? detail = decoded['detail'];
        if (detail is String && detail.trim().isNotEmpty) {
          return detail.trim();
        }
      }
    } on FormatException {
      throw const FormatException('Invalid JSON response body');
    }

    return snippet;
  }

  bool _looksLikeVsegptAuthError(String value) {
    final String text = value.toLowerCase();
    const List<String> authIndicators = <String>[
      'api key not found',
      'user with this api key not found',
      'invalid api key',
      'incorrect api key',
      'unauthorized',
      'forbidden',
      'authentication',
      'auth',
      'token',
      'ключ',
      'пользователь',
      'авторизац',
    ];

    return authIndicators.any(text.contains);
  }

  bool _looksLikeVsegptModelOrRequestError(String value) {
    final String text = value.toLowerCase();
    final bool hasModelKeyword =
        text.contains('model') ||
        text.contains('модель') ||
        text.contains('model_id');

    if (text.contains('invalid model') ||
        text.contains('unknown model') ||
        (text.contains('does not exist') && hasModelKeyword)) {
      return true;
    }

    if (text.contains('not found') && hasModelKeyword) {
      return true;
    }

    return hasModelKeyword;
  }

  String _safeErrorText(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Unknown network error';
    }

    if (trimmed.length <= 200) {
      return trimmed;
    }

    return '${trimmed.substring(0, 200)}...';
  }

  int? _parseInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  double? _parseDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }
}
