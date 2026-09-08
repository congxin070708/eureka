import 'dart:async';
import 'dart:math';
import 'skill_tree.dart';

/// ────────────────────────────────────────────
/// Boss 战系统
///
/// 真正的战斗机制，不是贴皮动画
/// 核心玩法：限时答题 → 伤害计算 → 多阶段 Boss → 道具策略
/// ────────────────────────────────────────────

/// Boss 战状态
enum BossBattleState {
  preparing,   // 准备中（开场动画）
  fighting,    // 战斗中
  victory,     // 胜利
  defeat,      // 失败
  ended,       // 已结束（结算完成）
}

/// Boss 阶段
enum BossPhase {
  phase1,  // 第一阶段（正常）
  phase2,  // 第二阶段（狂暴，题目更难，时间更短）
  phase3,  // 第三阶段（绝境，最难）
}

/// 单道 Boss 题
class BossQuestion {
  final String id;
  final String question;
  final List<String> keyPoints;
  final String difficulty;   // easy/medium/hard/extreme
  final String questionType; // concept/application/critical/brainstorm
  final int timeLimit;       // 限时（秒）
  final int baseDamage;      // 答对基础伤害
  final String? hint;        // 提示（使用提示卡解锁）

  BossQuestion({
    required this.id,
    required this.question,
    required this.keyPoints,
    required this.difficulty,
    required this.questionType,
    required this.timeLimit,
    required this.baseDamage,
    this.hint,
  });
}

/// 答题结果
class AnswerResult {
  final int score;          // 0-100
  final String feedback;
  final int damageDealt;    // 对 Boss 造成的伤害
  final int damageTaken;    // 玩家受到的伤害
  final bool isCritical;    // 是否暴击（连击触发）
  final bool isPerfect;     // 是否完美（95+）
  final int comboCount;     // 当前连击数
  final String? bonusType;  // 额外奖励类型（多解法/新思路等）
  final int bonusDamage;    // 额外伤害

  AnswerResult({
    required this.score,
    required this.feedback,
    required this.damageDealt,
    required this.damageTaken,
    required this.comboCount,
    this.isCritical = false,
    this.isPerfect = false,
    this.bonusType,
    this.bonusDamage = 0,
  });
}

/// Boss 战结算
class BossBattleResult {
  final bool victory;
  final int totalDamageDealt;
  final int totalDamageTaken;
  final int maxCombo;
  final int questionsAnswered;
  final int correctAnswers;
  final int highestScore;
  final Duration totalTime;
  final String rank;        // S/A/B/C/D
  final List<String> rewards; // 获得的奖励
  final int expGained;
  final int coinsGained;

  BossBattleResult({
    required this.victory,
    required this.totalDamageDealt,
    required this.totalDamageTaken,
    required this.maxCombo,
    required this.questionsAnswered,
    required this.correctAnswers,
    required this.highestScore,
    required this.totalTime,
    required this.rank,
    required this.rewards,
    required this.expGained,
    required this.coinsGained,
  });
}

/// Boss 配置
class BossConfig {
  final String bossId;
  final String bossName;
  final String bossEmoji;
  final String subject;
  final String description;

  final int maxHp;          // Boss 最大血量
  final int playerMaxHp;    // 玩家最大血量

  final int totalQuestions; // 总题数
  final int baseTimeLimit;  // 基础答题时间

  // 阶段配置
  final double phase2Threshold; // 进入 P2 的血量比例
  final double phase3Threshold; // 进入 P3 的血量比例
  final double phase2DamageMultiplier; // P2 伤害倍率
  final double phase3DamageMultiplier; // P3 伤害倍率
  final double phase2TimeReduction;    // P2 时间缩减
  final double phase3TimeReduction;    // P3 时间缩减

  // 连击配置
  final int comboThreshold;      // 连击触发阈值
  final double comboMultiplier;  // 连击伤害倍率

  // 完美/暴击配置
  final int perfectScore;     // 完美分数阈值
  final double perfectBonus;  // 完美伤害加成

