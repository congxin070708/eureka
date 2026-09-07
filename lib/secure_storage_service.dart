import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务 - 使用平台级加密存储敏感数据
/// Android: Keystore | iOS: Keychain
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _keyApiKey = 'api_key';
  static const _keyBaseUrl = 'base_url';

  /// 读取 API Key
  static Future<String> getApiKey() async {
    try {
      return await _storage.read(key: _keyApiKey) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 保存 API Key
  static Future<void> saveApiKey(String key) async {
    try {
      await _storage.write(key: _keyApiKey, value: key);
    } catch (_) {}
  }

  /// 读取自定义 Base URL
  static Future<String> getBaseUrl() async {
    try {
      return await _storage.read(key: _keyBaseUrl) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 保存自定义 Base URL
  static Future<void> saveBaseUrl(String url) async {
    try {
      await _storage.write(key: _keyBaseUrl, value: url);
    } catch (_) {}
  }

  /// 删除 API Key
  static Future<void> deleteApiKey() async {
    try {
      await _storage.delete(key: _keyApiKey);
    } catch (_) {}
  }
}
