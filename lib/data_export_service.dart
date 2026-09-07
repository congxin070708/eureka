import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'study_engine.dart';

/// 数据导出/导入服务
/// 支持将学习数据导出为 JSON 文件,以及从文件导入恢复
class DataExportService {
  /// 导出学习数据为 JSON 文件并分享
  /// 返回导出文件路径,失败返回 null
  static Future<String?> exportData(StudyEngine engine) async {
    try {
      final dir = await getTemporaryDirectory();
      final timestamp = DateTime.now().toIso8601String().substring(0, 10);
      final path = '${dir.path}/eureka_backup_$timestamp.json';

      final data = {
        'app': 'eureka',
        'version': 2,
        'exportDate': DateTime.now().toIso8601String(),
        'engine': engine.toJson(),
      };

      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      // 调用系统分享面板
      await Share.shareXFiles(
        [XFile(path)],
        text: 'Eureka 学习数据备份 $timestamp',
      );

      return path;
    } catch (e) {
      return null;
    }
  }

  /// 从用户选择的文件导入学习数据
  /// 返回导入的 StudyEngine, 失败返回 null
  static Future<StudyEngine?> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) return null;

      final path = result.files.first.path;
      if (path == null) return null;

      final file = File(path);
      final content = await file.readAsString();
      final data = jsonDecode(content);

      if (data is! Map || data['engine'] == null) return null;

      final engine = StudyEngine.fromJson(data['engine'] as Map<String, dynamic>);
      return engine;
    } catch (e) {
      return null;
    }
  }

  /// 仅导出到文件(不调分享面板),用于自动备份
  static Future<String?> exportToFile(StudyEngine engine) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().toIso8601String().substring(0, 10);
      final path = '${dir.path}/eureka_backup_$timestamp.json';

      final data = {
        'app': 'eureka',
        'version': 2,
        'exportDate': DateTime.now().toIso8601String(),
        'engine': engine.toJson(),
      };

      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      return path;
    } catch (e) {
      return null;
    }
  }
}