  const BossConfig({
    required this.bossId,
    required this.bossName,
    required this.bossEmoji,
    required this.subject,
    required this.description,
    required this.maxHp,
    required this.playerMaxHp,
    required this.totalQuestions,
    required this.baseTimeLimit,
    this.phase2Threshold = 0.66,
    this.phase3Threshold = 0.33,
    this.phase2DamageMultiplier = 1.3,
    this.phase3DamageMultiplier = 1.6,
    this.phase2TimeReduction = 0.2,
    this.phase3TimeReduction = 0.4,
    this.comboThreshold = 3,
    this.comboMultiplier = 1.5,
    this.perfectScore = 95,
    this.perfectBonus = 1.3,
  });

  /// 根据节点难度生成 Boss 配置
  factory BossConfig.fromSkillNode(SkillNode node, String subject) {
    final difficulty = node.difficulty; // 1-5
    final isFinalBoss = node.id.contains('final') || node.id.contains('boss_final');

    return BossConfig(
      bossId: node.id,
      bossName: '${node.name}守护者',
      bossEmoji: isFinalBoss ? '👹' : '🐉',
      subject: subject,
      description: node.description,
      maxHp: 500 + difficulty * 200 + (isFinalBoss ? 500 : 0),
      playerMaxHp: 100,
      totalQuestions: 5 + difficulty * 2,
      baseTimeLimit: 90 - difficulty * 10,
      phase2Threshold: 0.66,
      phase3Threshold: isFinalBoss ? 0.33 : 0.0,
      phase2DamageMultiplier: 1.2 + difficulty * 0.1,
      phase3DamageMultiplier: isFinalBoss ? 1.8 : 1.0,
      phase2TimeReduction: 0.15 + difficulty * 0.05,
      phase3TimeReduction: isFinalBoss ? 0.4 : 0.0,
    );
  }
}

/// Boss 战引擎
class BossBattleEngine {
  final BossConfig config;
  final List<BossQuestion> questions;

  // 战斗状态
  BossBattleState state = BossBattleState.preparing;
  BossPhase currentPhase = BossPhase.phase1;

  // 血量
  late int bossHp;
  late int playerHp;

  // 进度
  int currentQuestionIndex = 0;
  int combo = 0;
  int maxCombo = 0;
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;
  int correctAnswers = 0;
  int highestScore = 0;

  // 时间
  DateTime? battleStartTime;
  DateTime? questionStartTime;
  Timer? questionTimer;
  int remainingTime = 0;

  // 道具使用记录
  final Set<String> usedItems = {};
  int hintsUsed = 0;
  int skipsUsed = 0;

  // 回调
  void Function()? onStateChange;
  void Function(int remaining)? onTimerTick;
  void Function(AnswerResult)? onAnswerEvaluated;
  void Function(BossPhase)? onPhaseChange;
  void Function(BossBattleResult)? onBattleEnd;

  BossBattleEngine({
    required this.config,
    required this.questions,
  }) {
    bossHp = config.maxHp;
    playerHp = config.playerMaxHp;
  }

  /// 开始战斗
  void start() {
    state = BossBattleState.fighting;
    battleStartTime = DateTime.now();
    currentPhase = BossPhase.phase1;
    _startQuestion();
    onStateChange?.call();
  }

  /// 开始当前题目
  void _startQuestion() {
    if (currentQuestionIndex >= questions.length) {
      _endBattle(bossHp <= 0);
      return;
    }

    questionStartTime = DateTime.now();
    remainingTime = _currentTimeLimit;
    _startTimer();
  }

  /// 当前阶段的时间限制
  int get _currentTimeLimit {
    double reduction = 0;
    switch (currentPhase) {
      case BossPhase.phase1:
        reduction = 0;
        break;
      case BossPhase.phase2:
        reduction = config.phase2TimeReduction;
        break;
      case BossPhase.phase3:
        reduction = config.phase3TimeReduction;
        break;
    }
    return (config.baseTimeLimit * (1 - reduction)).round();
  }

  /// 当前阶段的伤害倍率
  double get _currentDamageMultiplier {
    switch (currentPhase) {
      case BossPhase.phase1:
        return 1.0;
      case BossPhase.phase2:
        return config.phase2DamageMultiplier;
      case BossPhase.phase3:
        return config.phase3DamageMultiplier;
    }
  }

