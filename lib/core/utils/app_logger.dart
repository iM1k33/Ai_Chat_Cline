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
      sanitized[key] = _sanitizeValue(key: key, value: value);
    });

    return sanitized.isEmpty ? null : sanitized;
  }

  dynamic _sanitizeValue({required String key, required dynamic value}) {
    if (_isSensitiveKey(key)) {
      return '[REDACTED]';
    }

    if (_isContentKey(key) && !_includeMessageContentInLogs) {
      return '[OMITTED]';
    }

    if (value is Map<String, dynamic>) {
      final Map<String, dynamic> nested = <String, dynamic>{};
      value.forEach((String nestedKey, dynamic nestedValue) {
        nested[nestedKey] =
            _sanitizeValue(key: nestedKey, value: nestedValue);
      });
      return nested;
    }

    if (value is List<dynamic>) {
      return value
          .map((dynamic item) => _sanitizeValue(key: key, value: item))
          .toList();
    }

    if (value is String) {
      return _shortSnippet(value);
    }

    return value;
  }

  bool get _includeMessageContentInLogs {
    return _settingsController?.settings.includeMessageContentInLogs ?? false;
  }

  bool _isSensitiveKey(String key) {
    final String normalized = key.toLowerCase();
    return normalized.contains('api_key') ||
        normalized.contains('apikey') ||
        normalized.contains('authorization') ||
        normalized == 'auth' ||
        normalized.contains('token') ||
        normalized.contains('bearer');
  }

  bool _isContentKey(String key) {
    final String normalized = key.toLowerCase();
    return normalized.contains('content') ||
        normalized.contains('prompt') ||
        normalized.contains('response');
  }

  String _shortSnippet(String value) {
    final String trimmed = value.trim();
    if (trimmed.length <= _maxSnippetLength) {
      return trimmed;
    }

    return '${trimmed.substring(0, _maxSnippetLength)}...';
  }
}
