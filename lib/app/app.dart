import 'package:aichatcline/app/app_theme.dart';
import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/data/database/app_database.dart';
import 'package:aichatcline/data/repositories/chat_repository.dart';
import 'package:aichatcline/data/repositories/logs_repository.dart';
import 'package:aichatcline/data/repositories/stats_repository.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/chat/state/chat_controller.dart';
import 'package:aichatcline/features/chat/ui/chat_screen.dart';
import 'package:aichatcline/features/export/services/export_service.dart';
import 'package:aichatcline/features/export/services/share_service.dart';
import 'package:aichatcline/features/logs/ui/logs_screen.dart';
import 'package:aichatcline/features/providers/state/model_catalog_controller.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:aichatcline/features/settings/state/settings_controller.dart';
import 'package:aichatcline/features/settings/ui/initial_setup_screen.dart';
import 'package:aichatcline/features/settings/ui/pin_setup_screen.dart';
import 'package:aichatcline/features/settings/ui/pin_unlock_screen.dart';
import 'package:aichatcline/features/settings/ui/settings_screen.dart';
import 'package:aichatcline/features/statistics/state/statistics_controller.dart';
import 'package:aichatcline/features/statistics/ui/graph_screen.dart';
import 'package:aichatcline/features/statistics/ui/statistics_screen.dart';
import 'package:flutter/material.dart';

class AIChatApp extends StatefulWidget {
  const AIChatApp({super.key});

  @override
  State<AIChatApp> createState() => _AIChatAppState();
}

class _AIChatAppState extends State<AIChatApp> with WidgetsBindingObserver {
  late final AppDatabase _appDatabase;
  late final ChatRepository _chatRepository;
  late final LogsRepository _logsRepository;
  late final StatsRepository _statsRepository;
  late final OpenAICompatibleClient _aiClient;
  late final ChatController _chatController;
  late final SettingsController _settingsController;
  late final AppLogger _appLogger;
  late final ModelCatalogController _modelCatalogController;
  late final StatisticsController _statisticsController;
  late final ExportService _exportService;
  late final ShareService _shareService;
  DateTime? _backgroundedAt;

  static const Duration _inactivityLockDuration = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _appDatabase = AppDatabase();
    _chatRepository = ChatRepository(appDatabase: _appDatabase);
    _logsRepository = LogsRepository(appDatabase: _appDatabase);
    _statsRepository = StatsRepository(appDatabase: _appDatabase);
    _aiClient = OpenAICompatibleClient();
    _appLogger = AppLogger(logsRepository: _logsRepository);

    _settingsController = SettingsController(
      settingsStorage: const SettingsStorageService(),
      secureStorage: SecureStorageService(),
      aiClient: _aiClient,
      appLogger: _appLogger,
    );
    _appLogger.attachSettingsController(_settingsController);

    _modelCatalogController = ModelCatalogController(
      aiClient: _aiClient,
      settingsController: _settingsController,
    );

    _chatController = ChatController(
      chatRepository: _chatRepository,
      settingsController: _settingsController,
      modelCatalogController: _modelCatalogController,
      aiClient: _aiClient,
      statsRepository: _statsRepository,
      appLogger: _appLogger,
      onAssistantResponseCompleted: () async {
        await _statisticsController.loadAccountBalance();
      },
    );

    _statisticsController = StatisticsController(
      statsRepository: _statsRepository,
      settingsController: _settingsController,
      aiClient: _aiClient,
      appLogger: _appLogger,
    );

    _exportService = const ExportService();
    _shareService = const ShareService();

    _settingsController.load();
    _chatController.load();