  void _startTimer() {
    questionTimer?.cancel();
    questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      remainingTime--;
      onTimerTick?.call(remainingTime);

      if (remainingTime <= 0) {
        _handleTimeout();
      }
    });
  }

  /// 超时处理
  void _handleTimeout() {
    questionTimer?.cancel();
    _takeDamage(15); // 超时扣 15 血
    combo = 0;
    _nextQuestion();
  }

  /// 提交答案
  void submitAnswer(String answer, {int score = 0, String feedback = ''}) {
    if (state != BossBattleState.fighting) return;
    questionTimer?.cancel();

    final q = questions[currentQuestionIndex];
    final timeBonus = remainingTime / q.timeLimit; // 剩余时间比例

    // 计算伤害
    int damage = _calculateDamage(q, score, timeBonus);

    // 连击判定
    bool isCorrect = score >= 60;
    bool isPerfect = score >= config.perfectScore;
    bool isCritical = false;

    if (isCorrect) {
      combo++;
      if (combo > maxCombo) maxCombo = combo;
      correctAnswers++;

      if (score > highestScore) highestScore = score;

      // 连击暴击
      if (combo >= config.comboThreshold && combo % config.comboThreshold == 0) {
        isCritical = true;
        damage = (damage * config.comboMultiplier).round();
      }

      // 完美加成
      if (isPerfect) {
        damage = (damage * config.perfectBonus).round();
      }

      // 阶段加成
      damage = (damage * _currentDamageMultiplier).round();

      _dealDamage(damage);
    } else {
      combo = 0;
      _takeDamage(20); // 答错扣 20 血
    }

    final result = AnswerResult(
      score: score,
      feedback: feedback,
      damageDealt: damage,
      damageTaken: isCorrect ? 0 : 20,
      comboCount: combo,
      isCritical: isCritical,
      isPerfect: isPerfect,
    );

    onAnswerEvaluated?.call(result);

    // 检查阶段变化
    _checkPhaseTransition();

    // 检查胜负
    if (bossHp <= 0) {
      _endBattle(true);
      return;
    }
    if (playerHp <= 0) {
      _endBattle(false);
      return;
    }

    // 下一题
    Future.delayed(const Duration(seconds: 2), () {
      _nextQuestion();
    });
  }

  /// 计算伤害
  int _calculateDamage(BossQuestion q, int score, double timeBonus) {
    // 基础伤害 = 题目基础伤害 * (分数/100)
    double damage = q.baseDamage * (score / 100);

    // 时间加成：剩余时间越多，伤害越高（最多 +20%）
    damage *= (1 + timeBonus * 0.2);

    return damage.round();
  }

  /// 对 Boss 造成伤害
  void _dealDamage(int damage) {
    bossHp = (bossHp - damage).clamp(0, config.maxHp);
    totalDamageDealt += damage;
  }

  /// 玩家受到伤害
  void _takeDamage(int damage) {
    playerHp = (playerHp - damage).clamp(0, config.playerMaxHp);
    totalDamageTaken += damage;
  }

  /// 检查阶段变化
  void _checkPhaseTransition() {
    final hpRatio = bossHp / config.maxHp;

    BossPhase newPhase = currentPhase;

    if (hpRatio <= config.phase3Threshold && currentPhase.index < BossPhase.phase3.index) {
      newPhase = BossPhase.phase3;
    } else if (hpRatio <= config.phase2Threshold && currentPhase.index < BossPhase.phase2.index) {
      newPhase = BossPhase.phase2;
    }

    if (newPhase != currentPhase) {
      currentPhase = newPhase;
      onPhaseChange?.call(newPhase);
    }
  }

  /// 下一题
  void _nextQuestion() {
    currentQuestionIndex++;
    if (currentQuestionIndex >= questions.length) {
      // 题用完了但 Boss 还没死 → 玩家输（耗尽弹药）
      _endBattle(bossHp <= 0);
      return;
    }
    _startQuestion();
  }

  /// 使用提示卡
  bool useHint() {
    if (hintsUsed >= 3) return false; // 一场最多用 3 次
    hintsUsed++;
    return true;
  }

  /// 使用跳题卡（跳过当前题，不扣血但也不输出伤害）
  bool useSkip() {
    if (skipsUsed >= 2) return false; // 一场最多用 2 次
    skipsUsed++;
    questionTimer?.cancel();
    combo = 0;
    _nextQuestion();
    return true;
  }

  /// 使用治疗卡
  bool useHeal() {
    if (usedItems.contains('heal')) return false; // 一场只能用一次
    usedItems.add('heal');
    playerHp = (playerHp + 30).clamp(0, config.playerMaxHp);
    return true;
  }

  /// 结束战斗
  void _endBattle(bool victory) {
    state = victory ? BossBattleState.victory : BossBattleState.defeat;
    questionTimer?.cancel();

    final totalTime = battleStartTime != null
        ? DateTime.now().difference(battleStartTime!)
        : Duration.zero;

    // 计算评级
    final rank = _calculateRank(victory);

    // 计算奖励
    final rewards = <String>[];
    int exp = 0;
    int coins = 0;

    if (victory) {
      exp = 100 + maxCombo * 10 + (rank == 'S' ? 100 : rank == 'A' ? 50 : 20);
      coins = 50 + (rank == 'S' ? 50 : rank == 'A' ? 25 : 10);
      rewards.add('exp+$exp');
      rewards.add('coins+$coins');
      if (rank == 'S') rewards.add('title:boss_slayer');
      if (maxCombo >= 5) rewards.add('achievement:combo_master');
    } else {
      exp = (correctAnswers * 10); // 失败也有参与奖励
      rewards.add('exp+$exp');
    }

    final result = BossBattleResult(
      victory: victory,
      totalDamageDealt: totalDamageDealt,
      totalDamageTaken: totalDamageTaken,
      maxCombo: maxCombo,
      questionsAnswered: currentQuestionIndex,
      correctAnswers: correctAnswers,
      highestScore: highestScore,
      totalTime: totalTime,
      rank: rank,
      rewards: rewards,
      expGained: exp,
      coinsGained: coins,
    );

    state = BossBattleState.ended;
    onBattleEnd?.call(result);
    onStateChange?.call();
  }

  /// 计算评级
  String _calculateRank(bool victory) {
    if (!victory) return 'D';

    final accuracy = currentQuestionIndex > 0
        ? correctAnswers / currentQuestionIndex
        : 0.0;
    final hpRatio = playerHp / config.playerMaxHp;

    if (accuracy >= 0.9 && hpRatio >= 0.5 && maxCombo >= 5) return 'S';
    if (accuracy >= 0.8 && hpRatio >= 0.3) return 'A';
    if (accuracy >= 0.6) return 'B';
    if (accuracy >= 0.4) return 'C';
    return 'D';
  }

  /// 清理资源
  void dispose() {
    questionTimer?.cancel();
  }
}

