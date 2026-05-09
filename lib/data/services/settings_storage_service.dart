import 'dart:convert';

import 'package:aichatcline/features/settings/state/app_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStorageService {
  const SettingsStorageService();

  static const String appSettingsKey = 'appSettings';

  Future<AppSettings> loadSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(appSettingsKey);
    if (raw == null || raw.isEmpty) {
      return AppSettings.defaults();
    }

    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return AppSettings.defaults();
      }

      return AppSettings.fromJson(decoded);
    } catch (_) {
      return AppSettings.defaults();
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(settings.toJson());
    await prefs.setString(appSettingsKey, encoded);
  }

  Future<void> resetSettings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(appSettingsKey);
  }
}
