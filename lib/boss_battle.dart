/// Boss 战系统 - 限时多阶段策略性答题
///
/// 核心设计:
/// - Boss 有血量（HP），答对扣血，答错自己扣血
/// - 限时机制：倒计时增加紧张感
/// - 连击（Combo）：连续答对增加伤害倍率
/// - 多阶段：Boss 分阶段释放不同难度题目
/// - 与现有 LearnScreen 的 isBossMode 集成
///
/// 战斗流程:
/// 1. 开始战斗 → Boss 出现，显示 HP 条 + 倒计时
/// 2. Boss 出题 → 用户作答 → AI 评分
/// 3. 答对：Combo+1，伤害 = 基础分 × Combo 倍率
/// 4. 答错：Combo 归零，Boss 反击扣用户 HP
/// 5. Boss HP 归零 → 胜利；用户 HP 归零/超时 → 失败
class BossBattle {
  /// Boss 最大血量
  final int bossMaxHp;

  /// 用户最大血量
  final int playerMaxHp;

  /// 限时（秒），0 表示不限时
  final int timeLimitSeconds;

  /// 阶段数（每个阶段 Boss 出不同难度的题）
  final int phases;

  BossBattle({
    this.bossMaxHp = 100,
    this.playerMaxHp = 50,
    this.timeLimitSeconds = 300,
    this.phases = 3,
  });

  /// 开始一场战斗，返回初始状态
  BossBattleState start() {
    return BossBattleState(
      battle: this,
      bossHp: bossMaxHp,
      playerHp: playerMaxHp,
      currentPhase: 1,
      combo: 0,
      maxCombo: 0,
      questionsAnswered: 0,
      correctAnswers: 0,
      startTime: DateTime.now(),
      status: BossBattleStatus.ongoing,
      log: [],
    );
  }
}

/// Boss 战状态
class BossBattleState {
  final BossBattle battle;
  int bossHp;
  int playerHp;
  int currentPhase;
  int combo;
  int maxCombo;
  int questionsAnswered;
  int correctAnswers;
  DateTime startTime;
  BossBattleStatus status;
  List<String> log;

  BossBattleState({
    required this.battle,
    required this.bossHp,
    required this.playerHp,
    required this.currentPhase,
    required this.combo,
    required this.maxCombo,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.startTime,
    required this.status,
    required this.log,
  });

  /// Boss 血量百分比
  double get bossHpPercent => bossHp / battle.bossMaxHp;

  /// 用户血量百分比
  double get playerHpPercent => playerHp / battle.playerMaxHp;

