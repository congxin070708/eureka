import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../study_engine.dart';

/// 演示模式面板 - 从 learn_screen.dart 抽取
/// 不调AI,直接模拟答对/答错,看掌握度变化(仅测试/演示版)
/// 构建时用 --dart-define=DEMO_MODE=true 开启
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

class DemoPanel extends StatelessWidget {
  final StudyEngine engine;
  final String subject;

  const DemoPanel({
    super.key,
    required this.engine,
    required this.subject,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  void show(BuildContext context) {
    if (!kDemoMode) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => _buildContent(ctx, setSheetState),
      ),
    );
  }

  Widget _buildContent(BuildContext ctx, StateSetter setSheetState) {
    final sub = engine.getSubject(subject.trim());
    final kps = sub.knowledgePoints;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science, color: AppTheme.accent, size: 18),
              const SizedBox(width: 8),
              Text('🧪 演示模式 · 模拟答题',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),
          Text('不调AI,直接模拟答对/答错,看掌握度如何变化',
              style:
                  TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          if (kps.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                  '还没有知识点\n先学一个话题(输入话题名→讲解→出题)才会生成',
                  style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.6)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: kps.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildKpCard(kps[i], setSheetState),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildKpCard(KnowledgePoint kp, StateSetter setSheetState) {
    final pct = (kp.mastery * 100).round();
    final gatePct = (kp.gateThreshold * 100).round();
    final status =
        kp.isMastered ? '✅ 已掌握' : '⏳ ${pct}%/${gatePct}%';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: kp.isMastered
                ? const Color(0xFF22c55e).withValues(alpha: 0.4)
                : AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${kp.name}  $status',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.textPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: kp.mastery,
              minHeight: 4,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(
                  kp.isMastered
                      ? const Color(0xFF22c55e)
                      : AppTheme.accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _demoBtn('答对', const Color(0xFF22c55e), () {
                kp.recordAttempt(true);
                setSheetState(() {});
              }),
              const SizedBox(width: 6),
              _demoBtn('答错', const Color(0xFFef4444), () {
                kp.recordAttempt(false);
                setSheetState(() {});
              }),
              const SizedBox(width: 6),
              _demoBtn('重置', AppTheme.textSecondary, () {
                kp.attempts.clear();
                kp.consecutiveCorrect = 0;
                kp.consecutiveWrong = 0;
                setSheetState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _demoBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
