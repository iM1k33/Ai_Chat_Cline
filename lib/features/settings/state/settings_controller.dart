import 'package:aichatcline/core/utils/app_logger.dart';
import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/core/errors/app_exception.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/model_parameters.dart';
import 'package:aichatcline/features/providers/services/openai_compatible_client.dart';
import 'package:aichatcline/features/providers/services/provider_detector.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:flutter/foundation.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsStorageService settingsStorage,
    required SecureStorageService secureStorage,
    required OpenAICompatibleClient aiClient,
    AppLogger? appLogger,
  }) : _settingsStorage = settingsStorage,
       _secureStorage = secureStorage,
       _aiClient = aiClient,
       _appLogger = appLogger;

  final SettingsStorageService _settingsStorage;
  final SecureStorageService _secureStorage;
  final OpenAICompatibleClient _aiClient;
  final AppLogger? _appLogger;

  AppSettings settings = AppSettings.defaults();
  String apiKey = '';
  AIProvider? detectedProvider;
  bool isLoading = false;
  bool isValidatingApiKey = false;
  bool isUnlocked = false;
  bool isPinSetupRequired = false;
  int remainingPinAttempts = 9;
  String? error;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get hasRecognizedProvider => detectedProvider != null;
  bool get isApiKeyValidated => settings.isApiKeyValidated;
  bool get isLocked => !isUnlocked;
  bool get isBasicApiConfigured =>
      hasApiKey && hasRecognizedProvider && isApiKeyValidated;

  static const int _maxPinAttempts = 9;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      settings = await _settingsStorage.loadSettings();
      apiKey = (await _secureStorage.readApiKey()) ?? '';
      detectedProvider = ProviderDetector.tryDetectByApiKey(apiKey);

      if (detectedProvider == null && settings.isApiKeyValidated) {
        settings = settings.copyWith(isApiKeyValidated: false);
        await _settingsStorage.saveSettings(settings);
      }

      if (detectedProvider != null) {
        final String detectedId = detectedProvider!.id;
        if (settings.selectedProviderId != detectedId ||
            settings.selectedProviderId == null) {
          settings = settings.copyWith(selectedProviderId: detectedId);
          await _settingsStorage.saveSettings(settings);
        }

        if ((settings.baseUrl?.trim().isEmpty ?? true)) {
          settings = settings.copyWith(baseUrl: detectedProvider!.baseUrl);
          await _settingsStorage.saveSettings(settings);
        }
      }

      if (!settings.isApiKeyValidated) {
        isUnlocked = false;
        isPinSetupRequired = false;
        remainingPinAttempts = _maxPinAttempts;
      } else {
        final String? pin = await _secureStorage.readPin();
        final bool hasPin = (pin?.trim().isNotEmpty ?? false);
        isPinSetupRequired = !hasPin;
        isUnlocked = !hasPin;
        remainingPinAttempts = _maxPinAttempts;
      }
    } catch (e) {
      error = 'Failed to load settings';
      await _appLogger?.logError(
        category: 'settings',
        message: 'Failed to load settings',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateBaseUrl(String value) async {
    final String trimmed = value.trim();
    final String? next = trimmed.isEmpty ? null : trimmed;
    await _saveSettings(
      settings.copyWith(baseUrl: next),
      errorMessage: 'Failed to save base URL',
    );
  }

  Future<void> saveApiKey(String value) async {
    error = null;
    try {
      final String trimmed = value.trim();
      await _secureStorage.saveApiKey(trimmed);
      apiKey = trimmed;
      detectedProvider = ProviderDetector.tryDetectByApiKey(trimmed);

      settings = settings.copyWith(
        selectedProviderId: detectedProvider?.id,
        baseUrl: detectedProvider?.baseUrl,
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);

      if (trimmed.isEmpty) {
        await _secureStorage.deleteApiKey();
        await _secureStorage.deletePin();
        isUnlocked = false;
        isPinSetupRequired = false;
        remainingPinAttempts = _maxPinAttempts;
      }
    } catch (e) {
      final String message = e.toString().trim();
      final String safeMessage = message.isEmpty ? 'Unknown error' : message;
      error = 'Failed to save API key [${e.runtimeType}]: $safeMessage';
      await _appLogger?.logWarning(
        category: 'settings',
        message: 'Failed to save API key',
        metadata: <String, dynamic>{'error': safeMessage},
      );
    }

    notifyListeners();
  }

  Future<void> clearApiKey({bool keepPin = true}) async {
    error = null;
    try {
      await _secureStorage.deleteApiKey();
      if (!keepPin) {
        await _secureStorage.deletePin();
      }

      apiKey = '';
      detectedProvider = null;
      isValidatingApiKey = false;

      settings = settings.copyWith(
        selectedProviderId: null,
        selectedModelId: null,
        baseUrl: null,
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);

      if (!keepPin) {
        isUnlocked = false;
        isPinSetupRequired = false;
        remainingPinAttempts = _maxPinAttempts;
      }
    } catch (e) {
      error = 'Failed to clear API key';
      await _appLogger?.logWarning(
        category: 'settings',
        message: 'Failed to clear API key',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    }

    notifyListeners();
  }

  Future<void> saveAndValidateInitialApiKey(String apiKeyInput) async {
    final AIProvider? detected = ProviderDetector.tryDetectByApiKey(
      apiKeyInput,
    );
    final String fallbackBaseUrl = detected?.baseUrl ?? '';
    await saveAndValidateInitialApiSetup(
      apiKey: apiKeyInput,
      baseUrl: fallbackBaseUrl,
    );
  }

  Future<void> saveAndValidateInitialApiSetup({
    required String apiKey,
    required String baseUrl,
  }) async {
    final String trimmed = apiKey.trim();
    final String trimmedBaseUrl = baseUrl.trim();
    error = null;
    isValidatingApiKey = true;
    notifyListeners();

    try {
      await _appLogger?.logInfo(
        category: 'validation',
        message: 'API key validation started',
      );

      if (trimmed.isEmpty) {
        throw Exception('API key is required');
      }

      final AIProvider? provider = ProviderDetector.tryDetectByApiKey(trimmed);
      if (provider == null) {
        await _secureStorage.deleteApiKey();
        this.apiKey = '';
        detectedProvider = null;
        settings = settings.copyWith(
          selectedProviderId: null,
          baseUrl: null,
          isApiKeyValidated: false,
        );
        await _settingsStorage.saveSettings(settings);
        throw Exception(
          'Provider could not be detected. Use a supported API key prefix.',
        );
      }

      final AIProvider providerForValidation = _providerWithBaseUrl(
        provider,
        trimmedBaseUrl,
      );

      await _aiClient.validateApiKey(
        provider: providerForValidation,
        apiKey: trimmed,
      );

      await _secureStorage.saveApiKey(trimmed);
      detectedProvider = provider;
      this.apiKey = trimmed;
      settings = settings.copyWith(
        selectedProviderId: provider.id,
        baseUrl: trimmedBaseUrl.isEmpty ? provider.baseUrl : trimmedBaseUrl,
        selectedModelId: _defaultModelForProvider(provider.id),
        isApiKeyValidated: true,
      );
      await _settingsStorage.saveSettings(settings);
      isPinSetupRequired = true;
      isUnlocked = false;
      remainingPinAttempts = _maxPinAttempts;
      error = null;

      await _appLogger?.logInfo(
        category: 'validation',
        message: 'API key validation succeeded',
        metadata: <String, dynamic>{'providerId': provider.id},
      );
    } catch (e) {
      await _secureStorage.deleteApiKey();
      this.apiKey = '';
      detectedProvider = null;
      settings = settings.copyWith(
        selectedProviderId: null,
        baseUrl: null,
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);
      isPinSetupRequired = false;
      isUnlocked = false;
      remainingPinAttempts = _maxPinAttempts;

      if (e is AppException) {
        error = e.message;
      } else {
        final String message = e
            .toString()
            .replaceFirst('Exception: ', '')
            .trim();
        error = message.isEmpty ? 'Failed to validate API key' : message;
      }

      await _appLogger?.logWarning(
        category: 'validation',
        message: 'API key validation failed',
        metadata: <String, dynamic>{
          'errorType': e.runtimeType.toString(),
          'error': error ?? 'Unknown validation failure',
        },
      );
    } finally {
      isValidatingApiKey = false;
      notifyListeners();
    }
  }

  Future<void> validateCurrentApiKey() async {
    final String effectiveBaseUrl = settings.baseUrl?.trim().isNotEmpty == true
        ? settings.baseUrl!.trim()
        : (detectedProvider?.baseUrl ?? '');

    await saveAndValidateInitialApiSetup(
      apiKey: apiKey,
      baseUrl: effectiveBaseUrl,
    );
  }

  Future<void> setupPin(String pin) async {
    await _secureStorage.savePin(pin);
    isPinSetupRequired = false;
    isUnlocked = true;
    remainingPinAttempts = _maxPinAttempts;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    if (remainingPinAttempts <= 0) {
      return false;
    }

    final String? storedPin = await _secureStorage.readPin();
    final bool isCorrect = storedPin != null && storedPin == pin.trim();

    if (isCorrect) {
      isUnlocked = true;
      remainingPinAttempts = _maxPinAttempts;
      notifyListeners();
      return true;
    }

    remainingPinAttempts = remainingPinAttempts > 0
        ? remainingPinAttempts - 1
        : 0;
    isUnlocked = false;
    notifyListeners();
    return false;
  }

  Future<bool> verifyPin(String pin) async {
    final String normalized = pin.trim();
    if (normalized.length != 4) {
      return false;
    }
    final String? storedPin = await _secureStorage.readPin();
    return storedPin != null && storedPin == normalized;
  }

  Future<void> resetApiKeyAndPin() async {
    error = null;
    try {
      await _secureStorage.deleteApiKey();
      await _secureStorage.deletePin();

      apiKey = '';
      detectedProvider = null;
      isValidatingApiKey = false;
      isUnlocked = false;
      isPinSetupRequired = false;
      remainingPinAttempts = _maxPinAttempts;

      settings = settings.copyWith(
        selectedProviderId: null,
        selectedModelId: null,
        baseUrl: null,
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);
    } catch (e) {
      error = 'Failed to reset API key';
      await _appLogger?.logWarning(
        category: 'settings',
        message: 'Failed to reset API key and PIN',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    }

    notifyListeners();
  }

  void lockApp() {
    if (settings.isApiKeyValidated) {
      isUnlocked = false;
      notifyListeners();
    }
  }

  Future<void> updateSystemPrompt(String value) {
    return _saveSettings(
      settings.copyWith(systemPrompt: value),
      errorMessage: 'Failed to update system prompt',
    );
  }

  Future<void> updateIncludeMessageContentInLogs(bool value) {
    return _saveSettings(
      settings.copyWith(includeMessageContentInLogs: value),
      errorMessage: 'Failed to update log settings',
    );
  }

  Future<void> updateThemeMode(ThemeModeOption value) {
    return _saveSettings(
      settings.copyWith(themeMode: value),
      errorMessage: 'Failed to update theme mode',
    );
  }

  Future<void> updateLocale(LocaleOption value) {
    return _saveSettings(
      settings.copyWith(locale: value),
      errorMessage: 'Failed to update locale',
    );
  }

  Future<void> updateModelParameters(ModelParameters value) {
    return _saveSettings(
      settings.copyWith(modelParameters: value),
      errorMessage: 'Failed to update model parameters',
    );
  }

  Future<void> updateSelectedModelId(String? value) {
    final String? normalized = value?.trim();
    final String? selectedModelId = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;

    return _saveSettings(
      settings.copyWith(selectedModelId: selectedModelId),
      errorMessage: 'Failed to update selected model',
    );
  }

  Future<void> resetSettings() async {
    error = null;
    try {
      await _settingsStorage.resetSettings();
      settings = AppSettings.defaults();
      await _secureStorage.deleteApiKey();
      await _secureStorage.deletePin();
      apiKey = '';
      detectedProvider = null;
      isValidatingApiKey = false;
      isUnlocked = false;
      isPinSetupRequired = false;
      remainingPinAttempts = _maxPinAttempts;
    } catch (e) {
      error = 'Failed to reset settings';
      await _appLogger?.logWarning(
        category: 'settings',
        message: 'Failed to reset settings',
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    }

    notifyListeners();
  }

  AIProvider? effectiveProvider() {
    if (detectedProvider != null) {
      return _providerWithBaseUrl(detectedProvider!, settings.baseUrl ?? '');
    }

    final String? selectedId = settings.selectedProviderId?.trim();
    final AIProvider? base = switch (selectedId) {
      'openrouter' => AIProvider.openRouter,
      'vsegpt' => AIProvider.vsegpt,
      _ => null,
    };
    if (base == null) {
      return null;
    }

    return _providerWithBaseUrl(base, settings.baseUrl ?? '');
  }

  AIProvider _providerWithBaseUrl(AIProvider provider, String baseUrl) {
    final String trimmedBaseUrl = baseUrl.trim();
    if (trimmedBaseUrl.isEmpty) {
      return provider;
    }

    return AIProvider(
      id: provider.id,
      name: provider.name,
      type: provider.type,
      baseUrl: trimmedBaseUrl,
      apiKeyPrefix: provider.apiKeyPrefix,
      currencyCode: provider.currencyCode,
    );
  }

  String? _defaultModelForProvider(String providerId) {
    return switch (providerId) {
      'openrouter' => 'openrouter/free',
      'vsegpt' => 'openai/gpt-3.5-turbo',
      _ => null,
    };
  }

  Future<void> _saveSettings(
    AppSettings nextSettings, {
    required String errorMessage,
  }) async {
    error = null;
    try {
      settings = nextSettings;
      await _settingsStorage.saveSettings(settings);
    } catch (e) {
      error = errorMessage;
      await _appLogger?.logWarning(
        category: 'settings',
        message: errorMessage,
        metadata: <String, dynamic>{'errorType': e.runtimeType.toString()},
      );
    }

    notifyListeners();
  }
}
