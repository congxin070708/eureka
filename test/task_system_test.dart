import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:eureka/task_system.dart';

/// ──────────────────────────────────────────────────────────────────────────
/// 任务系统 + 抽奖系统 + 保底机制 测试
///
/// 【源码保底常量对照表】（见 [GachaSystem]）
///   softPityEpic   = 50  // 软保底：超过 50 抽不出史诗+，开始按 1+0.15*(抽数-50) 提升史诗+权重
///   hardPityEpic   = 70  // 硬保底：pityEpic >= 70 时，_poolWithPity 只保留史诗+传说，必出史诗+
///   softPityLegend = 70  // 软保底：超过 70 抽不出传说，开始按 1+0.10*(抽数-70) 提升传说权重
///   hardPityLegend = 100 // 硬保底：pityLegend >= 100 时，_poolWithPity 只保留传说，必出传说
///
/// 注意：源码中「软保底」只提升概率、并不强制掉落；真正「必出」的是硬保底阈值。
/// 因此场景 1「连续抽 N 次不出史诗，第 N+1 次必出史诗」的「必出」行为对应 hardPityEpic(70)；
/// 场景 2「必出传说」对应 hardPityLegend(100)。另外在场景 1 下补充一个软保底概率提升的测试。
///
/// pity 计数语义：pityEpic = 距离上次出史诗+的抽数，pityLegend = 距离上次出传说的抽数。
/// ──────────────────────────────────────────────────────────────────────────

