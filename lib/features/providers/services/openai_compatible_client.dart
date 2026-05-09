import 'dart:async';
import 'dart:convert';

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
}
