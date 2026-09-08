import 'package:flutter_test/flutter_test.dart';
import 'package:eureka/study_engine.dart';
import 'package:eureka/review_scheduler.dart';

/// SM-2 间隔重复算法测试
///
/// 本项目的 [ReviewScheduler] 是 SM-2 的「简化版」实现，与教科书原版有差异：
/// - 用布尔值 `correct`（true=回忆成功 / false=回忆失败）代替原版 0..5 的 quality 评分；
/// - 用一张固定间隔表 `[1, 3, 7, 14, 30, 60]`（天）配合 `intervalIndex` 推进/回退，
///   而不使用连续的 ease factor。
///
/// 因此下面把原版 SM-2 概念按如下方式映射到本实现：
///   quality >= 3（及格回忆）   =>  correct = true
///   quality <  3（不及格回忆） =>  correct = false
///   ease factor 的「升 / 降」  =>  intervalIndex 的「推进 / 回退」
///   下次间隔                   =>  由 intervalIndex 查间隔表得到的天数

/// 间隔表镜像（对应 review_scheduler.dart 中的私有 _intervals）。
const kIntervals = [1, 3, 7, 14, 30, 60];

/// 计算知识点距离下次复习的秒数（用于近似验证 nextReviewAt 是否被正确安排）。
int secondsUntilReview(KnowledgePoint kp) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return kp.nextReviewAt - now;
}

/// 断言下次复习间隔约等于给定天数。
/// 允许 120 秒误差，用来吸收「函数内部捕获 now」与「测试捕获 now」之间的时差。
void expectIntervalDays(KnowledgePoint kp, int expectedDays) {
  expect(kp.nextReviewAt, greaterThan(0)); // 必须已被调度（非 0）
  expect(secondsUntilReview(kp), closeTo(expectedDays * 86400, 120));
}

