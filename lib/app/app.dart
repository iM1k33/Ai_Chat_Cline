import 'package:aichatcline/app/app_theme.dart';
import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/chat/ui/chat_screen.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/settings/ui/initial_setup_screen.dart';
import 'package:aichatcline/features/settings/ui/settings_screen.dart';
import 'package:aichatcline/features/statistics/state/statistics_controller.dart';
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
  late final StatsRepository _statsRepository;
  late final OpenAICompatibleClient _aiClient;
  late final ChatController _chatController;
  late final SettingsController _settingsController;
  late final ModelCatalogController _modelCatalogController;
  late final StatisticsController _statisticsController;
  late final ExportService _exportService;
  late final ShareService _shareService;

  @override
  void initState() {
    super.initState();

    _appDatabase = AppDatabase();
    _chatRepository = ChatRepository(appDatabase: _appDatabase);
    _statsRepository = StatsRepository(appDatabase: _appDatabase);
    _aiClient = OpenAICompatibleClient();

    _settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: _aiClient,
    );

    _chatController = ChatController(
      chatRepository: _chatRepository,
      settingsController: _settingsController,
      aiClient: _aiClient,
      statsRepository: _statsRepository,
    );

    _modelCatalogController = ModelCatalogController(
      aiClient: _aiClient,
      settingsController: _settingsController,
    );

    _statisticsController = StatisticsController(
      statsRepository: _statsRepository,
    );

    _exportService = const ExportService();
    _shareService = const ShareService();

    _settingsController.load();
    _chatController.load();
  }

  @override
  void dispose() {
    _chatController.dispose();
    _modelCatalogController.dispose();
    _settingsController.dispose();
    _statisticsController.dispose();
    _appDatabase.close();
    super.dispose();
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          controller: _settingsController,
          modelCatalogController: _modelCatalogController,
        ),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    _statisticsController.refresh();
    Navigator.of(
      context,
    ).push(
      MaterialPageRoute<void>(
        builder: (_) => StatisticsScreen(controller: _statisticsController),
      ),
    );
  }

  ThemeMode _resolveThemeMode(ThemeModeOption value) {
    return switch (value) {
      ThemeModeOption.system => ThemeMode.system,
      ThemeModeOption.light => ThemeMode.light,
      ThemeModeOption.dark => ThemeMode.dark,
    };
  }

  String _providerStatusName() {
    final String? selectedProviderId = _settingsController.settings.selectedProviderId;
    return switch (selectedProviderId) {
      'openrouter' => 'OpenRouter',
      'vsegpt' => 'VSEGPT',
      _ => 'Unknown provider',
    };
  }

  String? _selectedModelIdOrNull() {
    final String? selectedModelId = _settingsController.settings.selectedModelId
        ?.trim();
    if (selectedModelId == null || selectedModelId.isEmpty) {
      return null;
    }

    return selectedModelId;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsController,
      builder: (BuildContext context, _) {
        final ThemeMode themeMode = _resolveThemeMode(
          _settingsController.settings.themeMode,
        );

        return MaterialApp(
          title: 'AI Chat',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: Builder(
            builder: (context) {
              if (_settingsController.isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (!_settingsController.isBasicApiConfigured) {
                return InitialSetupScreen(controller: _settingsController);
              }

              return ChatScreen(
                controller: _chatController,
                modelCatalogController: _modelCatalogController,
                exportService: _exportService,
                shareService: _shareService,
                providerName: _providerStatusName(),
                selectedModelId: _selectedModelIdOrNull(),
                onOpenSettings: () => _openSettings(context),
                onOpenStatistics: () => _openStatistics(context),
              );
            },
          ),
        );
      },
    );
  }
}
