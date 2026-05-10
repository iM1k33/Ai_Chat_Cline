import 'dart:convert';

import 'package:aichatcline/data/repositories/logs_repository.dart';
import 'package:aichatcline/features/logs/models/app_log_entry.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:uuid/uuid.dart';

class AppLogger {
  AppLogger({
    required LogsRepository logsRepository,
    SettingsController? settingsController,
    Uuid? uuid,
  }) : _logsRepository = logsRepository,
       _settingsController = settingsController,
       _uuid = uuid ?? const Uuid();

  static const int _maxSnippetLength = 300;
  static final Object _omitField = Object();

  static const Set<String> _safeTechnicalFields = <String>{
    'providerid',
    'modelid',
    'streaming',
    'messagescount',
    'prompttokens',
    'completiontokens',
    'totaltokens',
    'responsetimems',
    'estimatedcost',
    'currencycode',
    'conversationid',
    'messageid',
    'statuscode',
    'errorcode',
  };

  static const Set<String> _messageContentFields = <String>{
    'content',
    'messagecontent',
    'usermessage',
    'assistantmessage',
    'systemprompt',
    'requestmessages',
    'responsetext',
    'prompt',
    'completion',
    'lastusermessagesnippet',
    'assistantresponsesnippet',
    'systempromptsnippet',
    'lastrequestmessagesnippet',
  };

  final LogsRepository _logsRepository;
  final Uuid _uuid;
  SettingsController? _settingsController;

  void attachSettingsController(SettingsController settingsController) {
    _settingsController = settingsController;
  }

  Future<void> logInfo({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    return _log(
      level: 'info',
      category: category,
      message: message,
      metadata: metadata,
    );
  }

  Future<void> logWarning({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    return _log(
      level: 'warning',
      category: category,
      message: message,
      metadata: metadata,
    );
  }

  Future<void> logError({
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
  }) {
    return _log(
      level: 'error',
      category: category,
      message: message,
      metadata: metadata,
    );
  }

  String? buildMessageContentSnippet(String content) {
    if (!_includeMessageContentInLogs) {
      return null;
    }

    return _shortSnippet(content);
  }

  bool get includeMessageContentInLogs => _includeMessageContentInLogs;

  Future<void> _log({
    required String level,
    required String category,
    required String message,
    Map<String, dynamic>? metadata,
  }) async {
    final String normalizedMessage = _shortSnippet(message);
    if (normalizedMessage.trim().isEmpty) {
      return;
    }

    final AppLogEntry entry = AppLogEntry(
      id: _uuid.v4(),
      createdAt: DateTime.now(),
      level: level,
      category: category.trim().isEmpty ? 'app' : category.trim(),
      message: normalizedMessage,
      metadata: _sanitizeMetadata(metadata),
    );

    try {
      await _logsRepository.insertLog(entry);
    } catch (_) {
      // Logging must never crash app flows.
    }
  }

  Map<String, dynamic>? _sanitizeMetadata(Map<String, dynamic>? metadata) {
    if (metadata == null || metadata.isEmpty) {
      return null;
    }

    final Map<String, dynamic> sanitized = <String, dynamic>{};
    metadata.forEach((String key, dynamic value) {
      final dynamic sanitizedValue = _sanitizeValue(
        keyPath: key,
        leafKey: key,
        value: value,
      );
      if (!identical(sanitizedValue, _omitField)) {
        sanitized[key] = sanitizedValue;
      }
    });

    return sanitized.isEmpty ? null : sanitized;
  }

  dynamic _sanitizeValue({
    required String keyPath,
    required String leafKey,
    required dynamic value,
  }) {
    final String normalizedLeaf = _normalizeComparableKey(leafKey);

    if (_isSensitiveKey(keyPath: keyPath, leafKey: leafKey)) {
      return '[REDACTED]';
    }

    if (_messageContentFields.contains(normalizedLeaf) &&
        !_includeMessageContentInLogs) {
      return _omitField;
    }

    if (value is Map<String, dynamic>) {
      final Map<String, dynamic> nested = <String, dynamic>{};
      value.forEach((String nestedKey, dynamic nestedValue) {
        final String nestedPath = '$keyPath.$nestedKey';
        final dynamic sanitizedNestedValue = _sanitizeValue(
          keyPath: nestedPath,
          leafKey: nestedKey,
          value: nestedValue,
        );
        if (!identical(sanitizedNestedValue, _omitField)) {
          nested[nestedKey] = sanitizedNestedValue;
        }
      });
      return nested.isEmpty ? _omitField : nested;
    }

    if (value is List<dynamic>) {
      final List<dynamic> sanitizedItems = value
          .map(
            (dynamic item) => _sanitizeValue(
              keyPath: keyPath,
              leafKey: leafKey,
              value: item,
            ),
          )
          .where((dynamic item) => !identical(item, _omitField))
          .toList();

      if (sanitizedItems.isEmpty) {
        return _omitField;
      }

      if (_messageContentFields.contains(normalizedLeaf)) {
        return _shortSnippet(jsonEncode(sanitizedItems));
      }

      return sanitizedItems;
    }

    if (value is String) {
      if (_messageContentFields.contains(normalizedLeaf)) {
        return _shortSnippet(value);
      }

      if (_looksLikeBearerValue(value)) {
        return '[REDACTED]';
      }

      return _shortSnippet(value);
    }

    if (_safeTechnicalFields.contains(normalizedLeaf)) {
      return value;
    }

    return value;
  }

  bool get _includeMessageContentInLogs {
    return _settingsController?.settings.includeMessageContentInLogs ?? false;
  }

  bool _isSensitiveKey({required String keyPath, required String leafKey}) {
    final String normalizedLeaf = _normalizeComparableKey(leafKey);
    final String normalizedPath = _normalizeComparableKey(keyPath);

    if (_safeTechnicalFields.contains(normalizedLeaf)) {
      return false;
    }

    if (normalizedLeaf == 'apikey' ||
        normalizedLeaf == 'authorization' ||
        normalizedLeaf == 'auth' ||
        normalizedLeaf == 'bearertoken') {
      return true;
    }

    if (normalizedLeaf == 'token' || normalizedLeaf.endsWith('token')) {
      return true;
    }

    if (normalizedPath.endsWith('headersauthorization')) {
      return true;
    }

    return false;
  }

  bool _looksLikeBearerValue(String value) {
    return value.trimLeft().toLowerCase().startsWith('bearer ');
  }

  String _normalizeComparableKey(String key) {
    return key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _shortSnippet(String value) {
    final String compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _maxSnippetLength) {
      return compact;
    }

    return '${compact.substring(0, _maxSnippetLength)}...';
  }
}
