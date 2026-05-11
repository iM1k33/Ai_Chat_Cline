import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String apiKeyKey = 'apiKey';
  static const String pinKey = 'pinCode';

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

    await _saveString(trimmed);
  }

  Future<void> savePin(String pin) async {
    final String trimmed = pin.trim();
    final RegExp pinPattern = RegExp(r'^\d{4}$');
    if (!pinPattern.hasMatch(trimmed)) {
      throw ArgumentError('PIN must be exactly 4 digits');
    }

    await _saveString(trimmed, key: pinKey);
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

  Future<String?> readPin() async {
    if (_useSecureStorage) {
      return _storage.read(key: pinKey);
    }

    if (_useSharedPreferences) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(pinKey);
    }

    return _storage.read(key: pinKey);
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

  Future<void> deletePin() async {
    if (_useSecureStorage) {
      await _storage.delete(key: pinKey);
      return;
    }

    if (_useSharedPreferences) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(pinKey);
      return;
    }

    await _storage.delete(key: pinKey);
  }

  Future<void> _saveString(String value, {String key = apiKeyKey}) async {
    if (_useSecureStorage) {
      await _storage.delete(key: key);
      await _storage.write(key: key, value: value);
      return;
    }

    if (_useSharedPreferences) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
      await prefs.setString(key, value);
      return;
    }

    await _storage.delete(key: key);
    await _storage.write(key: key, value: value);
  }
}
