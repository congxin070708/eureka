import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../paper_learning_service.dart';

/// 论文学习进度面板 - 显示两阶段学习进度和章节导航
///
/// 顶部：阶段切换（结构学习 / 内容学习 / 总结回顾）
/// 中部：章节列表（可点击跳转）
/// 底部：整体进度
class PaperStudyPanel extends StatelessWidget {
  final PaperLearningProgress progress;
  final void Function(int index)? onSectionTap;
  final VoidCallback? onEnterReview;

  const PaperStudyPanel({
    super.key,
    required this.progress,
    this.onSectionTap,
    this.onEnterReview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          right: BorderSide(color: AppTheme.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 论文标题
          _buildHeader(),
          // 阶段指示器
          _buildPhaseIndicator(),
          const SizedBox(height: 8),
          // 章节列表
          Expanded(child: _buildSectionList()),
          // 底部进度
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accent, AppTheme.accentLight],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📄 论文深度学习',
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            progress.structure.paperTitle,
            style: const TextStyle(
                fontSize: 15,
                color: Colors.white,
                fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            progress.structure.paperType,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseIndicator() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('学习阶段',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _phaseDot(0, '结构', PaperStudyPhase.structure),
              _phaseLine(0),
              _phaseDot(1, '内容', PaperStudyPhase.content),
              _phaseLine(1),
              _phaseDot(2, '总结', PaperStudyPhase.review),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _phaseDescription(),
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _phaseDot(int index, String label, PaperStudyPhase phase) {
    final isActive = progress.currentPhase == phase;
    final isPast = progress.currentPhase.index > phase.index;

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
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isPast || isActive ? 0.15 : 0.05),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
          child: Icon(icon, size: isPast ? 14 : 10, color: color),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: isActive ? AppTheme.textPrimary : AppTheme.textSecondary,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
      ],
    );
  }

  Widget _phaseLine(int index) {
    final isComplete = progress.currentPhase.index > index;
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

  String _phaseDescription() {
    switch (progress.currentPhase) {
      case PaperStudyPhase.structure:
        return '先搭框架：理解论文整体结构';
      case PaperStudyPhase.content:
        return '深入内容：逐节精读核心知识';
      case PaperStudyPhase.review:
        return '总结回顾：串联全文形成体系';
    }
  }

  Widget _buildSectionList() {
    final sections = progress.structure.topLevelSections;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: sections.length,
      itemBuilder: (_, i) {
        final section = sections[i];
        final isCurrent = progress.currentSection.id == section.id;
        return _buildSectionItem(section, isCurrent);
      },
    );
  }

  Widget _buildSectionItem(PaperSection section, bool isCurrent) {
    final learned = progress.currentPhase == PaperStudyPhase.structure
        ? section.structureLearned
        : section.contentLearned;

    Color bgColor = isCurrent
        ? AppTheme.accent.withValues(alpha: 0.1)
        : Colors.transparent;
    Color textColor =
        isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary;
    FontWeight fontWeight =
        isCurrent ? FontWeight.w600 : FontWeight.w400;

    return GestureDetector(
      onTap: () {
        final idx = progress.structure.sections.indexOf(section);
        if (idx >= 0) onSectionTap?.call(idx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: learned
                    ? AppTheme.taskDone.withValues(alpha: 0.15)
                    : AppTheme.border.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                learned ? Icons.check : Icons.circle,
                size: learned ? 12 : 6,
                color: learned ? AppTheme.taskDone : AppTheme.border,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                section.title,
                style: TextStyle(
                    fontSize: 12, color: textColor, fontWeight: fontWeight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final structurePct = (progress.structure.structureProgress * 100).toStringAsFixed(0);
    final contentPct = (progress.structure.contentProgress * 100).toStringAsFixed(0);

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
              const Text('结构掌握',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('$structurePct%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.structure.structureProgress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('内容掌握',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              Text('$contentPct%',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.taskDone)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.structure.contentProgress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.taskDone),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

/// 阶段切换按钮（嵌入聊天界面顶部）
class PaperPhaseBanner extends StatelessWidget {
  final PaperStudyPhase currentPhase;
  final PaperStructure structure;
  final VoidCallback? onAdvancePhase;

  const PaperPhaseBanner({
    super.key,
    required this.currentPhase,
    required this.structure,
    this.onAdvancePhase,
  });

  @override
  Widget build(BuildContext context) {
    bool canAdvance = false;
    String advanceText = '';
    String phaseText = '';
    IconData phaseIcon = Icons.menu_book;

    switch (currentPhase) {
      case PaperStudyPhase.structure:
        phaseText = '📐 结构学习阶段 - 先理解论文框架';
        phaseIcon = Icons.account_tree_outlined;
        canAdvance = structure.structureProgress >= 0.8;
        advanceText = '进入内容学习';
        break;
      case PaperStudyPhase.content:
        phaseText = '📝 内容学习阶段 - 深入核心知识';
        phaseIcon = Icons.menu_book_outlined;
        canAdvance = structure.contentProgress >= 0.8;
        advanceText = '进入总结回顾';
        break;
      case PaperStudyPhase.review:
        phaseText = '🎓 总结回顾阶段 - 串联全文';
        phaseIcon = Icons.emoji_events_outlined;
        canAdvance = false;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.08),
            AppTheme.accentLight.withValues(alpha: 0.05),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          Icon(phaseIcon, size: 18, color: AppTheme.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              phaseText,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w500),
            ),
          ),
          if (canAdvance && onAdvancePhase != null)
            GestureDetector(
              onTap: onAdvancePhase,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(advanceText,
                        style: const TextStyle(
                            fontSize: 11,
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
}