/// Boss 题目生成器
class BossQuestionGenerator {
  /// 生成指定数量的 Boss 题
  static List<BossQuestion> generateQuestions({
    required String subject,
    required String topic,
    required int count,
    required int difficulty, // 1-5
  }) {
    final rng = Random(DateTime.now().millisecondsSinceEpoch);
    final questions = <BossQuestion>[];

    final questionTemplates = _getTemplates(subject, topic, difficulty);

    for (int i = 0; i < count; i++) {
      final template = questionTemplates[i % questionTemplates.length];
      final timeLimit = _calculateTimeLimit(difficulty, i, count);
      final baseDamage = _calculateBaseDamage(difficulty, i, count);

      questions.add(BossQuestion(
        id: 'boss_q_$i',
        question: template['question'] as String,
        keyPoints: (template['keyPoints'] as List).cast<String>(),
        difficulty: i < count * 0.5 ? 'medium' : 'hard',
        questionType: template['type'] as String? ?? 'application',
        timeLimit: timeLimit,
        baseDamage: baseDamage,
      ));
    }

    return questions;
  }

  static int _calculateTimeLimit(int difficulty, int index, int total) {
    final baseTime = 90 - difficulty * 8;
    // 越往后时间越少
    final reduction = (index / total) * 0.3;
    return (baseTime * (1 - reduction)).round();
  }

