import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../study_engine.dart';
import '../api_service.dart';
import '../app_theme.dart';
import '../file_storage_service.dart';
import 'learn_screen.dart';
import 'stats_screen.dart';
import '../version.dart';

class HomeScreen extends StatefulWidget {
  final StudyEngine engine;
  const HomeScreen({super.key, required this.engine});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _controller = TextEditingController();
  List<String> _subjects = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 从文件重新加载（确保数据最新）
    _reloadEngine();
    if (widget.engine.currentSubject.isEmpty &&
        widget.engine.subjects.keys.isNotEmpty) {
      widget.engine.currentSubject = widget.engine.subjects.keys.first;
    }
    _subjects = widget.engine.subjects.keys.toList();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _reloadEngine() {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    FileStorageService.loadEngineData().then((fileData) {
      if (fileData == null) return;
      try {
        final loaded = StudyEngine.fromJson(fileData);
        if (loaded.subjects.isNotEmpty && widget.engine.subjects.isEmpty) {
          widget.engine.subjects = loaded.subjects;
        }
        if (loaded.chatHistory.isNotEmpty && widget.engine.chatHistory.isEmpty) {
          widget.engine.chatHistory = loaded.chatHistory;
        }
        if (loaded.dailyRecords.isNotEmpty && widget.engine.dailyRecords.isEmpty) {
          widget.engine.dailyRecords = loaded.dailyRecords;
        }
        setState(() {
          _subjects = widget.engine.subjects.keys.toList();
        });
      } catch (_) {}
    });
  }

