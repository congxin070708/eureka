import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../study_engine.dart';
import '../app_theme.dart';
import '../providers/app_providers.dart';

/// 学习统计 + 收藏页面 - 改用 Riverpod 读取引擎数据
class StatsScreen extends ConsumerStatefulWidget {
  final String subject;
  const StatsScreen({super.key, required this.subject});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(studyEngineProvider);
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text('学习中心', style: TextStyle(color: AppTheme.textPrimary)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: '统计', icon: Icon(Icons.bar_chart, size: 18)),
            Tab(text: '收藏', icon: Icon(Icons.bookmark, size: 18)),
            Tab(text: '成就', icon: Icon(Icons.emoji_events, size: 18)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildStatsTab(e),
          _buildBookmarksTab(e),
          _buildAchievementsTab(e),
        ],
      ),
    );
  }

  // ── 统计页 ──
  Widget _buildStatsTab(StudyEngine e) {
    final sub = e.getSubject(widget.subject);
    final today = e.todayRecord;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('📋 学习小结'),
          const SizedBox(height: 8),
          _StatCard(child: _buildSummary(e)),
          const SizedBox(height: 16),

          // 等级卡片
          _StatCard(
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text('Lv.${e.level}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('等级 ${e.level}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: e.xpPercent / 100.0,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.accent),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${e.xp} / ${e.xpNext} XP  (${e.xpPercent}%)',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 今日统计
          const _SectionTitle('今日学习'),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(Icons.timer, '${today.minutes}分钟', '学习时长',
                  AppTheme.accent),
              const SizedBox(width: 8),
              _MiniStat(Icons.quiz, '${today.questions}题', '答题数',
                  const Color(0xFFf97316)),
              const SizedBox(width: 8),
              _MiniStat(Icons.check_circle, '${today.accuracy}%', '正确率',
                  const Color(0xFF22c55e)),
            ],
          ),
          const SizedBox(height: 16),

          // 总统计
          const _SectionTitle('总统计'),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(Icons.stars, '${e.totalXp}XP', '总经验',
                  const Color(0xFFeab308)),
              const SizedBox(width: 8),
              _MiniStat(Icons.auto_awesome, '${e.studyDays}天', '学习天数',
                  AppTheme.accent),
              const SizedBox(width: 8),
              _MiniStat(Icons.local_fire_department, '🔥${e.streak}', '连续',
                  const Color(0xFFef4444)),
            ],
          ),
          const SizedBox(height: 16),

          // 科目统计
          _SectionTitle('「${widget.subject}」学习情况'),
          const SizedBox(height: 8),
          _StatCard(
            child: Column(
              children: [
                _StatRow('答题总数', '${sub.q} 题'),
                _StatRow('正确数', '${sub.ok} 题'),
                _StatRow('正确率', '${sub.accuracy}%'),
                _StatRow('历史最高连续', '${e.bestStreak} 天'),
                _StatRow('总学习时长', '${e.totalStudyMinutes} 分钟'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 学习小结 ──
  Widget _buildSummary(StudyEngine e) {
    final today = e.todayRecord;
    final weekQuestions =
        e.dailyRecords.take(7).fold(0, (sum, r) => sum + r.questions);
    final weekCorrect =
        e.dailyRecords.take(7).fold(0, (sum, r) => sum + r.correct);

    String advice;
    if (e.totalQ == 0) {
      advice = '还没有学习记录，开始学习吧！';
    } else if (today.questions == 0) {
      advice = '今天还没有学习，加油！';
    } else if (today.accuracy >= 80) {
      advice = '今天状态很好，继续保持！';
    } else if (today.accuracy >= 60) {
      advice = '今天表现不错，可以再复习一下薄弱点。';
    } else {
      advice = '今天错的比较多，建议回顾一下基础概念。';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('📅 今日',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            Text(
                '${today.questions}题 · ${today.accuracy}%正确率 · ${today.minutes}分钟',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('📅 本周',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const Spacer(),
            Text(
                '$weekQuestions题 · ${weekQuestions > 0 ? (weekCorrect * 100 ~/ weekQuestions) : 0}%正确率',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lightbulb, size: 14, color: Color(0xFFeab308)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(advice,
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.textPrimary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── 收藏页 ──
  Widget _buildBookmarksTab(StudyEngine e) {
    final userBookmarks = e.bookmarks;
    if (userBookmarks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📌', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('还没有收藏',
                style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Text('在知识点讲解中点击收藏按钮即可添加',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: userBookmarks.length,
      itemBuilder: (_, i) {
        final b = userBookmarks[i];
        return Dismissible(
          key: Key(b.time),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFef4444).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.delete, color: Color(0xFFef4444)),
          ),
          onDismissed: (_) {
            e.removeBookmark(i);
          },
          child: Card(
            color: AppTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.border),
            ),
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: AppTheme.bg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(b.subject,
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.accentLight)),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(Icons.close,
                                    size: 18, color: AppTheme.textSecondary),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(b.title,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            child: SelectableText(b.content,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.textSecondary,
                                    height: 1.6)),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(b.subject,
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.accentLight)),
                        ),
                        const Spacer(),
                        Text(
                          b.time.length >= 16 ? b.time.substring(11, 16) : '',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(b.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary)),
                    if (b.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(b.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              height: 1.5)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── 成就页 ──
  Widget _buildAchievementsTab(StudyEngine e) {
    final achievements = _getAchievements(e);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (_, i) {
        final a = achievements[i];
        final unlocked = a.condition(e);
        return Container(
          decoration: BoxDecoration(
            color: unlocked
                ? AppTheme.surface
                : AppTheme.surfaceLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  unlocked ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(unlocked ? a.icon : '🔒',
                  style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                a.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: unlocked
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<_Achievement> _getAchievements(StudyEngine e) => [
        _Achievement('初出茅庐', '🎓', (_) => e.totalQ >= 1),
        _Achievement('答题达人', '📝', (_) => e.totalQ >= 10),
        _Achievement('百题斩', '⚔️', (_) => e.totalQ >= 100),
        _Achievement('学霸', '🏆', (_) => e.level >= 5),
        _Achievement('学神', '👑', (_) => e.level >= 10),
        _Achievement('连续3天', '🔥', (_) => e.consecutiveDays >= 3),
        _Achievement('连续7天', '💪', (_) => e.consecutiveDays >= 7),
        _Achievement('全对', '🎯', (_) => e.accuracy == 100 && e.totalQ >= 5),
        _Achievement('收藏家', '📌', (_) => e.bookmarks.length >= 5),
        _Achievement('完美一天', '✨', (_) {
          final t = e.todayRecord;
          return t.questions >= 5 && t.accuracy == 100;
        }),
        _Achievement('持之以恒', '🌟', (_) => e.studyDays >= 7),
        _Achievement('满月', '🌙', (_) => e.studyDays >= 30),
      ];
}

// ── 小组件 ──
class _StatCard extends StatelessWidget {
  final Widget child;
  const _StatCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 16, color: AppTheme.accent),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _MiniStat(this.icon, this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}

class _Achievement {
  final String name;
  final String icon;
  final bool Function(StudyEngine) condition;
  _Achievement(this.name, this.icon, this.condition);
}
