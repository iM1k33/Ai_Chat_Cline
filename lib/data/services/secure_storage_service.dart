import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const String apiKeyKey = 'apiKey';

  final FlutterSecureStorage _storage;

  Future<void> saveApiKey(String apiKey) async {
    final String trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      await deleteApiKey();
      return;
    }

    await _storage.write(key: apiKeyKey, value: trimmed);
  }

  Future<String?> readApiKey() {
    return _storage.read(key: apiKeyKey);
  }

  Future<void> deleteApiKey() {
    return _storage.delete(key: apiKeyKey);
  }
}
