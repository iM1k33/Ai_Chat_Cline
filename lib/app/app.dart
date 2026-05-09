import 'package:aichatcline/app/app_theme.dart';
import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/chat/ui/chat_screen.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/settings/ui/settings_screen.dart';
import 'package:aichatcline/features/statistics/ui/statistics_screen.dart';
import 'package:flutter/material.dart';

class AIChatApp extends StatefulWidget {
  const AIChatApp({super.key});

  @override
  State<AIChatApp> createState() => _AIChatAppState();
}

class _AIChatAppState extends State<AIChatApp> {
  late final AppDatabase _appDatabase;
  late final ChatRepository _chatRepository;
  late final ChatController _chatController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();

    _appDatabase = AppDatabase();
    _chatRepository = ChatRepository(appDatabase: _appDatabase);
    _chatController = ChatController(chatRepository: _chatRepository);

    _settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
    );

    _settingsController.load();
    _chatController.load();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _settingsController.dispose();
    _appDatabase.close();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: _settingsController),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StatisticsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: Builder(
        builder: (context) {
          return ChatScreen(
            controller: _chatController,
            onOpenSettings: () => _openSettings(context),
            onOpenStatistics: () => _openStatistics(context),
          );
        },
      ),
    );
  }
}
