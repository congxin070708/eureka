import 'package:flutter/material.dart';
import '../study_engine.dart';

class ReportScreen extends StatelessWidget {
  final StudyEngine engine;
  final String subject;
  const ReportScreen({super.key, required this.engine, required this.subject});

  @override
  Widget build(BuildContext context) {
    final e = engine;
    final sub = e.getSubject(subject);

    return Scaffold(
      backgroundColor: const Color(0xFF0f0f1a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0f0f1a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFe8e8f0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('📊 学习报告', style: TextStyle(color: Color(0xFFe8e8f0), fontWeight: FontWeight.w700)),
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6c5ce7),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        border: Border.all(color: const Color(0xFF2a2a3e)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFa29bfe))),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

Widget _Row(String label, String value, {Color? color}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF8888aa))),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color ?? const Color(0xFFe8e8f0))),
      ],
    ),
  );
}
