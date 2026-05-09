import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String apiKeyKey = 'apiKey';

  final FlutterSecureStorage _storage;

  bool get _useSecureStorage => Platform.isIOS || Platform.isAndroid;

  bool get _useSharedPreferences =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;

  Future<void> saveApiKey(String apiKey) async {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteApiKey();
      return;
    }

    if (_useSecureStorage) {
      await _storage.delete(key: apiKeyKey);
      await _storage.write(key: apiKeyKey, value: trimmed);
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(apiKeyKey);
    await prefs.setString(apiKeyKey, trimmed);
  }

  Future<String?> readApiKey() async {
    if (_useSecureStorage) {
      return _storage.read(key: apiKeyKey);
    }

    if (_useSharedPreferences) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(apiKeyKey);
    }

    return _storage.read(key: apiKeyKey);
  }

  Future<void> deleteApiKey() async {
    if (_useSecureStorage) {
      await _storage.delete(key: apiKeyKey);
      return;
    }

    if (_useSharedPreferences) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(apiKeyKey);
      return;
    }

    await _storage.delete(key: apiKeyKey);
  }
}
