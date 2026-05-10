import 'package:aichatcline/features/logs/models/app_log_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppLogEntry JSON round trip preserves fields', () {
    final AppLogEntry entry = AppLogEntry(
      id: 'log-1',
      createdAt: DateTime.parse('2026-01-02T03:04:05.000Z'),
      level: 'info',
      category: 'api',
      message: 'request started',
      metadata: <String, dynamic>{
        'providerId': 'openrouter',
        'streaming': true,
      },
    );

    final Map<String, dynamic> json = entry.toJson();
    final AppLogEntry restored = AppLogEntry.fromJson(json);

    expect(restored.id, entry.id);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.level, entry.level);
    expect(restored.category, entry.category);
    expect(restored.message, entry.message);
    expect(restored.metadata, entry.metadata);
  });

  test('AppLogEntry map round trip preserves fields', () {
    final AppLogEntry entry = AppLogEntry(
      id: 'log-2',
      createdAt: DateTime.parse('2026-01-02T03:04:05.000Z'),
      level: 'error',
      category: 'chat',
      message: 'request failed',
      metadata: <String, dynamic>{
        'errorType': 'AppException',
        'responseTimeMs': 1234,
      },
    );

    final Map<String, Object?> map = entry.toMap();
    final AppLogEntry restored = AppLogEntry.fromMap(map);

    expect(restored.id, entry.id);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.level, entry.level);
    expect(restored.category, entry.category);
    expect(restored.message, entry.message);
    expect(restored.metadata, entry.metadata);
  });
}