  Future<void> _saveEngineSync() async {
    setState(() => _saving = true);
    await FileStorageService.save({'engine_data': widget.engine.toJson()});
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ 已保存'),
        backgroundColor: AppTheme.taskDone,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _saveEngine() {
    _saveEngineSync();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final checkedIn = e.isCheckedInToday;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:       EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentLight],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Lv.${e.level}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
                    SizedBox(width: 6),
              Text(
                '${e.xp}/${e.xpNext}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        title: const SizedBox.shrink(),
        actions: [
          // ── 学习模式切换 ──
          GestureDetector(
            onTap: () {
              final modes = ['速学', '深度', '挑战'];
              final current = modes.indexOf(e.studyMode);
              final next = (current + 1) % modes.length;
              setState(() => e.studyMode = modes[next]);
              _saveEngineSync();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📖 ${e.studyMode}模式'),
                  backgroundColor: AppTheme.accent,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding:       EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.accent.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                e.studyMode,
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // ── 签到按钮 ──
          IconButton(
            icon: Icon(
              checkedIn ? Icons.task_alt : Icons.touch_app,
              color: checkedIn ? const Color(0xFF22c55e) : const Color(0xFFeab308),
              size: 22,
            ),
            tooltip: checkedIn ? '今日已签到' : '签到',
            onPressed: checkedIn
                ? null
                : () {
                    e.checkIn();
                    _saveEngineSync();
                    setState(() {});
                  },
          ),
          // ── 保存按钮 ──
          IconButton(
            icon: _saving
                ?       SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.textSecondary,
                    ),
                  )
                : Icon(Icons.save, color: AppTheme.textSecondary, size: 20),
            tooltip: '保存',
            onPressed: _saving ? null : _saveEngine,
          ),
          // ── 统计按钮 ──
          IconButton(
            icon: Icon(Icons.bar_chart, color: AppTheme.textSecondary, size: 20),
            tooltip: '学习中心',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatsScreen(
                    engine: widget.engine,
                    subject: widget.engine.currentSubject.isNotEmpty
                        ? widget.engine.currentSubject
                        : (_subjects.isNotEmpty ? _subjects.first : ''),
                  ),
                ),
              ).then((_) => setState(() {}));
            },
          ),
          // ── 设置按钮 ──
          IconButton(
            icon: Icon(Icons.settings, color: AppTheme.textSecondary, size: 20),
            tooltip: '设置',
            onPressed: () => _showSettings(context),
          ),
          // ── 主题切换 ──
          IconButton(
            icon: Icon(
              AppTheme.isDark ? Icons.light_mode : Icons.dark_mode,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: AppTheme.isDark ? '切换为白色主题' : '切换为黑色主题',
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // ── Logo 区(纯文字 + 简洁图形) ──
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accent.withValues(alpha: 0.07),
                border: Border.all(
                  color: AppTheme.border.withValues(alpha: 0.6),
                ),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                size: 64,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              '元启 AI 学伴',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '语音输入 · 真AI教学 · 游戏化学习',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            // ── 底部状态面板 ──
            _buildStatusPanel(e),

            const SizedBox(height: 16),

            // ── 书架（学科网格） ──
            _buildBookShelf(e),

            const SizedBox(height: 16),

            // ── 添加新学科按钮 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: _showAddSubjectDialog,
                icon: const Icon(Icons.add, size: 18),
                label:       Text('添加新学科'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  side: BorderSide(color: AppTheme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  minimumSize: const Size(double.infinity, 0),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── 版本号页脚 ──
            Text(
              appVersion,
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── 底部状态面板（签到、XP、今日统计、徽章） ──
  Widget _buildStatusPanel(StudyEngine e) {
    final checkedIn = e.isCheckedInToday;
    final today = e.todayRecord;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding:       EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // ── 签到 + XP条 ──
          Row(
            children: [
              // 签到按钮
              GestureDetector(
                onTap: checkedIn
                    ? null
                    : () {
                        e.checkIn();
                        _saveEngineSync();
                        setState(() {});
                      },
                child: Container(
                  padding:       EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: checkedIn
                        ? null
                        : LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accentLight],
                          ),
                    color: checkedIn ? AppTheme.surfaceLight : null,
                    borderRadius: BorderRadius.circular(10),
                    border: checkedIn
                        ? Border.all(color: const Color(0xFF22c55e).withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        checkedIn ? Icons.check_circle : Icons.touch_app,
                        size: 18,
                        color: checkedIn ? const Color(0xFF22c55e) : Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        checkedIn ? '已签到' : '签到',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: checkedIn ? const Color(0xFF22c55e) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // XP条 + 连续天数
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department,
                            size: 14, color: Color(0xFFef4444)),
                        const SizedBox(width: 4),
                        Text(
                          '连续 ${e.streak} 天',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFef4444),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                              Spacer(),
                        Text(
                          'Lv.${e.level}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                              SizedBox(width: 4),
                        Text(
                          '${e.xp}/${e.xpNext} XP',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                          SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: e.xpPercent / 100.0,
                        backgroundColor: AppTheme.border,
                        valueColor:       AlwaysStoppedAnimation<Color>(
                            AppTheme.accent),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
                SizedBox(height: 14),

          // ── 今日统计 ──
          Row(
            children: [
              _buildMiniStat(Icons.timer, '${today.minutes}分钟', '今日学习',
                  AppTheme.accent),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.quiz, '${today.questions}题', '答题',
                  const Color(0xFFf97316)),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.check_circle_outline, '${today.accuracy}%', '正确率',
                  const Color(0xFF22c55e)),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.stars, '${e.totalXp}XP', '总经验',
                  const Color(0xFFeab308)),
            ],
          ),

          const SizedBox(height: 12),

          // ── 徽章行 ──
          _buildBadgeRow(e),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
                SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── 徽章行 ──
  Widget _buildBadgeRow(StudyEngine e) {
    final badges = <MapEntry<String, IconData>>[
      if (e.totalQ >= 1) MapEntry('学员', Icons.school),
      if (e.totalQ >= 10) MapEntry('答题', Icons.rate_review),
      if (e.totalQ >= 100) MapEntry('百题', Icons.military_tech),
      if (e.level >= 5) MapEntry('学霸', Icons.emoji_events),
      if (e.level >= 10) MapEntry('学神', Icons.auto_awesome),
      if (e.streak >= 3) MapEntry('连3', Icons.local_fire_department),
      if (e.streak >= 7) MapEntry('连7', Icons.whatshot),
      if (e.bookmarks.length >= 5) MapEntry('收藏', Icons.bookmark),
    ];
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: badges.map((b) => Container(
        padding:       EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(b.value, size: 12, color: AppTheme.accentLight),
                  SizedBox(width: 4),
            Text(
              b.key,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.accentLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  // ── 书架（学科网格） ──
  Widget _buildBookShelf(StudyEngine e) {
    final subjects = e.subjects.keys.toList();
    if (subjects.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding:       EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(Icons.menu_book, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 8),
                  Text(
              '还没有学科',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
                  Text(
              '点击下方按钮添加你的第一个学科',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding:       EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 16,
                color: AppTheme.accent,
              ),
              const SizedBox(width: 8),
                    Text(
                '我的书架',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
                    Spacer(),
              Text(
                '${subjects.length} 个学科',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.4,
            ),
            itemCount: subjects.length,
            itemBuilder: (_, i) {
              final name = subjects[i];
              final sub = e.getSubject(name);
              return _SubjectCard(
                name: name,
                qCount: sub.q,
                accuracy: sub.accuracy,
                onTap: () {
                  widget.engine.currentSubject = name;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnScreen(
                        engine: widget.engine,
                        subject: name,
                      ),
                    ),
                  ).then((_) {
                    setState(() {
                      _subjects = widget.engine.subjects.keys.toList();
                    });
                    _saveEngineSync();
                  });
                },
                onDelete: () {
                  _confirmDeleteSubject(name);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSubject(String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:       Text(
          '删除学科',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          '确定要删除「$name」吗？\n该学科的学习记录将被清除。',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:       Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              widget.engine.subjects.remove(name);
              if (widget.engine.currentSubject == name) {
                widget.engine.currentSubject = '';
              }
              Navigator.pop(ctx);
              setState(() {
                _subjects = widget.engine.subjects.keys.toList();
              });
              _saveEngineSync();
            },
            child: const Text(
              '删除',
              style: TextStyle(color: Color(0xFFef4444)),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog() {
    final subjectCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title:       Text(
          '添加新学科',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: TextField(
          controller: subjectCtrl,
          autofocus: true,
          style: TextStyle(color: AppTheme.textPrimary),
          decoration:       InputDecoration(
            hintText: '如：高等数学、Python编程',
            hintStyle: TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) {
              widget.engine.getSubject(v.trim());
              Navigator.pop(ctx);
              setState(() {
                _subjects = widget.engine.subjects.keys.toList();
              });
              _saveEngineSync();
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:       Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = subjectCtrl.text.trim();
              if (v.isNotEmpty) {
                widget.engine.getSubject(v);
                Navigator.pop(ctx);
                setState(() {
                  _subjects = widget.engine.subjects.keys.toList();
                });
                _saveEngineSync();
              }
            },
            child:       Text('添加', style: TextStyle(color: AppTheme.accentLight)),
          ),
        ],
      ),
    );
  }

  /// 切换明/暗主题并持久化
  Future<void> _toggleTheme() async {
    setState(() => AppTheme.isDark = !AppTheme.isDark);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', AppTheme.isDark);
  }

  void _showSettings(BuildContext context) {
    // 单个输入框:填 API Key,后端按前缀自动识别
    final controller = TextEditingController(text: ApiService.apiKey);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceLight,
          title:       Text('设置', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: TextStyle(color: AppTheme.textPrimary),
                onChanged: (_) => setDialogState(() {}),
                decoration:       InputDecoration(
                  labelText: 'API Key',
                  hintText: 'sk-...',
                  labelStyle: TextStyle(color: AppTheme.textSecondary),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _backendHint(controller.text),
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:       Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                ApiService.apiKey = controller.text.trim();
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('api_key', ApiService.apiKey);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child:       Text('保存', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      ),
    );
  }

  /// Key 提示(根据前缀实时提示当前识别的后端)
  static String _backendHint(String key) {
    final k = key.trim();
    if (k.startsWith('sk-sp-')) {
      return '🔮 识别为百炼 Qwen（TokenPlan）';
    }
    if (k.startsWith('sk-proj-')) {
      return '⚡ 识别为 OpenAI（GPT）';
    }
    if (k.startsWith('sk-')) {
      return '🔑 识别为 DeepSeek 官方';
    }
    return '💡 填入 API Key，自动识别后端';
  }
}

// ── 学科卡片 ──
class _SubjectCard extends StatelessWidget {
  final String name;
  final int qCount;
  final int accuracy;
  final VoidCallback onTap;
  final VoidCallback onDelete;

        _SubjectCard({
    required this.name,
    this.qCount = 0,
    this.accuracy = 0,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 根据学科名生成颜色
    final colors = [
      AppTheme.accent,
      const Color(0xFFf97316),
      const Color(0xFF22c55e),
      const Color(0xFFeab308),
      const Color(0xFFef4444),
      const Color(0xFF3b82f6),
      const Color(0xFFec4899),
      const Color(0xFF14b8a6),
    ];
    final colorIdx = name.hashCode.abs() % colors.length;
    final cardColor = colors[colorIdx];

    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cardColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0] : '?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cardColor,
                  ),
                ),
              ),
            ),
                  SizedBox(height: 8),
            // 学科名
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
                  SizedBox(height: 4),
            // 统计
            Text(
              '$qCount 题 · $accuracy%',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
