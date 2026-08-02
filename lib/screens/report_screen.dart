import 'package:flutter/material.dart';
import '../study_engine.dart';
import '../app_theme.dart';

class ReportScreen extends StatelessWidget {
  final StudyEngine engine;
  final String subject;
        ReportScreen({super.key, required this.engine, required this.subject});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final sub = e.getSubject(subject);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title:       Text('📊 学习报告', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            title: '🏆 $subject 总览',
            children: [
              _Row('等级', 'Lv.${e.level}'),
              _Row('总经验', '${e.totalXp} XP'),
              _Row('答题数', '${e.totalQ} 题'),
              _Row('准确率', '${e.accuracy}%', color: e.accuracy >= 60 ? const Color(0xFF4ade80) : const Color(0xFFfbbf24)),
              _Row('连续正确', '🔥 ${e.streak}（最佳${e.bestStreak}）'),
              _Row('本章准确率', '${sub.accuracy}%'),
            ],
          ),
          if (e.history.isNotEmpty)
            _Card(
              title: '📝 最近记录',
              children: e.history.take(10).map((h) => _Row(
                '${h.score >= 60 ? "✅" : "❌"} ${h.subject}',
                '${h.score}分 +${h.xpGain}XP',
              )).toList(),
            ),
                SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('📖 继续学习', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Card({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding:       EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.accentGlow)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

Widget _Row(String label, String value, {Color? color}) {
  return Padding(
    padding:       EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? AppTheme.textPrimary)),
      ],
    ),
  );
}
