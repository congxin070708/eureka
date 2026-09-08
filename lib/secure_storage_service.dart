// ignore_for_file: avoid_print
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 安全存储服务 - 使用平台级加密存储敏感数据
/// Android: Keystore | iOS: Keychain
///
/// 所有写/删操作返回 bool 以便调用方感知失败；
/// 读操作失败时返回空字符串默认值并记录日志。
class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyApiKey = 'api_key';
  static const _keyBaseUrl = 'base_url';

  /// 读取 API Key
  ///
  /// 失败时返回空字符串（默认值），并记录错误日志，
  /// 调用方可通过 [saveApiKey] 的返回值感知存储是否可用。
  static Future<String> getApiKey() async {
    try {
      return await _storage.read(key: _keyApiKey) ?? '';
    } catch (e) {
      debugPrint('[SecureStorage] 读取 API Key 失败: $e');
      return '';
    }
  }

  /// 保存 API Key
  ///
  /// 返回 true 表示保存成功，false 表示保存失败（如平台存储不可用）。
  static Future<bool> saveApiKey(String key) async {
    try {
      await _storage.write(key: _keyApiKey, value: key);
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] 保存 API Key 失败: $e');
      return false;
    }
  }

  /// 读取自定义 Base URL
  ///
  /// 失败时返回空字符串（默认值），并记录错误日志。
  static Future<String> getBaseUrl() async {
    try {
      return await _storage.read(key: _keyBaseUrl) ?? '';
    } catch (e) {
      debugPrint('[SecureStorage] 读取 Base URL 失败: $e');
      return '';
    }
  }

  /// 保存自定义 Base URL
  ///
  /// 返回 true 表示保存成功，false 表示保存失败。
  static Future<bool> saveBaseUrl(String url) async {
    try {
      await _storage.write(key: _keyBaseUrl, value: url);
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] 保存 Base URL 失败: $e');
      return false;
    }
  }

  /// 删除 API Key
  ///
  /// 返回 true 表示删除成功，false 表示删除失败。
  static Future<bool> deleteApiKey() async {
    try {
      await _storage.delete(key: _keyApiKey);
      return true;
    } catch (e) {
      debugPrint('[SecureStorage] 删除 API Key 失败: $e');
      return false;
    }
  }
}