void main() {
  // ════════════════════════════════════════════════════════════════════════
  // 抽奖保底机制
  // ════════════════════════════════════════════════════════════════════════
  group('抽奖保底机制', () {
    // ────────────────────────────────────────────────────────────────────────
    // 场景 1：软保底（史诗）
    // ────────────────────────────────────────────────────────────────────────
    group('1. 软保底（史诗）', () {
      // 1-A 软保底概率提升：pityEpic 超过 softPityEpic 后，史诗+掉率应显著高于基础率
      test('软保底：pityEpic 超过 softPityEpic 后史诗+掉率显著提升', () {
        // 基础池总权重 100，其中史诗+(unlock_key=epic 权重5 + title_master=legendary 权重1)=6，
        // 基础史诗+掉率约 6%。取 pityEpic = softPityEpic + 19 = 69（硬保底 70 的前一抽），
        // 此时 boost = 1 + (69-50)*0.15 = 3.85，史诗+权重升到约 23，掉率约 20%。
        const samples = 4000;
        var baseEpicPlus = 0;
        var boostedEpicPlus = 0;

        for (var seed = 0; seed < samples; seed++) {
          // 基础情况（无保底加成）
          final r0 = GachaSystem.drawOne(Random(seed), <String>{}, pityEpic: 0);
          if (r0.item.rarity == ItemRarity.epic ||
              r0.item.rarity == ItemRarity.legendary) {
            baseEpicPlus++;
          }

          // 软保底加成情况
          final rBoosted = GachaSystem.drawOne(
            Random(seed),
            <String>{},
            pityEpic: GachaSystem.softPityEpic + 19, // 69 抽，未达硬保底
          );
          if (rBoosted.item.rarity == ItemRarity.epic ||
              rBoosted.item.rarity == ItemRarity.legendary) {
            boostedEpicPlus++;
          }
        }

        // 软保底后史诗+数量应远多于基础（约 3 倍），证明软保底确实提升了概率
        expect(
          boostedEpicPlus,
          greaterThan(baseEpicPlus * 2),
          reason: '软保底应显著提升史诗+掉率',
        );
      });

      // 1-B 连续 N 抽不出史诗，第 N+1 抽必出史诗（对应源码 hardPityEpic）
      test('连续 N 抽不出史诗后第 N+1 抽必出史诗+（N = hardPityEpic）', () {
        // pityEpic 表示已连续 N 抽未出史诗+。当 pityEpic 达到 hardPityEpic(70) 时，
        // _poolWithPity 只保留史诗与传说，因此这一次（第 N+1 次）抽取必然命中史诗+。
        const n = GachaSystem.hardPityEpic; // 70

        // 遍历大量种子，验证「达到阈值后必出史诗+」对所有随机结果都成立
        for (var seed = 0; seed < 200; seed++) {
          final result = GachaSystem.drawOne(
            Random(seed),
            <String>{},
            pityEpic: n,
          );
          final isEpicPlus = result.item.rarity == ItemRarity.epic ||
              result.item.rarity == ItemRarity.legendary;
          expect(
            isEpicPlus,
            isTrue,
            reason: 'pityEpic=$n（硬保底）时必须出史诗或传说，seed=$seed',
          );
          // 触发保底命中标记应被置真
          expect(result.isPityHit, isTrue, reason: '硬保底命中应标记 isPityHit');
        }

        // 边界：未达阈值（n-1）时并不保证必出史诗+，仍可能不出
        var hasNonEpicPlus = false;
        for (var seed = 0; seed < 200; seed++) {
          final result = GachaSystem.drawOne(
            Random(seed),
            <String>{},
            pityEpic: n - 1,
          );
          if (result.item.rarity != ItemRarity.epic &&
              result.item.rarity != ItemRarity.legendary) {
            hasNonEpicPlus = true;
          }
        }
        expect(
          hasNonEpicPlus,
          isTrue,
          reason: 'pityEpic=${n - 1}（未达硬保底）时仍允许不出史诗+',
        );
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    // 场景 2：硬保底（传说）
    // ────────────────────────────────────────────────────────────────────────
    group('2. 硬保底（传说）', () {
      test('连续 M 抽不出传说后第 M+1 抽必出传说（M = hardPityLegend）', () {
        // pityLegend 达到 hardPityLegend(100) 时，_poolWithPity 只保留传说（title_master），
        // 因此这一次抽取必然命中传说。
        const m = GachaSystem.hardPityLegend; // 100

        for (var seed = 0; seed < 200; seed++) {
          final result = GachaSystem.drawOne(
            Random(seed),
            <String>{},
            pityLegend: m,
          );
          expect(
            result.item.rarity,
            ItemRarity.legendary,
            reason: 'pityLegend=$m（硬保底）时必须出传说，seed=$seed',
          );
          expect(result.isPityHit, isTrue, reason: '硬保底命中应标记 isPityHit');
        }

        // 边界：未达阈值（m-1）时不保证必出传说，仍可能不出
        var hasNonLegendary = false;
        for (var seed = 0; seed < 200; seed++) {
          final result = GachaSystem.drawOne(
            Random(seed),
            <String>{},
            pityLegend: m - 1,
          );
          if (result.item.rarity != ItemRarity.legendary) {
            hasNonLegendary = true;
          }
        }
        expect(
          hasNonLegendary,
          isTrue,
          reason: 'pityLegend=${m - 1}（未达硬保底）时仍允许不出传说',
        );
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    // 场景 3：出了史诗后，保底计数器重置
    // ────────────────────────────────────────────────────────────────────────
    group('3. 出史诗后保底计数器重置', () {
      test('drawMany 内出史诗+后 pityEpic 归零并重新累积', () {
        // drawMany 内部按以下规则维护保底计数：
        //   传说 -> pityEpic=0, pityLegend=0
        //   史诗 -> pityEpic=0, pityLegend++
        //   其他 -> pityEpic++,  pityLegend++
        // 若「出史诗+后计数器重置」逻辑正确，则两次史诗+之间最多相隔 hardPityEpic 抽
        // （因为再次累积到 hardPityEpic 时硬保底必出史诗+）。
        final results = GachaSystem.drawMany(
          1000,
          <String>{},
          pityEpic: 0,
          pityLegend: 0,
        );

        // 收集所有「史诗+」结果的下标
        final epicPlusIndices = <int>[];
        for (var i = 0; i < results.length; i++) {
          final r = results[i].item.rarity;
          if (r == ItemRarity.epic || r == ItemRarity.legendary) {
            epicPlusIndices.add(i);
          }
        }

        // 应当出现多次史诗+（证明计数器在掉落后重置、并再次累积到保底）
        expect(
          epicPlusIndices.length,
          greaterThan(1),
          reason: '1000 抽内应出现多次史诗+以验证重置逻辑',
        );

        // 首次史诗+应在前 hardPityEpic+1 抽内出现
        expect(
          epicPlusIndices.first,
          lessThanOrEqualTo(GachaSystem.hardPityEpic),
          reason: '从 0 开始累积，首次史诗+最迟在第 hardPityEpic+1 抽（下标 hardPityEpic）',
        );

        // 相邻两次史诗+之间的非史诗+抽数不得超过 hardPityEpic
        for (var k = 1; k < epicPlusIndices.length; k++) {
          final gap = epicPlusIndices[k] - epicPlusIndices[k - 1] - 1;
          expect(
            gap,
            lessThanOrEqualTo(GachaSystem.hardPityEpic),
            reason:
                '出史诗+后计数器重置，下一次史诗+最多间隔 hardPityEpic 抽；'
                '实际间隔 $gap',
          );
        }
      });

      test('drawMany 内出传说后 pityLegend 归零并重新累积', () {
        // 同理，传说硬保底保证两次传说之间最多相隔 hardPityLegend 抽。
        final results = GachaSystem.drawMany(
          2000,
          <String>{},
          pityEpic: 0,
          pityLegend: 0,
        );

        final legendaryIndices = <int>[];
        for (var i = 0; i < results.length; i++) {
          if (results[i].item.rarity == ItemRarity.legendary) {
            legendaryIndices.add(i);
          }
        }

        expect(
          legendaryIndices.length,
          greaterThan(1),
          reason: '2000 抽内应出现多次传说以验证重置逻辑',
        );
        expect(
          legendaryIndices.first,
          lessThanOrEqualTo(GachaSystem.hardPityLegend),
          reason: '首次传说最迟在第 hardPityLegend+1 抽出现',
        );
        for (var k = 1; k < legendaryIndices.length; k++) {
          final gap = legendaryIndices[k] - legendaryIndices[k - 1] - 1;
          expect(
            gap,
            lessThanOrEqualTo(GachaSystem.hardPityLegend),
            reason:
                '出传说后计数器重置，下一次传说最多间隔 hardPityLegend 抽；'
                '实际间隔 $gap',
          );
        }
      });
    });
  });

  // ════════════════════════════════════════════════════════════════════════
  // 任务系统
  // ════════════════════════════════════════════════════════════════════════
  group('任务系统', () {
    // ────────────────────────────────────────────────────────────────────────
    // 场景 4：每日任务刷新逻辑
    // ────────────────────────────────────────────────────────────────────────
    group('4. 每日任务刷新逻辑', () {
      test('跨天后日常任务进度清零、状态回到 active，主线任务保留', () {
        final mgr = TaskManager();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        // 预置为今天，避免首次操作触发意外的对象替换
        mgr.lastDailyReset = today;

        // 日常任务累计进度：daily_answer3 目标 3 题
        mgr.recordAnswer(true);
        mgr.recordAnswer(true);
        expect(mgr.getProgress('daily_answer3').progress, 2);

        // 主线任务累计进度：main_first_skill 目标 1 个技能
        mgr.recordMasteredSkill(1);
        expect(mgr.getProgress('main_first_skill').progress, 1);

        // 模拟「跨天」：把上次刷新时间改成过去某天
        mgr.lastDailyReset = '2020-01-01';
        // 访问 dailyTasks 会触发 _checkDailyReset
        mgr.dailyTasks;

        // 日常任务应被重置：进度归零、状态回到 active
        final resetDaily = mgr.getProgress('daily_answer3');
        expect(resetDaily.progress, 0);
        expect(resetDaily.status, TaskStatus.active);
        // 主线任务不受每日刷新影响，进度保留
        expect(mgr.getProgress('main_first_skill').progress, 1);
        // lastDailyReset 已被更新为今天
        expect(mgr.lastDailyReset, today);
      });

      test('同一天内重复访问不会重置日常任务进度', () {
        final mgr = TaskManager();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        mgr.lastDailyReset = today;

        mgr.recordAnswer(true);
        expect(mgr.getProgress('daily_answer3').progress, 1);

        // 再次访问 dailyTasks（同一天），不应触发重置
        mgr.dailyTasks;
        expect(mgr.getProgress('daily_answer3').progress, 1);

        // 继续累计，进度应在原基础上增长
        mgr.recordAnswer(true);
        expect(mgr.getProgress('daily_answer3').progress, 2);
      });
    });

    // ────────────────────────────────────────────────────────────────────────
    // 场景 5：任务完成奖励发放
    // ────────────────────────────────────────────────────────────────────────
    group('5. 任务完成奖励发放', () {
      test('未完成任务领取奖励返回空', () {
        final mgr = TaskManager();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        mgr.lastDailyReset = today;

        // daily_answer3 尚未完成（进度 0），领取应返回空列表
        expect(mgr.claimTask('daily_answer3'), isEmpty);
        // 状态仍为 active
        expect(
          mgr.getProgress('daily_answer3').status,
          TaskStatus.active,
        );
      });

      test('完成后领取奖励内容与数量正确，且状态变为 claimed', () {
        final mgr = TaskManager();
        final today = DateTime.now().toIso8601String().substring(0, 10);
        mgr.lastDailyReset = today;

        final p = mgr.getProgress('daily_answer3'); // 目标 3 题

        // 累计进度直到完成
        mgr.recordAnswer(true);
        expect(p.status, TaskStatus.active); // 进度 1，未完成
        mgr.recordAnswer(true);
        expect(p.status, TaskStatus.active); // 进度 2，未完成
        mgr.recordAnswer(true);
        expect(p.status, TaskStatus.completed); // 进度 3，完成
        expect(p.progress, 3);

        // 领取奖励：daily_answer3 的 rewards = {'exp_card_s': 1, 'hint_card': 2}
        final rewards = mgr.claimTask('daily_answer3');
        expect(rewards.length, 2);

        // 校验奖励道具与数量
        final expCard = rewards.firstWhere((r) => r.itemId == 'exp_card_s');
        expect(expCard.count, 1);
        expect(expCard.def.rarity, ItemRarity.common);

        final hintCard = rewards.firstWhere((r) => r.itemId == 'hint_card');
        expect(hintCard.count, 2);

        // 领取后状态变为已领取
        expect(p.status, TaskStatus.claimed);

        // 重复领取应返回空（已领取）
        expect(mgr.claimTask('daily_answer3'), isEmpty);
      });

      test('主线任务完成后同样可领取奖励（验证通用性）', () {
        final mgr = TaskManager();
        // 主线任务不随每日刷新，可直接操作
        mgr.recordBossCleared(); // main_first_boss 目标 1

        final p = mgr.getProgress('main_first_boss');
        expect(p.status, TaskStatus.completed);

        // main_first_boss 的 rewards = {'unlock_key': 1, 'gacha_ticket': 2}
        final rewards = mgr.claimTask('main_first_boss');
        expect(rewards.length, 2);

        final unlockKey = rewards.firstWhere((r) => r.itemId == 'unlock_key');
        expect(unlockKey.count, 1);
        expect(unlockKey.def.rarity, ItemRarity.epic);

        final ticket = rewards.firstWhere((r) => r.itemId == 'gacha_ticket');
        expect(ticket.count, 2);

        expect(p.status, TaskStatus.claimed);
        // 主线任务领取后不再出现在 mainTasks 列表中
        expect(mgr.mainTasks.any((t) => t.taskId == 'main_first_boss'), isFalse);
      });
    });
  });
}
