import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../smart_content_detector.dart';

/// 智能学习侧边面板 - 适配所有内容类型
///
/// 功能：
/// - 顶部：内容类型识别卡（显示检测结果和置信度）
/// - 中部：阶段指示器 + 章节/段落导航
/// - 底部：进度统计
class SmartLearningPanel extends StatelessWidget {
  final ContentTypeDetection detection;
  final LearningPhase currentPhase;
  final List<ContentSegment> segments;
  final int currentIndex;
  final double overallProgress;
  final void Function(int index)? onSegmentTap;
  final VoidCallback? onAdvancePhase;

  const SmartLearningPanel({
    super.key,
    required this.detection,
    required this.currentPhase,
    required this.segments,
    required this.currentIndex,
    required this.overallProgress,
    this.onSegmentTap,
    this.onAdvancePhase,
  });

  @override
  Widget build(BuildContext context) {
    final config = LearningModeLibrary.get(detection.type);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 内容类型识别卡
          _buildTypeCard(config),
          const SizedBox(height: 8),
          // 阶段指示器
          if (config.phases.length > 1) _buildPhaseIndicator(config),
          const SizedBox(height: 8),
          // 分段列表
          Expanded(child: _buildSegmentList(config)),
          // 底部进度
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildTypeCard(LearningModeConfig config) {
    final confidencePercent = (detection.confidence * 100).toStringAsFixed(0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent.withValues(alpha: 0.9),
            AppTheme.accentLight.withValues(alpha: 0.7),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(config.icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(config.modeName,
                        style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('智能识别 · 置信度 $confidencePercent%',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(config.description,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white, height: 1.4)),
          // 置信度进度条
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: detection.confidence,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator(LearningModeConfig config) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('学习阶段',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 10),
          Row(
            children: [
              for (int i = 0; i < config.phases.length; i++) ...[
                _phaseDot(i, config.phases[i], config),
                if (i < config.phases.length - 1) _phaseLine(i, config),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _phaseDescription(currentPhase),
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _phaseDot(int index, LearningPhase phase, LearningModeConfig config) {
    final currentIdx = config.phases.indexOf(currentPhase);
    final isActive = phase == currentPhase;
    final isPast = index < currentIdx;

    Color color;
    IconData icon;
    if (isPast) {
      color = AppTheme.taskDone;
      icon = Icons.check;
    } else if (isActive) {
      color = AppTheme.accent;
      icon = Icons.circle;
    } else {
      color = AppTheme.border;
      icon = Icons.circle_outlined;
    }

    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isPast || isActive ? 0.15 : 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: isPast ? 14 : 8, color: color),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 50,
          child: Text(
            _phaseShortName(phase),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _phaseLine(int index, LearningModeConfig config) {
    final currentIdx = config.phases.indexOf(currentPhase);
    final isComplete = index < currentIdx;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: isComplete ? AppTheme.taskDone : AppTheme.border,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }

  String _phaseShortName(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return '概览';
      case LearningPhase.detail: return '精读';
      case LearningPhase.practice: return '练习';
      case LearningPhase.review: return '总结';
    }
  }

  String _phaseDescription(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview:
        return '建立整体认知，了解结构和框架';
      case LearningPhase.detail:
        return '深入学习每一部分的核心内容';
      case LearningPhase.practice:
        return '通过练习检验和巩固所学';
      case LearningPhase.review:
        return '串联总结，形成完整知识体系';
    }
  }

  Widget _buildSegmentList(LearningModeConfig config) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: segments.length,
      itemBuilder: (_, i) {
        final seg = segments[i];
        final isCurrent = i == currentIndex;
        final isLearned = seg.mastery >= 0.7;
        return _buildSegmentItem(seg, i, isCurrent, isLearned, config);
      },
    );
  }

  Widget _buildSegmentItem(
    ContentSegment seg,
    int index,
    bool isCurrent,
    bool isLearned,
    LearningModeConfig config,
  ) {
    Color bgColor = isCurrent
        ? AppTheme.accent.withValues(alpha: 0.1)
        : Colors.transparent;
    Color textColor =
        isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary;
    FontWeight fontWeight =
        isCurrent ? FontWeight.w600 : FontWeight.w400;

    // 段类型图标
    IconData typeIcon = _segmentIcon(seg.segmentType);
    Color typeColor = _segmentColor(seg.segmentType);

    return GestureDetector(
      onTap: () => onSegmentTap?.call(index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            // 状态/序号
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: isLearned
                    ? AppTheme.taskDone.withValues(alpha: 0.15)
                    : isCurrent
                        ? AppTheme.accent.withValues(alpha: 0.15)
                        : AppTheme.border.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isLearned
                    ? Icon(Icons.check, size: 12, color: AppTheme.taskDone)
                    : Text('${index + 1}',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isCurrent
                                ? AppTheme.accent
                                : AppTheme.textSecondary)),
              ),
            ),
            const SizedBox(width: 8),
            // 段类型图标
            Icon(typeIcon, size: 12, color: typeColor),
            const SizedBox(width: 4),
            // 标题
            Expanded(
              child: Text(
                seg.title,
                style: TextStyle(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: fontWeight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _segmentIcon(String type) {
    switch (type) {
      case 'class': return Icons.category_outlined;
      case 'function': return Icons.code_outlined;
      case 'chapter': return Icons.menu_book_outlined;
      case 'section': return Icons.segment_outlined;
      case 'example': return Icons.lightbulb_outline;
      case 'exercise': return Icons.edit_outlined;
      case 'api': return Icons.api_outlined;
      case 'example_code': return Icons.terminal_outlined;
      case 'paragraph': return Icons.article_outlined;
      case 'paper_section': return Icons.description_outlined;
      default: return Icons.fiber_manual_record;
    }
  }

  Color _segmentColor(String type) {
    switch (type) {
      case 'class': return const Color(0xFF8b5cf6);
      case 'function': return const Color(0xFF3b82f6);
      case 'chapter': return const Color(0xFFf97316);
      case 'section': return const Color(0xFF06b6d4);
      case 'example': return const Color(0xFFf59e0b);
      case 'exercise': return const Color(0xFF22c55e);
      case 'api': return const Color(0xFFec4899);
      case 'paragraph': return const Color(0xFF6b7280);
      default: return AppTheme.textSecondary;
    }
  }

  Widget _buildFooter() {
    final learnedCount = segments.where((s) => s.mastery >= 0.7).length;
    final percent = (overallProgress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('学习进度',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('$learnedCount/${segments.length} · $percent%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: overallProgress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 8),
          // 下一节按钮
          if (currentIndex < segments.length - 1)
            SizedBox(
              width: double.infinity,
              height: 32,
              child: ElevatedButton(
                onPressed: () => onSegmentTap?.call(currentIndex + 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('下一段',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_downward,
                        size: 14, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 顶部阶段横幅
class PhaseBanner extends StatelessWidget {
  final ContentType contentType;
  final LearningPhase currentPhase;
  final int totalSegments;
  final int currentSegment;
  final VoidCallback? onAdvancePhase;
  final bool canAdvancePhase;

  const PhaseBanner({
    super.key,
    required this.contentType,
    required this.currentPhase,
    required this.totalSegments,
    required this.currentSegment,
    this.onAdvancePhase,
    this.canAdvancePhase = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = LearningModeLibrary.get(contentType);
    final phaseName = _phaseName(currentPhase);
    final phaseIcon = _phaseIcon(currentPhase);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.06),
            AppTheme.accentLight.withValues(alpha: 0.03),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.15)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(phaseIcon, size: 18, color: AppTheme.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$phaseName阶段 · ${config.modeName}',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '第 ${currentSegment + 1} / $totalSegments 段 · ${_phaseHint(currentPhase)}',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          if (canAdvancePhase && onAdvancePhase != null)
            GestureDetector(
              onTap: onAdvancePhase,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_nextPhaseText(config),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_forward,
                        size: 12, color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _phaseName(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return '📐 结构概览';
      case LearningPhase.detail: return '📝 内容精读';
      case LearningPhase.practice: return '✏️ 练习巩固';
      case LearningPhase.review: return '🎓 总结回顾';
    }
  }

  IconData _phaseIcon(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return Icons.account_tree_outlined;
      case LearningPhase.detail: return Icons.menu_book_outlined;
      case LearningPhase.practice: return Icons.edit_outlined;
      case LearningPhase.review: return Icons.emoji_events_outlined;
    }
  }

  String _phaseHint(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return '先搭框架，建立整体认知';
      case LearningPhase.detail: return '深入细节，逐段攻克';
      case LearningPhase.practice: return '动手练习，检验掌握';
      case LearningPhase.review: return '串联总结，形成体系';
    }
  }

  String _nextPhaseText(LearningModeConfig config) {
    final currentIdx = config.phases.indexOf(currentPhase);
    if (currentIdx < config.phases.length - 1) {
      final nextPhase = config.phases[currentIdx + 1];
      switch (nextPhase) {
        case LearningPhase.overview: return '进入概览';
        case LearningPhase.detail: return '开始精读';
        case LearningPhase.practice: return '开始练习';
        case LearningPhase.review: return '查看总结';
      }
    }
    return '完成';
  }
}

/// 类型标签 chip
class ContentTypeChip extends StatelessWidget {
  final ContentType type;
  final double confidence;
  final VoidCallback? onTap;

  const ContentTypeChip({
    super.key,
    required this.type,
    required this.confidence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = LearningModeLibrary.get(type);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(config.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 4),
            Text(config.modeName,
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Text('${(confidence * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                    fontSize: 10, color: AppTheme.accent.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
