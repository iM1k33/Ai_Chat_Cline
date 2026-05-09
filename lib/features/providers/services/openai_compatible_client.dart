import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/chat_completion_request.dart';
import 'package:aichatcline/features/providers/models/chat_completion_response.dart';
import 'package:http/http.dart' as http;

class OpenAICompatibleClient {
  OpenAICompatibleClient({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

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
}
