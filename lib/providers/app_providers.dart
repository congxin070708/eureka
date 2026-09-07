import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../study_engine.dart';
import '../file_storage_service.dart';
import '../app_theme.dart';

/// ── StudyEngine 状态管理 ──
/// 使用 StateNotifier 统一管理引擎状态,所有页面通过 ref.watch 共享同一实例
/// 修改引擎数据后调用 state = state 即可触发 UI 重建
class StudyEngineNotifier extends StateNotifier<StudyEngine> {
  StudyEngineNotifier() : super(StudyEngine());

  /// 从文件系统加载引擎数据(启动时调用)
  Future<void> loadFromStorage() async {
    try {
      final fileData = await FileStorageService.loadEngineData();
      if (fileData != null) {
        state = StudyEngine.fromJson(fileData);
      }
    } catch (_) {}
  }

  /// 用外部加载好的引擎替换当前状态
  void setEngine(StudyEngine engine) {
    state = engine;
  }

  /// 持久化到文件系统
  Future<void> save() async {
    await FileStorageService.save({'engine_data': state.toJson()});
  }

  /// 答题记录
  RecordResult record(String subject, int score) {
    final result = state.record(subject, score);
    state = state; // 触发重建
    return result;
  }

  /// 签到
  void checkIn() {
    state.checkIn();
    state = state;
  }

  /// 切换学习模式
  void setStudyMode(String mode) {
    state.studyMode = mode;
    state = state;
  }

  /// 设置当前科目
  void setCurrentSubject(String subject) {
    state.currentSubject = subject;
    state = state;
  }

  /// 添加/获取科目
  SubjectData getSubject(String name) {
    return state.getSubject(name);
  }

  /// 添加收藏
  void addBookmark(String subject, String title, String content) {
    state.addBookmark(subject, title, content);
    state = state;
  }

  /// 删除收藏
  void removeBookmark(int index) {
    state.removeBookmark(index);
    state = state;
  }

  /// 添加学习时长
  void addStudyMinutes(int minutes) {
    state.addStudyMinutes(minutes);
    state = state;
  }

  /// 删除科目
  void removeSubject(String name) {
    state.subjects.remove(name);
    if (state.currentSubject == name) {
      state.currentSubject = '';
    }
    state = state;
  }

  /// 从导入数据替换整个引擎
  void replaceEngine(StudyEngine newEngine) {
    state = newEngine;
  }

  /// 更新聊天记录
  void updateChatHistory(String subject, List<Map<String, dynamic>> messages) {
    state.chatHistory[subject] = messages;
    state = state;
  }
}

/// 引擎 Provider(全局唯一实例)
final studyEngineProvider =
    StateNotifierProvider<StudyEngineNotifier, StudyEngine>(
  (ref) => StudyEngineNotifier(),
);

/// ── 主题状态 ──
class ThemeNotifier extends StateNotifier<bool> {
  ThemeNotifier() : super(AppTheme.isDark);
  void toggle() {
    state = !state;
    AppTheme.isDark = state;
  }

  void setDark(bool isDark) {
    state = isDark;
    AppTheme.isDark = isDark;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, bool>(
  (ref) => ThemeNotifier(),
);