    _settingsController.addListener(_handleSettingsChanged);
  }

  bool _wasSetupReady = false;

  Future<void> _handleSettingsChanged() async {
    final bool setupReady =
        _settingsController.isApiKeyValidated &&
        !_settingsController.isPinSetupRequired;

    if (setupReady && !_wasSetupReady) {
      _wasSetupReady = true;
      await _chatController.ensureCurrentConversationHasDefaultModel();
      return;
    }

    _wasSetupReady = setupReady;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _backgroundedAt = DateTime.now();
      return;
    }

    if (state == AppLifecycleState.resumed && _backgroundedAt != null) {
      final Duration elapsed = DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (elapsed >= _inactivityLockDuration) {
        _settingsController.lockApp();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settingsController.removeListener(_handleSettingsChanged);
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
        builder: (settingsContext) => SettingsScreen(
          controller: _settingsController,
          modelCatalogController: _modelCatalogController,
          onOpenLogs: () => _openLogs(settingsContext),
          onResetAppData: _resetAllAppData,
        ),
      ),
    );
  }

  void _openLogs(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LogsScreen(
          logsRepository: _logsRepository,
          shareService: _shareService,
        ),
      ),
    );
  }

  void _openStatistics(BuildContext context) {
    _statisticsController.refresh();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatisticsScreen(
          controller: _statisticsController,
          exportService: _exportService,
          shareService: _shareService,
        ),
      ),
    );
  }

  Future<void> _resetAllAppData() async {
    try {
      await _chatRepository.deleteAllConversations();
      await _statsRepository.deleteAllUsageRecords();
      await _logsRepository.deleteAllLogs();

      _chatController.resetLocalState();
      _statisticsController.resetLocalState();

      await _settingsController.resetAllAppData();
    } catch (e) {
      await _appLogger.logError(
        category: 'settings',
        message: 'Reset app data failed',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    }
  }

  void _openGraphs(BuildContext context) {
    _statisticsController.refresh();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GraphScreen(controller: _statisticsController),
      ),
    );
  }

  Future<void> _showBalanceFromChat(BuildContext context) async {
    await _statisticsController.loadAccountBalance();
    if (!context.mounted) {
      return;
    }

    final balance = _statisticsController.accountBalance;
    final String? balanceError = _statisticsController.balanceError;

    await showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Account balance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (balanceError != null)
                  Text(
                    balanceError,
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.error,
                    ),
                  )
                else if (balance == null)
                  const Text('No balance data available')
                else ...<Widget>[
                  Text('Provider: ${balance.providerId}'),
                  Text(
                    'Balance: ${balance.balance?.toStringAsFixed(6) ?? '-'} ${balance.currencyCode ?? ''}',
                  ),
                  Text(
                    'Status: ${(balance.subscriptionStatus?.trim().isNotEmpty ?? false) ? balance.subscriptionStatus : '-'}',
                  ),
                ],
              ],
            ),
          ),
        );
      },
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
    final String? selectedProviderId =
        _settingsController.settings.selectedProviderId;
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

              if (!_settingsController.isApiKeyValidated) {
                return InitialSetupScreen(controller: _settingsController);
              }

              if (_settingsController.isPinSetupRequired) {
                return PinSetupScreen(
                  onPinReady: (String pin) async {
                    await _settingsController.setupPin(pin);
                  },
                );
              }

              if (_settingsController.isLocked) {
                return PinUnlockScreen(
                  remainingAttempts: _settingsController.remainingPinAttempts,
                  onUnlock: (String pin) async {
                    final bool ok = await _settingsController.unlockWithPin(
                      pin,
                    );
                    if (ok) {
                      await _chatController
                          .ensureCurrentConversationHasDefaultModel();
                    }
                    return ok;
                  },
                  onResetApiKey: () {
                    return _settingsController.resetApiKeyAndPin();
                  },
                );
              }

              return AnimatedBuilder(
                animation: _statisticsController,
                builder: (BuildContext context, _) {
                  return ChatScreen(
                    controller: _chatController,
                    modelCatalogController: _modelCatalogController,
                    exportService: _exportService,
                    shareService: _shareService,
                    providerName: _providerStatusName(),
                    appLogger: _appLogger,
                    selectedModelId: _selectedModelIdOrNull(),
                    onOpenSettings: () => _openSettings(context),
                    onOpenStatistics: () => _openStatistics(context),
                    onOpenGraphs: () => _openGraphs(context),
                    onShowBalance: () => _showBalanceFromChat(context),
                    balance: _statisticsController.accountBalance,
                    isBalanceLoading: _statisticsController.isLoadingBalance,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
