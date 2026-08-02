import 'package:flutter/material.dart';

/// 元启AI学伴 · 统一系统主题
/// 灵感来自《学霸的黑科技系统》——深色系统界面+颜色分级
class AppTheme {
  // ── 基础色 ──
  static const Color bg = Color(0xFF0a0a0f); // 最深背景
  static const Color surface = Color(0xFF12121a); // 卡片/面板
  static const Color surfaceLight = Color(0xFF1a1a2e); // 输入框/浅面板
  static const Color border = Color(0xFF2a2a3e); // 边框
  static const Color textPrimary = Color(0xFFe8e8f0); // 主文字
  static const Color textSecondary = Color(0xFF8888aa); // 次要文字
  static const Color accent = Color(0xFF6c5ce7); // 主色调（紫色）
  static const Color accentLight = Color(0xFF8b5cf6); // 浅紫色
  static const Color accentGlow = Color(0xFFa29bfe); // 发光紫

  // ── 价值颜色分级（从高到低） ──
  /// 价值系数 → 颜色
  static Color valueColor(int score) {
    if (score >= 90) return const Color(0xFFef4444); // 🔴 红色 — 神级
    if (score >= 70) return const Color(0xFFf97316); // 🟠 橙色 — 优质
    if (score >= 50) return const Color(0xFFeab308); // 🟡 黄色 — 中等
    if (score >= 30) return const Color(0xFF22c55e); // 🟢 绿色 — 基础
    return const Color(0xFF6b7280); // ⚪ 灰色 — 拓展
  }

  /// 价值等级标签
  static String valueLabel(int score) {
    if (score >= 90) return '神级';
    if (score >= 70) return '优质';
    if (score >= 50) return '中等';
    if (score >= 30) return '基础';
    return '拓展';
  }

  /// 价值等级图标
  static String valueIcon(int score) {
    if (score >= 90) return '🌟';
    if (score >= 70) return '🔥';
    if (score >= 50) return '⭐';
    if (score >= 30) return '📗';
    return '📄';
  }

  // ── 任务状态颜色 ──
  static const Color taskLocked = Color(0xFF4a4a5e);
  static const Color taskActive = Color(0xFF6c5ce7);
  static const Color taskDone = Color(0xFF22c55e);

  // ── 系统字体样式 ──
  static const TextStyle systemTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: accentGlow,
    letterSpacing: 1.2,
  );

  static const TextStyle systemSubtitle = TextStyle(
    fontSize: 13,
    color: textSecondary,
    letterSpacing: 0.8,
  );

  static const TextStyle bookTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle bookValue = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
  );

  // ── 系统分隔线 ──
  static Widget divider() => Container(
        height: 1,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [border.withOpacity(0), border, border.withOpacity(0)],
          ),
        ),
      );

  // ── 系统消息气泡 ──
  static Widget systemBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.2), accentLight.withOpacity(0.1)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, color: accentGlow, letterSpacing: 0.5)),
      );

  // ── 价值系数标签（带颜色） ──
  static Widget valueBadge(int score) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: valueColor(score).withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: valueColor(score).withOpacity(0.3)),
        ),
        child: Text(
          '价值 $score · ${valueLabel(score)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor(score),
          ),
        ),
      );
}
