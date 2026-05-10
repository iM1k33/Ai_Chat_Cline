import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/logs_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/logs/models/app_log_entry.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLogsRepository extends LogsRepository {
  _FakeLogsRepository() : super(appDatabase: AppDatabase());

  final List<AppLogEntry> inserted = <AppLogEntry>[];

  @override
  Future<void> insertLog(AppLogEntry entry) async {
    inserted.add(entry);
  }

  @override
  Future<List<AppLogEntry>> getLogs({int limit = 500}) async {
    return inserted;
  }

  @override
  Future<void> deleteAllLogs() async {
    inserted.clear();
  }
}

void main() {
  test('logger redacts sensitive fields and removes content fields by default', () async {
    final _FakeLogsRepository repo = _FakeLogsRepository();
    final AppLogger logger = AppLogger(logsRepository: repo);

    await logger.logInfo(
      category: 'api',
      message: 'Chat request started',
      metadata: <String, dynamic>{
        'apiKey': 'sk-secret',
        'authorization': 'Bearer secret',
        'headers': <String, dynamic>{
          'Authorization': 'Bearer nested-secret',
        },
        'content': 'this should not be persisted in logs by default',
        'promptTokens': 123,
        'completionTokens': 456,
        'totalTokens': 579,
        'responseTimeMs': 999,
        'nested': <String, dynamic>{
          'token': 'nested-secret',
        },
      },
    );

    expect(repo.inserted.length, 1);
    final AppLogEntry entry = repo.inserted.single;
    final Map<String, dynamic> metadata = entry.metadata!;

    expect(metadata['apiKey'], '[REDACTED]');
    expect(metadata['authorization'], '[REDACTED]');
    expect(metadata.containsKey('content'), isFalse);
    expect((metadata['headers'] as Map<String, dynamic>)['Authorization'], '[REDACTED]');
    expect(metadata['promptTokens'], 123);
    expect(metadata['completionTokens'], 456);
    expect(metadata['totalTokens'], 579);
    expect(metadata['responseTimeMs'], 999);
    expect((metadata['nested'] as Map<String, dynamic>)['token'], '[REDACTED]');
  });

  test('logger keeps content as short snippet when enabled in settings', () async {
    final _FakeLogsRepository repo = _FakeLogsRepository();
    final AppLogger logger = AppLogger(logsRepository: repo);

    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );
    settingsController.settings = settingsController.settings.copyWith(
      includeMessageContentInLogs: true,
    );
    logger.attachSettingsController(settingsController);

    final String longContent = List<String>.filled(600, 'x').join();

    await logger.logInfo(
      category: 'chat',
      message: 'Chat request succeeded',
      metadata: <String, dynamic>{
        'content': longContent,
      },
    );

    final AppLogEntry entry = repo.inserted.single;
    final String snippet = entry.metadata!['content'] as String;

    expect(snippet, isNotEmpty);
    expect(snippet.length, lessThanOrEqualTo(303));
    expect(snippet.startsWith('x'), isTrue);
  });

  test('logger keeps explicit snippet fields only when enabled', () async {
    final _FakeLogsRepository repo = _FakeLogsRepository();
    final AppLogger logger = AppLogger(logsRepository: repo);

    await logger.logInfo(
      category: 'api',
      message: 'Chat request started',
      metadata: <String, dynamic>{
        'lastUserMessageSnippet': 'hello user',
        'providerId': 'openrouter',
      },
    );

    final AppLogEntry first = repo.inserted.single;
    expect(first.metadata!.containsKey('lastUserMessageSnippet'), isFalse);
    expect(first.metadata!['providerId'], 'openrouter');

    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );
    settingsController.settings = settingsController.settings.copyWith(
      includeMessageContentInLogs: true,
    );
    logger.attachSettingsController(settingsController);

    await logger.logInfo(
      category: 'api',
      message: 'Chat request started',
      metadata: <String, dynamic>{
        'lastUserMessageSnippet': 'hello user',
        'providerId': 'openrouter',
      },
    );

    final AppLogEntry second = repo.inserted.last;
    expect(second.metadata!['lastUserMessageSnippet'], 'hello user');
    expect(second.metadata!['providerId'], 'openrouter');
  });
}