  /// 剩余时间（秒）
  int get remainingSeconds {
    if (battle.timeLimitSeconds == 0) return 0;
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final remaining = battle.timeLimitSeconds - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /// 是否超时
  bool get isTimeUp =>
      battle.timeLimitSeconds > 0 && remainingSeconds <= 0;

  /// 当前阶段难度描述
  String get phaseDescription {
    switch (currentPhase) {
      case 1:
        return '第一阶段：试探（基础概念题）';
      case 2:
        return '第二阶段：激战（应用计算题）';
      case 3:
        return '最终阶段：决战（综合应用题）';
      default:
        return '第$currentPhase阶段';
    }
  }

  /// 处理答题结果
  ///
  /// [score] 0-120 (Boss 评分)
  /// 返回伤害信息和战斗日志
  BossAttackResult processAnswer(int score) {
    if (status != BossBattleStatus.ongoing) {
      return BossAttackResult(
        damage: 0,
        counterDamage: 0,
        newCombo: combo,
        log: '战斗已结束',
        isDefeated: false,
        isVictory: false,
      );
    }

    questionsAnswered++;
    final isCorrect = score >= 60;
    final normalizedScore = (score / 100.0).clamp(0.0, 1.2);

    int damage = 0;
    int counterDamage = 0;
    final logParts = <String>[];

    if (isCorrect) {
      correctAnswers++;
      combo++;
      if (combo > maxCombo) maxCombo = combo;

      // 伤害 = 基础伤害 × 分数倍率 × Combo 倍率
      final baseDamage = 15 + (normalizedScore * 15).round();
      final comboMultiplier = 1.0 + (combo - 1) * 0.2; // 每连击 +20%
      damage = (baseDamage * comboMultiplier).round();

      bossHp -= damage;
      logParts.add('✅ 答对！Combo x$combo → 造成 $damage 伤害');

      // 检查是否进入下一阶段
      final phaseThreshold = battle.bossMaxHp -
          (battle.bossMaxHp * currentPhase / battle.phases);
      if (bossHp <= phaseThreshold && currentPhase < battle.phases) {
        currentPhase++;
        logParts.add('⚡ Boss 进入第$currentPhase阶段！题目难度提升！');
      }
    } else {
      combo = 0;
      // Boss 反击：分数越低扣越多
      counterDamage = 10 + ((1 - score / 60) * 10).round();
      counterDamage = counterDamage.clamp(5, 20);
      playerHp -= counterDamage;
      logParts.add('❌ 答错！Combo 归零 → Boss 反击造成 $counterDamage 伤害');
    }

    // 检查战斗结束
    bool isVictory = false;
    bool isDefeated = false;

    if (bossHp <= 0) {
      bossHp = 0;
      status = BossBattleStatus.victory;
      isVictory = true;
      logParts.add('🏆 Boss 已击败！战斗胜利！');
    } else if (playerHp <= 0) {
      playerHp = 0;
      status = BossBattleStatus.defeat;
      isDefeated = true;
      logParts.add('💀 你的血量耗尽，挑战失败...');
    } else if (isTimeUp) {
      status = BossBattleStatus.timeout;
      isDefeated = true;
      logParts.add('⏰ 时间到！挑战失败...');
    }

    log.addAll(logParts);

    return BossAttackResult(
      damage: damage,
      counterDamage: counterDamage,
      newCombo: combo,
      log: logParts.join('\n'),
      isDefeated: isDefeated,
      isVictory: isVictory,
    );
  }

  /// 战斗统计
  Map<String, dynamic> get stats {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    return {
      'bossMaxHp': battle.bossMaxHp,
      'bossRemainHp': bossHp,
      'playerMaxHp': battle.playerMaxHp,
      'playerRemainHp': playerHp,
      'combo': combo,
      'maxCombo': maxCombo,
      'questionsAnswered': questionsAnswered,
      'correctAnswers': correctAnswers,
      'accuracy': questionsAnswered > 0
          ? (correctAnswers * 100 / questionsAnswered).round()
          : 0,
      'elapsedSeconds': elapsed,
      'phase': currentPhase,
      'status': status.name,
    };
  }

  Map<String, dynamic> toJson() => {
    'bossHp': bossHp,
    'playerHp': playerHp,
    'currentPhase': currentPhase,
    'combo': combo,
    'maxCombo': maxCombo,
    'questionsAnswered': questionsAnswered,
    'correctAnswers': correctAnswers,
    'startTime': startTime.toIso8601String(),
    'status': status.index,
    'log': log,
  };
}

/// Boss 战状态
enum BossBattleStatus {
  ongoing,  // 进行中
  victory,  // 胜利
  defeat,   // 失败（血量耗尽）
  timeout,  // 超时失败
}

/// 答题处理结果
class BossAttackResult {
  final int damage;         // 对 Boss 造成的伤害
  final int counterDamage;  // Boss 反击的伤害
  final int newCombo;       // 当前连击数
  final String log;          // 战斗日志
  final bool isDefeated;    // 是否失败
  final bool isVictory;      // 是否胜利

  BossAttackResult({
    required this.damage,
    required this.counterDamage,
    required this.newCombo,
    required this.log,
    required this.isDefeated,
    required this.isVictory,
  });
}
