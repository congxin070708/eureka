import 'package:flutter/material.dart';

/// 元启AI学伴 · 统一主题
/// 支持明/暗两套配色,可自由切换
class AppTheme {
  AppTheme._();

  // ── 当前主题模式(由 main.dart 在启动时设置) ──
  static bool isDark = true;

  // ── 基础色(明/暗双套) ──
  static Color get bg => isDark ? const Color(0xFF0a0a0f) : const Color(0xFFf7f7f9); // 背景
  static Color get surface => isDark ? const Color(0xFF12121a) : const Color(0xFFFFFFFF); // 卡片/面板
  static Color get surfaceLight => isDark ? const Color(0xFF1a1a2e) : const Color(0xFFf0f0f4); // 输入框/浅面板
  static Color get border => isDark ? const Color(0xFF2a2a3e) : const Color(0xFFd8d8e0); // 边框
  static Color get textPrimary => isDark ? const Color(0xFFe8e8f0) : const Color(0xFF1a1a24); // 主文字
  static Color get textSecondary => isDark ? const Color(0xFF8888aa) : const Color(0xFF6b6b80); // 次要文字
  static Color get accent => isDark ? const Color(0xFF6c5ce7) : const Color(0xFF5b4bd5); // 主色调（紫）
  static Color get accentLight => isDark ? const Color(0xFF8b5cf6) : const Color(0xFF7c6af0); // 浅紫
  static Color get accentGlow => isDark ? const Color(0xFFa29bfe) : const Color(0xFF6c5ce7); // 发光紫(亮色下取深紫保证可读)

  // ── 任务状态颜色 ──
  static const Color taskLocked = Color(0xFF9a9aae);
  static Color get taskActive => accent;
  static const Color taskDone = Color(0xFF22c55e);

  // ── 语义状态色(明暗通用,保证对比度) ──
  static const Color success = Color(0xFF22c55e);  // ✅ 成功/正确/已完成
  static const Color warning = Color(0xFFf97316);  // ⚠️ 提醒/待复习
  static const Color error = Color(0xFFef4444);    // ❌ 错误/删除
  static const Color info = Color(0xFFeab308);     // 💡 提示/经验值
  static const Color dimGray = Color(0xFF888888);  // ⚪ 中性灰(通用)

  // ── 价值颜色分级（从高到低,明暗通用） ──
  static Color valueColor(int score) {
    if (score >= 90) return const Color(0xFFef4444); // 🔴 神级
    if (score >= 70) return const Color(0xFFf97316); // 🟠 优质
    if (score >= 50) return const Color(0xFFeab308); // 🟡 中等
    if (score >= 30) return const Color(0xFF22c55e); // 🟢 基础
    return const Color(0xFF6b7280); // ⚪ 拓展
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

  // ── 系统字体样式 ──
  static TextStyle get systemTitle => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: accentGlow,
    letterSpacing: 1.2,
  );

  static TextStyle get systemSubtitle => TextStyle(
    fontSize: 13,
    color: textSecondary,
    letterSpacing: 0.8,
  );

  static TextStyle get bookTitle => TextStyle(
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
            colors: [border.withValues(alpha: 0), border, border.withValues(alpha: 0)],
          ),
        ),
      );

  // ── 系统消息气泡 ──
  static Widget systemBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.2), accentLight.withValues(alpha: 0.1)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.3)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: accentGlow, letterSpacing: 0.5)),
      );

  // ── 价值系数标签（带颜色） ──
  static Widget valueBadge(int score) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: valueColor(score).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: valueColor(score).withValues(alpha: 0.3)),
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
