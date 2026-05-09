import 'package:aichatcline/data/services/secure_storage_service.dart';
import 'package:aichatcline/data/services/settings_storage_service.dart';
import 'package:aichatcline/features/providers/models/ai_provider.dart';
import 'package:aichatcline/features/providers/models/model_parameters.dart';
import 'package:aichatcline/features/providers/services/provider_detector.dart';
import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:flutter/foundation.dart';

class SettingsController extends ChangeNotifier {
  SettingsController({
    required SettingsStorageService settingsStorage,
    required SecureStorageService secureStorage,
  }) : _settingsStorage = settingsStorage,
       _secureStorage = secureStorage;

  final SettingsStorageService _settingsStorage;
  final SecureStorageService _secureStorage;

  AppSettings settings = AppSettings.defaults();
  String apiKey = '';
  AIProvider? detectedProvider;
  bool isLoading = false;
  String? error;

  Future<void> load() async {
    isLoading = true;
    error = null;
    notifyListeners();

    try {
      settings = await _settingsStorage.loadSettings();
      apiKey = (await _secureStorage.readApiKey()) ?? '';
      detectedProvider = ProviderDetector.tryDetectByApiKey(apiKey);

      if (detectedProvider != null) {
        final String detectedId = detectedProvider!.id;
        if (settings.selectedProviderId != detectedId) {
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
      await _secureStorage.saveApiKey(value);
      apiKey = value.trim();
      detectedProvider = ProviderDetector.tryDetectByApiKey(apiKey);

      if (detectedProvider != null) {
        settings = settings.copyWith(selectedProviderId: detectedProvider!.id);
        await _settingsStorage.saveSettings(settings);
      }
    } catch (e) {
      error = 'Failed to save API key';
    }

    notifyListeners();
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

  Future<void> resetSettings() async {
    error = null;
    try {
      await _settingsStorage.resetSettings();
      settings = AppSettings.defaults();
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
