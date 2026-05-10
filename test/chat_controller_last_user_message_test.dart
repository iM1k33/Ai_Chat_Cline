import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lastUserMessage returns latest user message', () {
    final AppDatabase appDatabase = AppDatabase();
    final SettingsController settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: OpenAICompatibleClient(),
    );
    final ModelCatalogController modelCatalogController =
        ModelCatalogController(
          aiClient: OpenAICompatibleClient(),
          settingsController: settingsController,
        );

    final ChatController controller = ChatController(
      chatRepository: ChatRepository(appDatabase: appDatabase),
      settingsController: settingsController,
      modelCatalogController: modelCatalogController,
      aiClient: OpenAICompatibleClient(),
      statsRepository: StatsRepository(appDatabase: appDatabase),
    );

    controller.messages = <ChatMessage>[
      ChatMessage(
        id: 'u1',
        conversationId: 'c1',
        role: ChatMessageRole.user,
        content: 'first',
        createdAt: DateTime.parse('2026-05-10T09:00:00Z'),
      ),
      ChatMessage(
        id: 'a1',
        conversationId: 'c1',
        role: ChatMessageRole.assistant,
        content: 'reply',
        createdAt: DateTime.parse('2026-05-10T09:00:10Z'),
      ),
      ChatMessage(
        id: 'u2',
        conversationId: 'c1',
        role: ChatMessageRole.user,
        content: 'edited target',
        createdAt: DateTime.parse('2026-05-10T09:01:00Z'),
      ),
    ];

    expect(controller.lastUserMessage, isNotNull);
    expect(controller.lastUserMessage!.id, 'u2');
    expect(controller.lastUserMessage!.content, 'edited target');
  });
}