  static int _calculateBaseDamage(int difficulty, int index, int total) {
    final base = 60 + difficulty * 20;
    // 越往后伤害越高（鼓励坚持到后面）
    final bonus = (index / total) * 0.5;
    return (base * (1 + bonus)).round();
  }

  static List<Map<String, dynamic>> _getTemplates(
      String subject, String topic, int difficulty) {
    // 这里返回占位模板，实际使用时通过 API 生成
    return [
      {
        'question': '请用你掌握的知识解决以下问题：$topic 相关的综合应用题',
        'keyPoints': ['核心概念理解', '方法选择与应用', '逻辑推导', '结果验证'],
        'type': 'application',
      },
      {
        'question': '设计一个方案来解决 $topic 领域的实际问题，并说明你的思路',
        'keyPoints': ['问题分析', '方案设计', '可行性论证', '优缺点分析'],
        'type': 'critical',
      },
      {
        'question': '比较 $topic 中两种不同方法的优劣，并说明适用场景',
        'keyPoints': ['方法原理对比', '适用场景分析', '性能比较', '实际选择建议'],
        'type': 'analysis',
      },
      {
        'question': '如果要优化 $topic 的性能，你会从哪些方面入手？',
        'keyPoints': ['瓶颈分析', '优化策略', '权衡取舍', '验证方法'],
        'type': 'brainstorm',
      },
      {
        'question': '用 $topic 的知识解决一个跨领域的实际问题',
        'keyPoints': ['知识迁移', '创新应用', '可行性分析', '具体方案'],
        'type': 'application',
      },
    ];
  }
}

/// 生成 Boss 题目的 API Prompt
class BossBattlePrompts {
  static String generateQuestionsPrompt({
    required String subject,
    required String topic,
    required int count,
    required int difficulty,
  }) {
    final diffDesc = switch (difficulty) {
      1 => '入门级',
      2 => '简单',
      3 => '中等',
      4 => '困难',
      5 => '地狱级',
      _ => '中等',
    };

    return '''
你是一位 Boss 战出题官。请为 $subject 领域的「$topic」Boss 战生成 $count 道应用题。

难度：$diffDesc（1-5 分制：$difficulty 分）

要求：
1. 题目难度递增，前几题中等，后面越来越难
2. 题型多样：应用题、分析题、设计题、优化题、跨领域题
3. 每道题都需要学生用自己的话详细回答，不是选择题
4. 题目要综合考察理解深度和应用能力，不是记忆
5. 要有一定的开放性，允许多种解法

请用 JSON 格式返回：
{
  "questions": [
    {
      "id": "q1",
      "question": "题目内容",
      "keyPoints": ["考察点1", "考察点2", "考察点3"],
      "difficulty": "easy/medium/hard/extreme",
      "questionType": "application/analysis/critical/brainstorm",
      "baseDamage": 基础伤害值（60-150）,
      "timeLimit": 建议限时秒数（60-120）
    }
  ]
}

只输出 JSON。''';
  }

  static String evaluateAnswerPrompt({
    required String question,
    required String answer,
    required List<String> keyPoints,
    required String questionType,
  }) {
    return '''
你是一位严格的 Boss 战裁判。请评估以下回答。

题目：$question
题型：$questionType
考察点：${keyPoints.join('、')}

学生的回答：
$answer

评分标准（严格评分）：
- 准确性（30分）：核心观点是否正确
- 深度（25分）：分析是否深入，有没有表面化
- 完整性（20分）：是否覆盖了各考察点
- 逻辑性（15分）：论证是否有条理
- 创新性（10分）：有没有独特的见解或巧妙的解法（加分项）

请用 JSON 返回：
{
  "score": 0-100的整数,
  "feedback": "简短有力的点评，像 Boss 的嘲讽或赞许",
  "breakdown": {
    "accuracy": 得分,
    "depth": 得分,
    "completeness": 得分,
    "logic": 得分,
    "creativity": 得分
  },
  "hasCleverSolution": true/false（是否有巧妙解法，有则额外伤害）,
  "cleverBonus": 0-30 巧妙解法额外伤害加成
}

注意：
- 70分以下算答错，玩家会扣血
- 95分以上是完美，会触发完美加成
- 如果有独特见解或巧妙解法，hasCleverSolution 设为 true

只输出 JSON。''';
  }
}
