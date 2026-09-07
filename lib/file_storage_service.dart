import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 基于文件系统的持久化存储
/// 写入 App 文档目录下的 JSON 文件，每次写后立即 flush
/// 启动时从文件读取，完全不依赖 SharedPreferences
class FileStorageService {
  static const _fileName = 'eureka_data.json';
  static const _oldFileName = 'ai_tutor_data.json'; // 兼容旧版

  /// 获取存储文件路径
  static Future<String> _getFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_fileName';
  }

  /// 获取旧版文件路径(兼容迁移)
  static Future<String> _getOldFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_oldFileName';
  }

  /// 从文件加载存储数据
  /// 文件不存在或损坏时返回空 map
  static Future<Map<String, dynamic>> load() async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      if (!await file.exists()) {
        // 兼容旧版: 尝试从旧文件名加载
        final oldPath = await _getOldFilePath();
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          debugPrint('[FileStorage] 从旧文件名迁移: $oldPath');
          final content = await oldFile.readAsString();
          final data = jsonDecode(content);
          if (data is Map) {
            // 迁移到新文件后删除旧文件
            await save(data.cast<String, dynamic>());
            await oldFile.delete();
            return data.cast<String, dynamic>();
          }
        }
        debugPrint('[FileStorage] 存储文件不存在，返回空数据');
        return {};
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        debugPrint('[FileStorage] 存储文件为空');
        return {};
      }
      final data = jsonDecode(content);
      if (data is! Map) {
        debugPrint('[FileStorage] 数据格式错误，不是 Map');
        return {};
      }
      debugPrint('[FileStorage] 成功加载 ${content.length} 字节');
      return data.cast<String, dynamic>();
    } catch (e) {
      debugPrint('[FileStorage] 加载失败: $e');
      return {};
    }
  }

  /// 写入完整数据到文件
  static Future<bool> save(Map<String, dynamic> data) async {
    try {
      final path = await _getFilePath();
      final file = File(path);
      final content = const JsonEncoder.withIndent(null).convert(data);
      await file.writeAsString(content);
      debugPrint('[FileStorage] 成功写入 ${content.length} 字节到 $path');
      return true;
    } catch (e) {
      debugPrint('[FileStorage] 写入失败: $e');
      return false;
    }
  }

  /// 安全读取 engine_data（兼容两种存储方式）
  /// 优先从文件读，文件不存在时从 SharedPreferences 迁移
  static Future<Map<String, dynamic>?> loadEngineData() async {
    final fileData = await load();
    if (fileData.isNotEmpty && fileData['engine_data'] != null) {
      final raw = fileData['engine_data'];
      if (raw is String) {
        return jsonDecode(raw);
      }
      return raw;
    }
    return null;
  }
}