void main() {
  group('SM-2 间隔重复算法', () {
    // ─────────────────────────────────────────────────────────────
    // 场景 1：首次复习（quality=4）后，下次间隔应该增加
    // ─────────────────────────────────────────────────────────────
    group('场景1 首次高质量复习后间隔增加', () {
      test('quality=4(答对)后 intervalIndex 从 0 推进到 1，间隔 1d→3d', () {
        final kp = KnowledgePoint(name: '光合作用', type: 'memory');

        // 复习前：从未安排过复习
        expect(kp.intervalIndex, 0);
        expect(kp.nextReviewAt, 0);

        // quality=4 => 答对，触发首次复习调度
        ReviewScheduler.updateKnowledgePoint(kp, true);

        // 间隔索引推进一格：0 -> 1
        expect(kp.intervalIndex, 1);
        // 下次复习被安排在约 3 天后（kIntervals[1] == 3）
        expectIntervalDays(kp, kIntervals[1]);
      });

      test('答对后的间隔(3d)严格大于初始间隔(1d)', () {
        final kp = KnowledgePoint(name: '细胞呼吸', type: 'memory');
        ReviewScheduler.updateKnowledgePoint(kp, true);

        // 初始间隔为 kIntervals[0]=1 天，答对后变成 3 天，间隔严格增大
        expect(kIntervals[kp.intervalIndex], greaterThan(kIntervals[0]));
      });
    });

    // ─────────────────────────────────────────────────────────────
    // 场景 2：连续多次高质量回忆（quality>=4）后，间隔应递增
    // ─────────────────────────────────────────────────────────────
    group('场景2 连续高质量回忆间隔递增', () {
      test('连续答对 5 次，间隔依次 1→3→7→14→30→60 递增', () {
        final kp = KnowledgePoint(name: '牛顿第二定律', type: 'memory');
        final seenIntervals = <int>[];

        // 起始间隔 1 天（索引 0 对应的间隔）
        seenIntervals.add(kIntervals[kp.intervalIndex]);
        for (int i = 0; i < 5; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true); // quality>=4 => 答对
          seenIntervals.add(kIntervals[kp.intervalIndex]);
          expectIntervalDays(kp, kIntervals[kp.intervalIndex]);
        }

        // 间隔序列应严格递增：1, 3, 7, 14, 30, 60
        expect(seenIntervals, [1, 3, 7, 14, 30, 60]);
        // 索引同步递增到 5
        expect(kp.intervalIndex, 5);
      });

      test('到达表顶(60d)后再答对，间隔封顶不再增长', () {
        final kp = KnowledgePoint(name: '熵增定律', type: 'memory');
        // 先连续答对 6 次，推进到表顶
        for (int i = 0; i < 6; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, kIntervals.length - 1); // 已到最大索引 5
        expect(kIntervals[kp.intervalIndex], 60);

        // 再答对一次：索引不应越界，仍封顶在 60 天
        ReviewScheduler.updateKnowledgePoint(kp, true);
        expect(kp.intervalIndex, kIntervals.length - 1);
        expectIntervalDays(kp, 60);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // 场景 3：低质量回忆（quality<=2）后，间隔应重置为 1 天
    // ─────────────────────────────────────────────────────────────
    // 注意：本简化版实现「答错只回退一格」而非「立即重置到 1 天」。
    // 因此分两步验证其真实行为：
    //   (a) 单次答错：间隔回退一格（非完全重置）；
    //   (b) 连续答错：最终会一路落到最小间隔 1 天（即索引 0）。
    group('场景3 低质量回忆后间隔回退/重置', () {
      test('单次答错(quality<=2)：间隔回退一格(非直接重置到1天)', () {
        final kp = KnowledgePoint(name: '热力学第一定律', type: 'memory');
        // 先答对 4 次，推进到索引 4（30 天）
        for (int i = 0; i < 4; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 4);

        // quality<=2 => 答错，间隔回退一格：4 -> 3（14 天），而非直接到 1 天
        ReviewScheduler.updateKnowledgePoint(kp, false);
        expect(kp.intervalIndex, 3);
        expectIntervalDays(kp, kIntervals[3]); // 14 天
        expect(kIntervals[kp.intervalIndex], lessThan(kIntervals[4]));
      });

      test('连续答错会一路回退到最小间隔 1 天', () {
        final kp = KnowledgePoint(name: '热力学第二定律', type: 'memory');
        // 先推进到索引 4（30 天）
        for (int i = 0; i < 4; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 4);

        // 连续答错 4 次：4 -> 3 -> 2 -> 1 -> 0
        for (int i = 0; i < 4; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, false);
        }
        expect(kp.intervalIndex, 0);
        expectIntervalDays(kp, 1); // 已回到最小间隔 1 天
      });

      test('已在最小间隔时答错，保持在 1 天(不会越界为负)', () {
        final kp = KnowledgePoint(name: '玻尔兹曼分布', type: 'memory');
        // 索引 0 时答错：不应越界
        ReviewScheduler.updateKnowledgePoint(kp, false);
        expect(kp.intervalIndex, 0);
        expectIntervalDays(kp, 1);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // 场景 4：ease factor 应在 quality>=3 时保持或增加，quality<3 时减少
    // ─────────────────────────────────────────────────────────────
    // 说明：本实现没有连续 ease factor，由 intervalIndex 承担其角色：
    //   - quality>=3(答对)：intervalIndex 不会减少（保持或增加）；
    //   - quality< 3(答错)：intervalIndex 不会增加（保持或减少）。
    group('场景4 间隔索引(ease factor 等价)的升/降', () {
      test('答对(quality>=3)时 intervalIndex 保持或增加，绝不回退', () {
        final kp = KnowledgePoint(name: '动量守恒', type: 'memory');
        // 先推进到索引 3
        for (int i = 0; i < 3; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 3);

        // 中间位置答对：3 -> 4（增加）
        ReviewScheduler.updateKnowledgePoint(kp, true);
        expect(kp.intervalIndex, greaterThan(3));

        // 表顶继续答对：保持不变（封顶，不回退）
        for (int i = 0; i < 10; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, kIntervals.length - 1); // 保持
      });

      test('答错(quality<3)时 intervalIndex 保持或减少，绝不推进', () {
        final kp = KnowledgePoint(name: '角动量守恒', type: 'memory');
        // 先推进到索引 3
        for (int i = 0; i < 3; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 3);

        // 答错：3 -> 2（减少）
        ReviewScheduler.updateKnowledgePoint(kp, false);
        expect(kp.intervalIndex, lessThan(3));

        // 一路答错到底：保持最小（不再减少）
        for (int i = 0; i < 10; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, false);
        }
        expect(kp.intervalIndex, 0); // 保持最小
      });

      test('答错(quality<3)会重置 consecutiveCorrect 计数', () {
        final kp = KnowledgePoint(name: '能量守恒', type: 'memory');
        kp.consecutiveCorrect = 5;
        ReviewScheduler.updateKnowledgePoint(kp, false);
        expect(kp.consecutiveCorrect, 0);
      });

      test('答对(quality>=3)会重置 consecutiveWrong 计数', () {
        final kp = KnowledgePoint(name: '质量守恒', type: 'memory');
        kp.consecutiveWrong = 5;
        ReviewScheduler.updateKnowledgePoint(kp, true);
        expect(kp.consecutiveWrong, 0);
      });
    });

    // ─────────────────────────────────────────────────────────────
    // 场景 5：边界情况 quality=0 和 quality=5
    // ─────────────────────────────────────────────────────────────
    group('场景5 边界情况 quality=0 与 quality=5', () {
      test('quality=0(最差)：视为答错，间隔回退一格', () {
        final kp = KnowledgePoint(name: '量子叠加', type: 'memory');
        // 先推进到索引 3（14 天）
        for (int i = 0; i < 3; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 3);

        // quality=0 => 答错，回退一格：3 -> 2（7 天）
        ReviewScheduler.updateKnowledgePoint(kp, false);
        expect(kp.intervalIndex, 2);
        expectIntervalDays(kp, kIntervals[2]);
      });

      test('quality=0 在最小间隔时仍保持 1 天(不越界)', () {
        final kp = KnowledgePoint(name: '量子纠缠', type: 'memory');
        ReviewScheduler.updateKnowledgePoint(kp, false); // quality=0，索引 0
        expect(kp.intervalIndex, 0);
        expectIntervalDays(kp, 1);
      });

      test('quality=5(最好)：视为答对，间隔推进一格', () {
        final kp = KnowledgePoint(name: '测不准原理', type: 'memory');
        // 先推进到索引 3（14 天）
        for (int i = 0; i < 3; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, 3);

        // quality=5 => 答对，推进一格：3 -> 4（30 天）
        ReviewScheduler.updateKnowledgePoint(kp, true);
        expect(kp.intervalIndex, 4);
        expectIntervalDays(kp, kIntervals[4]);
      });

      test('quality=5 在最大间隔时仍封顶 60 天(不越界)', () {
        final kp = KnowledgePoint(name: '泡利不相容', type: 'memory');
        // 先推到表顶
        for (int i = 0; i < 6; i++) {
          ReviewScheduler.updateKnowledgePoint(kp, true);
        }
        expect(kp.intervalIndex, kIntervals.length - 1);

        // quality=5 再答对：不越界，保持 60 天
        ReviewScheduler.updateKnowledgePoint(kp, true);
        expect(kp.intervalIndex, kIntervals.length - 1);
        expectIntervalDays(kp, 60);
      });
    });
  });
}
