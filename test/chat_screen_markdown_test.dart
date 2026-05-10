import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/chat/models/chat_message.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/chat/ui/chat_screen.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<(ChatController, ModelCatalogController)> buildControllers() async {
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

    final ChatController chatController = ChatController(
      chatRepository: ChatRepository(appDatabase: appDatabase),
      settingsController: settingsController,
      modelCatalogController: modelCatalogController,
      aiClient: OpenAICompatibleClient(),
      statsRepository: StatsRepository(appDatabase: appDatabase),
    );

    return (chatController, modelCatalogController);
  }

  testWidgets(
    'assistant markdown renders and code block copy button is shown',
    (WidgetTester tester) async {
      final (
        ChatController chatController,
        ModelCatalogController modelCatalogController,
      ) = await buildControllers();

      chatController.messages = <ChatMessage>[
        ChatMessage(
          id: 'assistant-1',
          conversationId: 'conv-1',
          role: ChatMessageRole.assistant,
          content: '# Title\n\n```dart\nprint("hello");\n```',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            controller: chatController,
            modelCatalogController: modelCatalogController,
            exportService: const ExportService(),
            shareService: const ShareService(),
            providerName: 'OpenRouter',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Title'), findsOneWidget);
      expect(find.byTooltip('Copy code'), findsOneWidget);
    },
  );

  testWidgets('empty state shows Start a conversation', (
    WidgetTester tester,
  ) async {
    final (
      ChatController chatController,
      ModelCatalogController modelCatalogController,
    ) = await buildControllers();

    chatController.messages = <ChatMessage>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          controller: chatController,
          modelCatalogController: modelCatalogController,
          exportService: const ExportService(),
          shareService: const ShareService(),
          providerName: 'OpenRouter',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Start a conversation'), findsOneWidget);
  });

  testWidgets('assistant error message has subtle error styling icon', (
    WidgetTester tester,
  ) async {
    final (
      ChatController chatController,
      ModelCatalogController modelCatalogController,
    ) = await buildControllers();

    chatController.messages = <ChatMessage>[
      ChatMessage(
        id: 'assistant-error-1',
        conversationId: 'conv-1',
        role: ChatMessageRole.assistant,
        content: 'Error: test failure',
        createdAt: DateTime.now(),
        error: 'test failure',
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ChatScreen(
          controller: chatController,
          modelCatalogController: modelCatalogController,
          exportService: const ExportService(),
          shareService: const ShareService(),
          providerName: 'OpenRouter',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets(
    'streaming assistant message with incomplete fence renders safely',
    (WidgetTester tester) async {
      final (
        ChatController chatController,
        ModelCatalogController modelCatalogController,
      ) = await buildControllers();

      chatController.messages = <ChatMessage>[
        ChatMessage(
          id: 'assistant-streaming-1',
          conversationId: 'conv-1',
          role: ChatMessageRole.assistant,
          content: '```dart\nprint("partial")',
          createdAt: DateTime.now(),
        ),
      ];
      chatController.isStreaming = true;
      chatController.streamingMessageId = 'assistant-streaming-1';

      await tester.pumpWidget(
        MaterialApp(
          home: ChatScreen(
            controller: chatController,
            modelCatalogController: modelCatalogController,
            exportService: const ExportService(),
            shareService: const ShareService(),
            providerName: 'OpenRouter',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('print("partial")'), findsOneWidget);
      expect(find.byTooltip('Copy code'), findsNothing);
    },
  );
}
