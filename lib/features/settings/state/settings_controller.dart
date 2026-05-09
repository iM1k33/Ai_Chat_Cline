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
  }) : _settingsStorage = settingsStorage,
       _secureStorage = secureStorage,
       _aiClient = aiClient;

  final SettingsStorageService _settingsStorage;
  final SecureStorageService _secureStorage;
  final OpenAICompatibleClient _aiClient;

  AppSettings settings = AppSettings.defaults();
  String apiKey = '';
  AIProvider? detectedProvider;
  bool isLoading = false;
  bool isValidatingApiKey = false;
  String? error;

  bool get hasApiKey => apiKey.trim().isNotEmpty;
  bool get hasRecognizedProvider => detectedProvider != null;
  bool get isApiKeyValidated => settings.isApiKeyValidated;
  bool get isBasicApiConfigured =>
      hasApiKey && hasRecognizedProvider && isApiKeyValidated;

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
      }
    } catch (e) {
      error = 'Failed to load settings';
    } finally {
      isLoading = false;
      notifyListeners();
    }
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
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);

      if (trimmed.isEmpty) {
        await _secureStorage.deleteApiKey();
      }
    } catch (e) {
      final String message = e.toString().trim();
      final String safeMessage = message.isEmpty ? 'Unknown error' : message;
      error = 'Failed to save API key [${e.runtimeType}]: $safeMessage';
    }

    notifyListeners();
  }

  Future<void> saveAndValidateInitialApiKey(String apiKeyInput) async {
    final String trimmed = apiKeyInput.trim();
    error = null;
    isValidatingApiKey = true;
    notifyListeners();

    try {
      if (trimmed.isEmpty) {
        throw Exception('API key is required');
      }

      final AIProvider? provider = ProviderDetector.tryDetectByApiKey(trimmed);
      if (provider == null) {
        await _secureStorage.deleteApiKey();
        apiKey = '';
        detectedProvider = null;
        settings = settings.copyWith(
          selectedProviderId: null,
          isApiKeyValidated: false,
        );
        await _settingsStorage.saveSettings(settings);
        throw Exception(
          'Provider could not be detected. Use a supported API key prefix.',
        );
      }

      await _aiClient.validateApiKey(provider: provider, apiKey: trimmed);

      await _secureStorage.saveApiKey(trimmed);
      detectedProvider = provider;
      apiKey = trimmed;
      settings = settings.copyWith(
        selectedProviderId: provider.id,
        isApiKeyValidated: true,
      );
      await _settingsStorage.saveSettings(settings);
      error = null;
    } catch (e) {
      await _secureStorage.deleteApiKey();
      apiKey = '';
      detectedProvider = null;
      settings = settings.copyWith(
        selectedProviderId: null,
        isApiKeyValidated: false,
      );
      await _settingsStorage.saveSettings(settings);

      if (e is AppException) {
        error = e.message;
      } else {
        final String message = e.toString().replaceFirst('Exception: ', '').trim();
        error = message.isEmpty
            ? 'Failed to validate API key'
            : message;
      }
    } finally {
      isValidatingApiKey = false;
      notifyListeners();
    }
  }

  Future<void> validateCurrentApiKey() async {
    await saveAndValidateInitialApiKey(apiKey);
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
      apiKey = '';
      detectedProvider = null;
      isValidatingApiKey = false;
    } catch (e) {
      error = 'Failed to reset settings';
    }

    notifyListeners();
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
    }

    notifyListeners();
  }
}
