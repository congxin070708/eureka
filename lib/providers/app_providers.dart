import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../study_engine.dart';
import '../file_storage_service.dart';
import '../app_theme.dart';

/// ── StudyEngine 状态管理 ──
/// 使用 ChangeNotifierProvider 管理可变状态
/// StudyEngine 内部数据变化后调用 notifyListeners() 触发 UI 重建
/// 比 StateNotifier 更适合 StudyEngine 这种重量级可变对象
class StudyEngineNotifier extends StudyEngine with ChangeNotifier {
  /// 从文件系统加载引擎数据(启动时调用)
  Future<void> loadFromStorage() async {
    try {
      final fileData = await FileStorageService.loadEngineData();
      if (fileData != null) {
        final loaded = StudyEngine.fromJson(fileData);
        replaceEngine(loaded);
      }
    } catch (_) {
      // 加载失败时保持现有引擎数据不变，不影响应用启动
    }
  }

  /// 用外部引擎替换全部数据
  void replaceEngine(StudyEngine other) {
    level = other.level;
    xp = other.xp;
    xpNext = other.xpNext;
    totalXp = other.totalXp;
    totalQ = other.totalQ;
    totalCorrect = other.totalCorrect;
    streak = other.streak;
    bestStreak = other.bestStreak;
    totalStudyMinutes = other.totalStudyMinutes;
    studyMode = other.studyMode;
    currentSubject = other.currentSubject;
    subjects = other.subjects;
    history = other.history;
    dailyRecords = other.dailyRecords;
    chatHistory = other.chatHistory;
    bookmarks = other.bookmarks;
    // 技能树 / 任务 / 背包 / 积分 / 抽奖保底
    skillTrees = other.skillTrees;
    taskManager = other.taskManager;
    inventory = other.inventory;
    systemCredits = other.systemCredits;
    equippedTitle = other.equippedTitle;
    gachaPityEpic = other.gachaPityEpic;
    gachaPityLegend = other.gachaPityLegend;
    notifyListeners();
  }

  // ── 以下方法覆盖父类,操作后通知监听者 ──

  @override
  RecordResult record(String subject, int score) {
    final result = super.record(subject, score);
    notifyListeners();
    return result;
  }

  @override
  void checkIn() {
    super.checkIn();
    notifyListeners();
  }

  @override
  void addStudyMinutes(int minutes) {
    super.addStudyMinutes(minutes);
    notifyListeners();
  }

  @override
  void addBookmark(String subject, String title, String content) {
    super.addBookmark(subject, title, content);
    notifyListeners();
  }

  @override
  void removeBookmark(int index) {
    super.removeBookmark(index);
    notifyListeners();
  }

  /// 切换学习模式
  void setStudyMode(String mode) {
    studyMode = mode;
    notifyListeners();
  }

  /// 设置当前科目
  void setCurrentSubject(String subject) {
    currentSubject = subject;
    notifyListeners();
  }

  /// 删除科目
  void removeSubject(String name) {
    subjects.remove(name);
    if (currentSubject == name) {
      currentSubject = '';
    }
    notifyListeners();
  }

  /// 更新聊天记录后通知
  void notifyChatUpdated() {
    notifyListeners();
  }

  /// 持久化到文件系统
  Future<void> save() async {
    await FileStorageService.save({'engine_data': toJson()});
  }
}

/// 引擎 Provider(全局唯一实例,ChangeNotifier 模式)
final studyEngineProvider =
    ChangeNotifierProvider<StudyEngineNotifier>((ref) {
  return StudyEngineNotifier();
});

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
