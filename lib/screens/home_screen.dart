import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../study_engine.dart';
import '../api_service.dart';
import '../app_theme.dart';
import '../secure_storage_service.dart';
import '../review_scheduler.dart';
import '../data_export_service.dart';
import '../notification_service.dart';
import '../providers/app_providers.dart';
import '../widgets/api_key_guide_sheet.dart';
import 'learn_screen.dart';
import 'stats_screen.dart';
import 'skill_tree_screen.dart';
import 'gacha_screen.dart';
import 'file_learning_screen.dart';
import 'subject_launch_screen.dart';
import 'knowledge_base_screen.dart';
import '../skill_tree.dart';
import '../version.dart';
import '../preset_courses.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = ref.read(studyEngineProvider);
    if (e.currentSubject.isEmpty && e.subjects.isNotEmpty) {
      e.setCurrentSubject(e.subjects.keys.first);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveEngineSync() async {
    setState(() => _saving = true);
    await ref.read(studyEngineProvider).save();
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
    // ChangeNotifierProvider: ref.watch 返回 notifier 本身,notifyListeners 触发重建
    final e = ref.watch(studyEngineProvider);
    final subjects = e.subjects.keys.toList();
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              const SizedBox(width: 6),
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
              e.setStudyMode(modes[next]);
              _saveEngineSync();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('📖 ${modes[next]}模式'),
                  backgroundColor: AppTheme.accent,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                  },
          ),
          // ── 保存按钮 ──
          IconButton(
            icon: _saving
                ? SizedBox(
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
          // ── 任务中心 ──
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.assignment_outlined, color: AppTheme.textSecondary, size: 22),
                tooltip: '任务中心',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TaskCenterScreen(),
                    ),
                  );
                },
              ),
              if (e.taskManager.claimableCount > 0)
                Positioned(
                  right: 6,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFef4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${e.taskManager.claimableCount}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // ── 商店/抽奖 ──
          IconButton(
            icon: Icon(Icons.card_giftcard, color: AppTheme.textSecondary, size: 22),
            tooltip: '系统商店',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const GachaScreen(),
                ),
              );
            },
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
                    subject: e.currentSubject.isNotEmpty
                        ? e.currentSubject
                        : (subjects.isNotEmpty ? subjects.first : ''),
                  ),
                ),
              ).then((_) => _saveEngineSync());
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
              ref.watch(themeProvider) ? Icons.light_mode : Icons.dark_mode,
              color: AppTheme.textSecondary,
              size: 20,
            ),
            tooltip: ref.watch(themeProvider) ? '切换为白色主题' : '切换为黑色主题',
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // ── Logo 区 ──
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
              '尤里卡',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'AI 学习强化训练 · 掌握度门控 · 遗忘曲线复习',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),

            _buildStatusPanel(e),
            const SizedBox(height: 16),
            _buildReviewPanel(e),
            const SizedBox(height: 16),
            _buildBookShelf(e, subjects),
            const SizedBox(height: 16),

            // ── 快速入口：文件学习 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FileLearningScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF8b5cf6),
                        const Color(0xFF6366f1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366f1).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.description, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              '文件学习',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '上传代码/文档，逐段理解',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 快速入口：知识库 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const KnowledgeBaseScreen(),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0ea5e9),
                        const Color(0xFF0284c7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0ea5e9).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.library_books, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '知识库',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '上传文档，RAG 问答 + 引导阅读',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── 添加新学科按钮 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton.icon(
                onPressed: () => _showAddSubjectDialog(e),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加新学科'),
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

  // ── 状态面板 ──
  Widget _buildStatusPanel(StudyEngine e) {
    final checkedIn = e.isCheckedInToday;
    final today = e.todayRecord;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: checkedIn
                    ? null
                    : () {
                        e.checkIn();
                        _saveEngineSync();
                      },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        const Spacer(),
                        Text(
                          'Lv.${e.level}',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${e.xp}/${e.xpNext} XP',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: e.xpPercent / 100.0,
                        backgroundColor: AppTheme.border,
                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMiniStat(Icons.timer, '${today.minutes}分钟', '今日学习', AppTheme.accent),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.quiz, '${today.questions}题', '答题', const Color(0xFFf97316)),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.check_circle_outline, '${today.accuracy}%', '正确率', const Color(0xFF22c55e)),
              const SizedBox(width: 8),
              _buildMiniStat(Icons.stars, '${e.totalXp}XP', '总经验', const Color(0xFFeab308)),
            ],
          ),
          const SizedBox(height: 12),
          _buildBadgeRow(e),
        ],
      ),
    );
  }

  // ── 复习面板 ──
  Widget _buildReviewPanel(StudyEngine e) {
    final dueReviews = ReviewScheduler.getDueReviews(e);
    if (dueReviews.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFf97316).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.refresh, size: 18, color: Color(0xFFf97316)),
              const SizedBox(width: 8),
              Text(
                '今日待复习 ${dueReviews.length} 个知识点',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFf97316),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...dueReviews.take(5).map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.subject,
                    style: TextStyle(fontSize: 10, color: AppTheme.accentLight),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.knowledgePoint.name,
                    style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                  ),
                ),
                if (r.isUrgent)
                  Text(
                    '过期${r.overdueDays}天',
                    style: const TextStyle(fontSize: 10, color: Color(0xFFef4444)),
                  ),
              ],
            ),
          )),
          if (dueReviews.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '还有 ${dueReviews.length - 5} 个...',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(b.value, size: 12, color: AppTheme.accentLight),
            const SizedBox(width: 4),
            Text(
              b.key,
              style: TextStyle(fontSize: 10, color: AppTheme.accentLight, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildBookShelf(StudyEngine e, List<String> subjects) {
    if (subjects.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Row(
              children: [
                Container(width: 3, height: 16, color: AppTheme.accent),
                const SizedBox(width: 8),
                Text('快速开始', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Spacer(),
                Text('推荐路线', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(height: 12),
            // 预置课程卡片列表
            ...PresetCourses.courses.map((c) => _buildPresetQuickStart(c, e)),
            const SizedBox(height: 12),
            // 自定义学科入口
            GestureDetector(
              onTap: () => _showAddSubjectDialog(e),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.border, style: BorderStyle.solid),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.add, color: AppTheme.accent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('自定义学科',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 2),
                          Text('输入任意知识点开始学习（需 API Key）',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, color: AppTheme.accent),
              const SizedBox(width: 8),
              Text('我的书架', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${subjects.length} 个学科', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
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
                  e.setCurrentSubject(name);
                  // 如果有技能树预设，先走任务发布页
                  final preset = SkillTreePresets.matchPreset(name);
                  if (preset != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectLaunchScreen(subject: name),
                      ),
                    ).then((_) {
                      _saveEngineSync();
                    });
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LearnScreen(subject: name),
                      ),
                    ).then((_) {
                      _saveEngineSync();
                    });
                  }
                },
                onSkillTree: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SkillTreeScreen(subject: name),
                    ),
                  ).then((_) {
                    _saveEngineSync();
                  });
                },
                onDelete: () => _confirmDeleteSubject(name, e),
              );
            },
          ),
        ],
      ),
    );
  }

  /// 预置课程快速开始卡片（空书架时展示）
  Widget _buildPresetQuickStart(PresetCourse course, StudyEngine e) {
    final hasApiKey = ApiService.apiKey.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            // 将预置科目加入引擎并跳转学习页
            e.getSubject(course.subject);
            e.setCurrentSubject(course.subject);
            _saveEngineSync();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LearnScreen(subject: course.subject),
              ),
            ).then((_) => _saveEngineSync());
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(course.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(course.subject,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(width: 6),
                          Text('· ${course.topic}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasApiKey
                            ? '点击开始学习'
                            : '体验模式 · 无需 API Key',
                        style: TextStyle(
                            fontSize: 12,
                            color: hasApiKey
                                ? AppTheme.textSecondary
                                : AppTheme.accent.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteSubject(String name, StudyEngine e) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('删除学科', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('确定要删除「$name」吗？\n该学科的学习记录将被清除。', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              e.removeSubject(name);
              Navigator.pop(ctx);
              _saveEngineSync();
            },
            child: const Text('删除', style: TextStyle(color: Color(0xFFef4444))),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(StudyEngine e) {
    final subjectCtrl = TextEditingController();
    final examples = ['高等数学', 'Python编程', '英语词汇', '数据结构', '机器学习', '经济学原理'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('想学点什么？', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '输入你想学习的学科或具体知识点',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              autofocus: true,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '例如：线性代数、机器学习、英语语法...',
                hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.accent, width: 2),
                ),
              ),
              onSubmitted: (v) {
                if (v.trim().isNotEmpty) {
                  e.getSubject(v.trim());
                  Navigator.pop(ctx);
                  _saveEngineSync();
                }
              },
            ),
            const SizedBox(height: 14),
            Text(
              '💡 试试这些：',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: examples.map((ex) {
                return GestureDetector(
                  onTap: () {
                    subjectCtrl.text = ex;
                    subjectCtrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: ex.length),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      ex,
                      style: TextStyle(fontSize: 11, color: AppTheme.accent),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = subjectCtrl.text.trim();
              if (v.isNotEmpty) {
                e.getSubject(v);
                Navigator.pop(ctx);
                _saveEngineSync();
              }
            },
            child: Text('开始学习', style: TextStyle(color: AppTheme.accentLight, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTheme() async {
    ref.read(themeProvider.notifier).toggle();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', AppTheme.isDark);
  }

  void _showSettings(BuildContext context) {
    final controller = TextEditingController(text: ApiService.apiKey);
    bool notifEnabled = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surfaceLight,
          title: Text('设置', style: TextStyle(color: AppTheme.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── API Key 入口 ──
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ApiKeyGuideSheet(
                      controller: controller,
                      onSaved: (baseUrl) async {
                        ApiService.apiKey = controller.text.trim();
                        ApiService.customBaseUrl = baseUrl;
                        final keyOk = await SecureStorageService.saveApiKey(ApiService.apiKey);
                        final urlOk = await SecureStorageService.saveBaseUrl(baseUrl);
                        ApiService.clearDetectionCache();
                        if (context.mounted) Navigator.pop(context);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(keyOk && urlOk
                                  ? '✅ API Key 已保存'
                                  : '⚠️ 保存失败，请检查系统存储权限'),
                              backgroundColor: keyOk && urlOk
                                  ? AppTheme.taskDone
                                  : Colors.orange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      onClosed: () => Navigator.pop(context),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, size: 22, color: Color(0xFFf97316)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'API Key 设置',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              ApiService.apiKey.isEmpty
                                  ? '还没设置，点击配置'
                                  : '已配置 · ${_backendHint(ApiService.apiKey)}',
                              style: TextStyle(
                                  fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ── 数据管理 ──
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final engine = ref.read(studyEngineProvider);
                        await DataExportService.exportData(engine);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('导出数据', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final imported = await DataExportService.importData();
                        if (imported != null) {
                          ref.read(studyEngineProvider).replaceEngine(imported);
                          await ref.read(studyEngineProvider).save();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('导入失败,请检查文件'),
                              backgroundColor: Color(0xFFef4444),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('导入数据', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: Text('复习提醒', style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
                subtitle: Text('每天20:00提醒复习到期知识点', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                value: notifEnabled,
                onChanged: (val) async {
                  setDialogState(() => notifEnabled = val);
                  if (val) {
                    await NotificationService.requestPermissions();
                    await NotificationService.scheduleDailyReviewReminder();
                  } else {
                    await NotificationService.cancelAll();
                  }
                },
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('完成', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  static String _backendHint(String key) {
    final k = key.trim();
    if (k.startsWith('sk-sp-')) return '🔮 识别为百炼 Qwen（TokenPlan）';
    if (k.startsWith('sk-proj-')) return '⚡ 识别为 OpenAI（GPT）';
    if (k.startsWith('sk-')) return '🔑 识别为 DeepSeek 官方';
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
  final VoidCallback onSkillTree;

  const _SubjectCard({
    required this.name,
    this.qCount = 0,
    this.accuracy = 0,
    required this.onTap,
    required this.onDelete,
    required this.onSkillTree,
  });

  @override
  Widget build(BuildContext context) {
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: cardColor),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '$qCount 题 · $accuracy%',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: onSkillTree,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_alt, size: 11, color: AppTheme.accent),
                    const SizedBox(width: 3),
                    Text(
                      '技能树',
                      style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
