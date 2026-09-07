import 'study_engine.dart';

/// 遗忘曲线复习调度器
/// 基于间隔重复算法(Spaced Repetition),调度到期需复习的知识点
/// 间隔序列参考 SM-2 算法简化版: 1d → 3d → 7d → 14d → 30d → 60d
class ReviewScheduler {
  /// 间隔重复间隔表(天)
  static const List<int> _intervals = [1, 3, 7, 14, 30, 60];

  /// 答对后推进间隔索引,答错重置
  static void updateKnowledgePoint(KnowledgePoint kp, bool correct) {
    if (correct) {
      kp.consecutiveWrong = 0;
      // 推进到下一个间隔(不超过表长)
      if (kp.intervalIndex < _intervals.length - 1) {
        kp.intervalIndex++;
      }
    } else {
      kp.consecutiveCorrect = 0;
      // 答错回退一格(不小于0)
      if (kp.intervalIndex > 0) kp.intervalIndex--;
    }
    // 计算下次复习时间戳(秒)
    final days = _intervals[kp.intervalIndex.clamp(0, _intervals.length - 1)];
    kp.nextReviewAt =
        DateTime.now().add(Duration(days: days)).millisecondsSinceEpoch ~/ 1000;
  }

  /// 获取所有到期需复习的知识点
  /// 按 nextReviewAt 升序排列(最该复习的排前面)
  static List<ReviewItem> getDueReviews(StudyEngine engine, {int? limit}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final items = <ReviewItem>[];

    for (final entry in engine.subjects.entries) {
      final subjectName = entry.key;
      final subjectData = entry.value;
      for (final kp in subjectData.knowledgePoints) {
        // 已掌握的不需要复习(除非到期)
        // nextReviewAt == 0 表示从未安排过,跳过
        if (kp.nextReviewAt == 0) continue;
        if (kp.nextReviewAt <= now) {
          items.add(ReviewItem(
            subject: subjectName,
            knowledgePoint: kp,
            overdueDays: ((now - kp.nextReviewAt) ~/ 86400),
          ));
        }
      }
    }

    // 按到期时间升序:最早到期的排最前面
    items.sort((a, b) =>
        a.knowledgePoint.nextReviewAt.compareTo(b.knowledgePoint.nextReviewAt));

    if (limit != null && items.length > limit) {
      return items.sublist(0, limit);
    }
    return items;
  }

  /// 获取今日待复习数量
  static int getDueCount(StudyEngine engine) {
    return getDueReviews(engine).length;
  }

  /// 获取某科目下待复习的知识点
  static List<ReviewItem> getDueReviewsForSubject(
      StudyEngine engine, String subject) {
    final all = getDueReviews(engine);
    return all.where((r) => r.subject == subject).toList();
  }
}

/// 复习项
class ReviewItem {
  final String subject;
  final KnowledgePoint knowledgePoint;
  final int overdueDays; // 过期天数(0=今天到期)

  ReviewItem({
    required this.subject,
    required this.knowledgePoint,
    required this.overdueDays,
  });

  /// 是否严重过期(超过3天)
  bool get isUrgent => overdueDays >= 3;
}
