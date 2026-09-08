import 'package:flutter_test/flutter_test.dart';
import 'package:eureka/study_engine.dart';
import 'package:eureka/review_scheduler.dart';

void main() {
  // ═══════════════════════════════════════════════════
  // KnowledgePoint 掌握度计算测试
  // ═══════════════════════════════════════════════════
  group('KnowledgePoint mastery', () {
    test('空答题记录时掌握度为0', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      expect(kp.mastery, 0.0);
    });

    test('答1题对 → 掌握度上限50%(防蒙对一次就毕业)', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      kp.recordAttempt(true);
      expect(kp.mastery, 0.5);
    });

    test('答2题全对 → 掌握度上限80%', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      kp.recordAttempt(true);
      kp.recordAttempt(true);
      expect(kp.mastery, 0.8);
    });

    test('答3题全对 → 掌握度可达100%', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      kp.recordAttempt(true);
      kp.recordAttempt(true);
      kp.recordAttempt(true);
      expect(kp.mastery, greaterThan(0.8));
    });

    test('答5题全对 → 掌握度1.0', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      for (int i = 0; i < 5; i++) kp.recordAttempt(true);
      expect(kp.mastery, 1.0);
    });

    test('答5题全错 → 掌握度0.0', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      for (int i = 0; i < 5; i++) kp.recordAttempt(false);
      expect(kp.mastery, 0.0);
    });

    test('近期答题权重高于早期(近因效应)', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      // 先答对2题,再答错1题
      kp.recordAttempt(true);
      kp.recordAttempt(true);
      kp.recordAttempt(false);
      // 最近5题: [对,对,错], 不是满分
      expect(kp.mastery, lessThan(0.8));
      // 但也不是0,因为前面对的有权重
      expect(kp.mastery, greaterThan(0.0));
    });
  });

  // ═══════════════════════════════════════════════════
  // KnowledgePoint 门控阈值测试
  // ═══════════════════════════════════════════════════
  group('KnowledgePoint gateThreshold', () {
    test('神级(importance>=90) → 门槛95%', () {
      final kp = KnowledgePoint(name: '高数极限', type: 'memory', importance: 95);
      expect(kp.gateThreshold, 0.95);
    });

    test('优质(importance 70) → 门槛90%', () {
      final kp = KnowledgePoint(name: '微积分', type: 'memory', importance: 70);
      expect(kp.gateThreshold, 0.90);
    });

    test('拓展(importance<=29) → 门槛70%', () {
      final kp = KnowledgePoint(name: '拓展知识', type: 'memory', importance: 20);
      expect(kp.gateThreshold, 0.70);
    });

    test('概念/设计型 → 门槛1.0(需AI定性评判)', () {
      final kp = KnowledgePoint(name: '设计模式', type: 'concept', importance: 80);
      expect(kp.gateThreshold, 1.0);
      expect(kp.isMastered, false); // 需 qualitativeMastery=true
    });

    test('概念型 qualitativeMastery=true → 已掌握', () {
      final kp = KnowledgePoint(name: '设计模式', type: 'concept');
      kp.qualitativeMastery = true;
      expect(kp.isMastered, true);
    });
  });

  // ═══════════════════════════════════════════════════
  // StudyEngine 记录与升级测试
  // ═══════════════════════════════════════════════════
  group('StudyEngine record', () {
    test('答对(60分+) → totalCorrect增加,streak+1', () {
      final engine = StudyEngine();
      final result = engine.record('数学', 80);
      expect(engine.totalQ, 1);
      expect(engine.totalCorrect, 1);
      expect(engine.streak, 1);
      expect(result.leveledUp, false);
    });

    test('答错(<60分) → streak重置为0', () {
      final engine = StudyEngine();
      engine.record('数学', 80); // 先答对
      expect(engine.streak, 1);
      engine.record('数学', 30); // 再答错
      expect(engine.streak, 0);
    });

    test('连续答对3题 → 有streak加成XP', () {
      final engine = StudyEngine();
      engine.record('数学', 80);
      engine.record('数学', 80);
      final result = engine.record('数学', 80);
      // streak >= 3, 额外+2 XP
      // 基础 XP = 80/10 = 8, streak bonus = 2, total = 10
      expect(result.xpGain, 10);
    });

    test('90分+ → 有额外XP加成', () {
      final engine = StudyEngine();
      final result = engine.record('数学', 95);
      // 基础 XP = 95/10 = 9, 90分+加成 = 5, total = 14
      expect(result.xpGain, 14);
    });

    test('XP足够 → 升级', () {
      final engine = StudyEngine();
      engine.xp = 95;
      engine.xpNext = 100;
      final result = engine.record('数学', 80);
      // XP gain = 8, 95+8=103 >= 100 → 升级
      expect(result.leveledUp, true);
      expect(result.newLevel, 2);
    });
  });

  // ═══════════════════════════════════════════════════
  // chatHistory 序列化测试(关键bug修复验证)
  // ═══════════════════════════════════════════════════
  group('chatHistory serialization', () {
    test('toJson/fromJson 往返不丢数据', () {
      final engine = StudyEngine();
      engine.chatHistory['数学'] = [
        {'emoji': '📖', 'text': '讲解微积分', 'isAI': true},
        {'emoji': '👤', 'text': '我懂了', 'isAI': false},
      ];

      final json = engine.toJson();
      final restored = StudyEngine.fromJson(json);

      expect(restored.chatHistory, isNotEmpty);
      expect(restored.chatHistory['数学'], isNotNull);
      expect(restored.chatHistory['math'], isNull); // 错误的key
      expect(restored.chatHistory['数学']!.length, 2);
      expect(restored.chatHistory['数学']![0]['text'], '讲解微积分');
      expect(restored.chatHistory['数学']![0]['isAI'], true);
      expect(restored.chatHistory['数学']![1]['text'], '我懂了');
      expect(restored.chatHistory['数学']![1]['isAI'], false);
    });

    test('空chatHistory → fromJson不报错', () {
      final engine = StudyEngine();
      final json = engine.toJson();
      final restored = StudyEngine.fromJson(json);
      expect(restored.chatHistory, isEmpty);
    });

    test('studyMode 和 currentSubject 序列化', () {
      final engine = StudyEngine();
      engine.studyMode = '挑战';
      engine.currentSubject = '物理';

      final restored = StudyEngine.fromJson(engine.toJson());
      expect(restored.studyMode, '挑战');
      expect(restored.currentSubject, '物理');
    });
  });

  // ═══════════════════════════════════════════════════
  // ReviewScheduler 遗忘曲线调度测试
  // ═══════════════════════════════════════════════════
  group('ReviewScheduler', () {
    test('答对 → intervalIndex 推进, nextReviewAt 设为未来', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      ReviewScheduler.updateKnowledgePoint(kp, true);
      expect(kp.intervalIndex, 1);
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(kp.nextReviewAt, greaterThan(now)); // 未来时间
    });

    test('答错 → intervalIndex 不推进(或回退)', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      // 初始 intervalIndex = 0, 答错不会变成负数
      ReviewScheduler.updateKnowledgePoint(kp, false);
      expect(kp.intervalIndex, 0);
    });

    test('连续答对多次 → intervalIndex 逐步推进', () {
      final kp = KnowledgePoint(name: '测试', type: 'memory');
      ReviewScheduler.updateKnowledgePoint(kp, true);
      expect(kp.intervalIndex, 1);
      ReviewScheduler.updateKnowledgePoint(kp, true);
      expect(kp.intervalIndex, 2);
      ReviewScheduler.updateKnowledgePoint(kp, true);
      expect(kp.intervalIndex, 3);
    });

    test('未安排复习的知识点 → getDueReviews 不返回', () {
      final engine = StudyEngine();
      final kp = engine.getOrCreateKnowledgePoint('数学', '极限', type: 'memory');
      kp.nextReviewAt = 0; // 从未安排
      final due = ReviewScheduler.getDueReviews(engine);
      expect(due, isEmpty);
    });

    test('已到期 → getDueReviews 返回', () {
      final engine = StudyEngine();
      final kp = engine.getOrCreateKnowledgePoint('数学', '极限', type: 'memory');
      // 设为过去的时间戳
      kp.nextReviewAt = DateTime.now()
          .subtract(const Duration(days: 2))
          .millisecondsSinceEpoch ~/ 1000;
      final due = ReviewScheduler.getDueReviews(engine);
      expect(due.length, 1);
      expect(due[0].subject, '数学');
      expect(due[0].knowledgePoint.name, '极限');
      expect(due[0].isUrgent, false); // 过期2天 < 3天阈值,不算紧急
      expect(due[0].overdueDays, 2);
    });

    test('未到期 → getDueReviews 不返回', () {
      final engine = StudyEngine();
      final kp = engine.getOrCreateKnowledgePoint('数学', '极限', type: 'memory');
      // 设为未来的时间戳
      kp.nextReviewAt = DateTime.now()
          .add(const Duration(days: 5))
          .millisecondsSinceEpoch ~/ 1000;
      final due = ReviewScheduler.getDueReviews(engine);
      expect(due, isEmpty);
    });

    test('getDueCount 返回正确数量', () {
      final engine = StudyEngine();
      final kp1 = engine.getOrCreateKnowledgePoint('数学', '极限', type: 'memory');
      final kp2 = engine.getOrCreateKnowledgePoint('物理', '力学', type: 'memory');
      final past = DateTime.now()
          .subtract(const Duration(days: 1))
          .millisecondsSinceEpoch ~/ 1000;
      kp1.nextReviewAt = past;
      kp2.nextReviewAt = past;
      expect(ReviewScheduler.getDueCount(engine), 2);
    });
  });

  // ═══════════════════════════════════════════════════
  // SubjectData 测试
  // ═══════════════════════════════════════════════════
  group('SubjectData', () {
    test('正确率计算', () {
      final sub = SubjectData(q: 10, ok: 7);
      expect(sub.accuracy, 70);
    });

    test('零题时正确率为0', () {
      final sub = SubjectData();
      expect(sub.accuracy, 0);
    });

    test('toJson/fromJson 往返', () {
      final sub = SubjectData(q: 5, ok: 3);
      sub.knowledgePoints.add(KnowledgePoint(name: '测试', type: 'memory'));
      final restored = SubjectData.fromJson(sub.toJson());
      expect(restored.q, 5);
      expect(restored.ok, 3);
      expect(restored.knowledgePoints.length, 1);
      expect(restored.knowledgePoints[0].name, '测试');
    });
  });

  // ═══════════════════════════════════════════════════
  // DailyRecord 测试
  // ═══════════════════════════════════════════════════
  group('DailyRecord', () {
    test('正确率计算', () {
      final rec = DailyRecord(date: '2026-09-07', questions: 10, correct: 8);
      expect(rec.accuracy, 80);
    });

    test('零题时正确率为0', () {
      final rec = DailyRecord(date: '2026-09-07');
      expect(rec.accuracy, 0);
    });
  });

  // ═══════════════════════════════════════════════════
  // Bookmark 测试
  // ═══════════════════════════════════════════════════
  group('Bookmark', () {
    test('toJson/fromJson 往返', () {
      final b = Bookmark(
        subject: '数学',
        title: '极限的概念',
        content: '极限是...',
        time: '2026-09-07T10:00:00',
      );
      final restored = Bookmark.fromJson(b.toJson());
      expect(restored.subject, '数学');
      expect(restored.title, '极限的概念');
      expect(restored.content, '极限是...');
      expect(restored.time, '2026-09-07T10:00:00');
    });
  });

  // ═══════════════════════════════════════════════════
  // HistoryItem 测试
  // ═══════════════════════════════════════════════════
  group('HistoryItem', () {
    test('toJson/fromJson 往返', () {
      final h = HistoryItem(
        subject: '物理',
        score: 85,
        xpGain: 10,
        time: '2026-09-07T10:00:00',
      );
      final restored = HistoryItem.fromJson(h.toJson());
      expect(restored.subject, '物理');
      expect(restored.score, 85);
      expect(restored.xpGain, 10);
    });
  });
}
