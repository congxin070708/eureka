import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../version.dart';
import '../providers/app_providers.dart';
import 'settings_screen.dart';
import 'about_screen.dart';
import 'stats_screen.dart';

/// 个人中心页
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final e = ref.watch(studyEngineProvider);

    final subjects = e.subjects.values.toList();
    final avgAccuracy = subjects.isEmpty
        ? 0
        : (subjects.fold<int>(0, (sum, s) => sum + s.accuracy) ~/
            subjects.length);
    final subjectForStats = e.currentSubject.isNotEmpty
        ? e.currentSubject
        : (e.subjects.isNotEmpty ? e.subjects.keys.first : '');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.settings,
                color: AppTheme.textSecondary, size: 22),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── 用户头部卡片 ──
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [AppTheme.accent, AppTheme.accentLight]),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person,
                        size: 48, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('学习者',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('Lv.${e.level} · ${e.xp} XP',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.white70)),
                    ],
                  ),
                ],
              ),
            ),
            // ── 数据概览卡片 ──
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding:
                  const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(child: _buildStatItem('${e.totalQ}', '总答题')),
                  Expanded(child: _buildStatItem('$avgAccuracy%', '平均正确率')),
                  Expanded(child: _buildStatItem('${e.streak}', '连续天数')),
                  Expanded(
                      child: _buildStatItem(
                          '${e.subjects.length}', '学习科目')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── 快捷入口 ──
            _buildSection('快捷入口', [
              _buildTile(
                Icons.bar_chart,
                '学习统计',
                '查看详细学习数据',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StatsScreen(subject: subjectForStats),
                  ),
                ),
              ),
              _buildTile(
                Icons.settings,
                '设置',
                'API Key、数据、通知等',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),
              _buildTile(
                Icons.info,
                '关于',
                '版本 $appVersion',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            // ── 底部版权 ──
            Center(
              child: Text(appVersion,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 单格统计项 ──
  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.accentGlow)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  // ── 与设置页一致的列表项样式 ──
  Widget _buildTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppTheme.accentLight),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: AppTheme.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                      height: 1,
                      color: AppTheme.border.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
