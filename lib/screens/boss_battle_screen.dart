import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../boss_battle.dart';
import '../api_service.dart';

/// Boss 战页面
///
/// 完整的战斗体验：
/// - Boss 血条 + 阶段变化
/// - 玩家血条 + 道具栏
/// - 倒计时 + 连击系统
/// - 答题 → 伤害计算 → 反馈特效
/// - 胜利/失败结算
class BossBattleScreen extends StatefulWidget {
  final BossConfig config;
  final String subject;
  final String nodeId;

  const BossBattleScreen({
    super.key,
    required this.config,
    required this.subject,
    required this.nodeId,
  });

  @override
  State<BossBattleScreen> createState() => _BossBattleScreenState();
}

class _BossBattleScreenState extends State<BossBattleScreen>
    with TickerProviderStateMixin {
  late BossBattleEngine _engine;
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // 动画控制器
  late AnimationController _bossShakeController;
  late AnimationController _playerShakeController;
  late AnimationController _phaseTransitionController;
  late AnimationController _comboController;
  late AnimationController _damageNumberController;

  // 特效状态
  bool _showDamageNumber = false;
  int _lastDamage = 0;
  bool _isPlayerDamage = false;
  bool _showPhaseTransition = false;
  String _phaseTransitionText = '';
  bool _showCritical = false;
  bool _showPerfect = false;

  // 题目数据
  List<BossQuestion> _questions = [];
  bool _loading = true;
  bool _evaluating = false;
  String _feedback = '';
  int _lastScore = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadQuestions();
  }

  void _initAnimations() {
    _bossShakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _playerShakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _phaseTransitionController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _comboController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _damageNumberController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
  }

  Future<void> _loadQuestions() async {
    // 先用本地生成的占位题，同时请求 API 生成
    _questions = BossQuestionGenerator.generateQuestions(
      subject: widget.subject,
      topic: widget.config.bossName,
      count: widget.config.totalQuestions,
      difficulty: 3,
    );

    _engine = BossBattleEngine(
      config: widget.config,
      questions: _questions,
    );

    // 设置回调
    _engine.onTimerTick = (remaining) {
      if (mounted) setState(() {});
    };

    _engine.onAnswerEvaluated = (result) {
      _showDamage(result.damageDealt, isPlayerDamage: false);
      if (result.damageTaken > 0) {
        _showDamage(result.damageTaken, isPlayerDamage: true);
      }
      if (result.isCritical) {
        _showCriticalEffect();
      }
      if (result.isPerfect) {
        _showPerfectEffect();
      }
      setState(() {
        _feedback = result.feedback;
        _lastScore = result.score;
        _evaluating = false;
      });
    };

    _engine.onPhaseChange = (phase) {
      _showPhaseTransitionEffect(phase);
    };

    _engine.onBattleEnd = (result) {
      _showResultDialog(result);
    };

    setState(() => _loading = false);
  }

  void _startBattle() {
    _engine.start();
    setState(() {});
  }

  void _showDamage(int damage, {required bool isPlayerDamage}) {
    _lastDamage = damage;
    _isPlayerDamage = isPlayerDamage;
    _showDamageNumber = true;
    _damageNumberController.forward(from: 0);

    if (isPlayerDamage) {
      _playerShakeController.forward(from: 0);
    } else {
      _bossShakeController.forward(from: 0);
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _showDamageNumber = false);
      }
    });
  }

  void _showCriticalEffect() {
    _showCritical = true;
    _comboController.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showCritical = false);
    });
  }

  void _showPerfectEffect() {
    _showPerfect = true;
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _showPerfect = false);
    });
  }

  void _showPhaseTransitionEffect(BossPhase phase) {
    final text = switch (phase) {
      BossPhase.phase2 => '⚡ 狂暴阶段！',
      BossPhase.phase3 => '💀 绝境阶段！',
      _ => '',
    };
    _phaseTransitionText = text;
    _showPhaseTransition = true;
    _phaseTransitionController.forward(from: 0);

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showPhaseTransition = false);
    });
  }

  Future<void> _submitAnswer() async {
    if (_evaluating) return;
    final answer = _inputController.text.trim();
    if (answer.isEmpty) return;

    setState(() => _evaluating = true);
    _inputController.clear();

    final q = _questions[_engine.currentQuestionIndex];

    // 调用 API 评分
    final prompt = BossBattlePrompts.evaluateAnswerPrompt(
      question: q.question,
      answer: answer,
      keyPoints: q.keyPoints,
      questionType: q.questionType,
    );

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位严格公正的 Boss 战裁判。',
    );

    if (!result.success) {
      // API 失败，用本地评分（60分保底）
      _engine.submitAnswer(answer, score: 60, feedback: 'AI 暂时离线，默认通过');
      return;
    }

    final data = ApiService.parseJson(result);
    int score = 60;
    String feedback = result.content;

    if (data != null) {
      score = (data['score'] as num?)?.toInt() ?? 60;
      feedback = data['feedback']?.toString() ?? result.content;
      // 巧妙解法额外伤害已经在引擎中通过分数体现
    }

    _engine.submitAnswer(answer, score: score, feedback: feedback);
    setState(() {});
  }

  void _useHint() {
    if (_engine.useHint()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💡 使用提示卡！剩余 ${3 - _engine.hintsUsed} 次'),
          backgroundColor: AppTheme.accent,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _useSkip() {
    if (_engine.useSkip()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⏭️ 使用跳题卡！剩余 ${2 - _engine.skipsUsed} 次'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 2),
        ),
      );
      setState(() {
        _feedback = '';
        _lastScore = 0;
      });
    }
  }

  void _useHeal() {
    if (_engine.useHeal()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('💚 使用治疗卡！恢复 30 HP'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {});
    }
  }

  void _showResultDialog(BossBattleResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              result.victory ? '🎉 胜利！' : '💔 失败',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: result.victory ? AppTheme.taskDone : Colors.red,
              ),
            ),
            const SizedBox(height: 16),
            // 评级
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: result.rank == 'S'
                      ? [const Color(0xFFfbbf24), const Color(0xFFf59e0b)]
                      : result.rank == 'A'
                          ? [const Color(0xFFa78bfa), const Color(0xFF8b5cf6)]
                          : [AppTheme.accent, AppTheme.accentLight],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (result.rank == 'S'
                            ? const Color(0xFFfbbf24)
                            : AppTheme.accent)
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  result.rank,
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildResultRow('总伤害', '${result.totalDamageDealt}'),
            _buildResultRow('承受伤害', '${result.totalDamageTaken}'),
            _buildResultRow('最高连击', '${result.maxCombo} combo'),
            _buildResultRow('正确率',
                '${result.correctAnswers}/${result.questionsAnswered}'),
            _buildResultRow('最高分', '${result.highestScore}'),
            _buildResultRow(
                '用时',
                '${result.totalTime.inMinutes}:${(result.totalTime.inSeconds % 60).toString().padLeft(2, '0')}'),
            const SizedBox(height: 16),
            const Divider(color: AppTheme.border),
            const SizedBox(height: 12),
            const Text('获得奖励',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: result.rewards.map((r) {
                Color color = AppTheme.accent;
                IconData icon = Icons.star;
                String text = r;

                if (r.startsWith('exp+')) {
                  icon = Icons.trending_up;
                  color = Colors.green;
                } else if (r.startsWith('coins+')) {
                  icon = Icons.monetization_on;
                  color = Colors.amber;
                } else if (r.startsWith('title:')) {
                  icon = Icons.emoji_events;
                  color = Colors.purple;
                  text = r.replaceFirst('title:', '称号: ');
                } else if (r.startsWith('achievement:')) {
                  icon = Icons.military_tech;
                  color = Colors.orange;
                  text = r.replaceFirst('achievement:', '成就: ');
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(text,
                          style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: result.victory
                      ? AppTheme.taskDone
                      : AppTheme.accent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(result.victory ? '领取奖励' : '下次再来',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _engine.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    _bossShakeController.dispose();
    _playerShakeController.dispose();
    _phaseTransitionController.dispose();
    _comboController.dispose();
    _damageNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppTheme.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🐉', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 20),
              Text('Boss 正在登场...',
                  style: TextStyle(
                      fontSize: 18,
                      color: AppTheme.textSecondary)),
            ],
          ),
        ),
      );
    }

    if (_engine.state == BossBattleState.preparing) {
      return _buildPrepScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Boss 区
                _buildBossArea(),
                // 中间战斗信息
                _buildBattleInfo(),
                // 题目/答题区
                Expanded(child: _buildQuestionArea()),
                // 玩家区
                _buildPlayerArea(),
              ],
            ),
          ),
          // 阶段过渡特效
          if (_showPhaseTransition) _buildPhaseOverlay(),
          // 暴击特效
          if (_showCritical) _buildCriticalOverlay(),
          // 完美特效
          if (_showPerfect) _buildPerfectOverlay(),
        ],
      ),
    );
  }

  Widget _buildPrepScreen() {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.config.bossEmoji, style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 20),
            Text(
              widget.config.bossName,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.config.totalQuestions} 道题 · ${widget.config.maxHp} HP',
              style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 200,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startBattle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFef4444),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                icon: const Icon(Icons.flash_on, size: 22),
                label: const Text('开始战斗',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '限时答题 · 连击暴击 · 多阶段 Boss',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBossArea() {
    final bossHpRatio = _engine.bossHp / widget.config.maxHp;
    final hpColor = _getBossHpColor(bossHpRatio);

    return AnimatedBuilder(
      animation: _bossShakeController,
      builder: (_, child) {
        final offset = _bossShakeController.value > 0
            ? Offset(
                _bossShakeController.value * 8 *
                    (_bossShakeController.value < 0.5 ? 1 : -1),
                0)
            : Offset.zero;
        return Transform.translate(offset: offset, child: child);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            Row(
              children: [
                // Boss 头像
                Stack(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            _getPhaseColor().withValues(alpha: 0.3),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Center(
                        child: Text(widget.config.bossEmoji,
                            style: const TextStyle(fontSize: 36)),
                      ),
                    ),
                    if (_showDamageNumber && !_isPlayerDamage)
                      Positioned(
                        top: 0,
                        right: -10,
                        child: _buildDamageNumber(false),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                // Boss 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.config.bossName,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // 阶段标识
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getPhaseColor().withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _getPhaseColor().withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              _phaseLabel(_engine.currentPhase),
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _getPhaseColor()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Boss 血条
                      Stack(
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(7),
                              border: Border.all(color: AppTheme.border),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: bossHpRatio,
                            child: Container(
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [hpColor, hpColor.withValues(alpha: 0.7)],
                                ),
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: hpColor.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '${_engine.bossHp} / ${widget.config.maxHp}',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getBossHpColor(double ratio) {
    if (ratio > 0.66) return const Color(0xFF22c55e);
    if (ratio > 0.33) return const Color(0xFFf59e0b);
    return const Color(0xFFef4444);
  }

  Color _getPhaseColor() {
    switch (_engine.currentPhase) {
      case BossPhase.phase1:
        return const Color(0xFF3b82f6);
      case BossPhase.phase2:
        return const Color(0xFFf59e0b);
      case BossPhase.phase3:
        return const Color(0xFFef4444);
    }
  }

  String _phaseLabel(BossPhase phase) {
    switch (phase) {
      case BossPhase.phase1:
        return 'P1 正常';
      case BossPhase.phase2:
        return 'P2 狂暴';
      case BossPhase.phase3:
        return 'P3 绝境';
    }
  }

  Widget _buildBattleInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 题号
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '第 ${_engine.currentQuestionIndex + 1}/${_questions.length} 题',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
          ),
          // 连击
          if (_engine.combo > 0)
            AnimatedBuilder(
              animation: _comboController,
              builder: (_, child) {
                final scale = 1.0 + _comboController.value * 0.3;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.orange,
                          Colors.red,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bolt, size: 14, color: Colors.yellow),
                        const SizedBox(width: 4),
                        Text(
                          '${_engine.combo} COMBO',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // 倒计时
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _engine.remainingTime <= 10
                  ? Colors.red.withValues(alpha: 0.2)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _engine.remainingTime <= 10
                    ? Colors.red.withValues(alpha: 0.4)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.timer,
                  size: 14,
                  color: _engine.remainingTime <= 10
                      ? Colors.red
                      : AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_engine.remainingTime}s',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _engine.remainingTime <= 10
                        ? Colors.red
                        : AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionArea() {
    final q = _questions.isNotEmpty &&
            _engine.currentQuestionIndex < _questions.length
        ? _questions[_engine.currentQuestionIndex]
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (q != null) ...[
              // 题目类型标签
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getDifficultyColor(q.difficulty)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _difficultyLabel(q.difficulty),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _getDifficultyColor(q.difficulty)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _typeLabel(q.questionType),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.accent),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.flash_on,
                      size: 14, color: Colors.orange.withValues(alpha: 0.7)),
                  const SizedBox(width: 2),
                  Text('${q.baseDamage}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 12),
              // 题目
              Text(
                q.question,
                style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    height: 1.6,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              // 反馈区域
              if (_feedback.isNotEmpty) _buildFeedbackCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard() {
    final isGood = _lastScore >= 70;
    final isPerfect = _lastScore >= 95;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPerfect
            ? Colors.amber.withValues(alpha: 0.1)
            : isGood
                ? Colors.green.withValues(alpha: 0.08)
                : Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPerfect
              ? Colors.amber.withValues(alpha: 0.3)
              : isGood
                  ? Colors.green.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isPerfect ? '🏆 完美！' : isGood ? '✅ 答对了' : '❌ 答错了',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isPerfect
                        ? Colors.amber
                        : isGood
                            ? Colors.green
                            : Colors.red),
              ),
              const Spacer(),
              Text('$_lastScore 分',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isPerfect
                          ? Colors.amber
                          : isGood
                              ? Colors.green
                              : Colors.red)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _feedback,
            style: TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String diff) {
    switch (diff) {
      case 'easy':
        return Colors.green;
      case 'medium':
        return Colors.blue;
      case 'hard':
        return Colors.orange;
      case 'extreme':
        return Colors.red;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _difficultyLabel(String diff) {
    switch (diff) {
      case 'easy':
        return '简单';
      case 'medium':
        return '中等';
      case 'hard':
        return '困难';
      case 'extreme':
        return '地狱';
      default:
        return diff;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'application':
        return '应用题';
      case 'analysis':
        return '分析题';
      case 'critical':
        return '思考题';
      case 'brainstorm':
        return '发散题';
      default:
        return type;
    }
  }

  Widget _buildPlayerArea() {
    final hpRatio = _engine.playerHp / widget.config.playerMaxHp;

    return AnimatedBuilder(
      animation: _playerShakeController,
      builder: (_, child) {
        final offset = _playerShakeController.value > 0
            ? Offset(
                _playerShakeController.value * 6 *
                    (_playerShakeController.value < 0.5 ? 1 : -1),
                0)
            : Offset.zero;
        return Transform.translate(offset: offset, child: child);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 玩家血条 + 道具栏
            Row(
              children: [
                // 玩家头像
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [AppTheme.accent, AppTheme.accentLight],
                    ),
                  ),
                  child:
                      const Center(child: Text('🧑‍🎓', style: TextStyle(fontSize: 22))),
                ),
                const SizedBox(width: 10),
                // 血条
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'HP ${_engine.playerHp}/${widget.config.playerMaxHp}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 3),
                      Stack(
                        children: [
                          Container(
                            height: 10,
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: hpRatio,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF22c55e),
                                    const Color(0xFF16a34a),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                // 伤害数字
                if (_showDamageNumber && _isPlayerDamage)
                  _buildDamageNumber(true),
              ],
            ),
            const SizedBox(height: 8),
            // 道具栏
            Row(
              children: [
                _buildItemButton(Icons.lightbulb_outline, '提示',
                    '${3 - _engine.hintsUsed}/3', Colors.amber, _useHint),
                const SizedBox(width: 6),
                _buildItemButton(Icons.skip_next, '跳题',
                    '${2 - _engine.skipsUsed}/2', Colors.orange, _useSkip),
                const SizedBox(width: 6),
                _buildItemButton(
                    Icons.favorite,
                    '治疗',
                    _engine.usedItems.contains('heal') ? '已用' : '+30HP',
                    Colors.green,
                    _engine.usedItems.contains('heal') ? null : _useHeal),
                const Spacer(),
                // 发送按钮
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: _evaluating ? null : _submitAnswer,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _evaluating ? AppTheme.border : AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      elevation: 0,
                    ),
                    icon: _evaluating
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send, size: 16),
                    label: Text(_evaluating ? '批改中' : '提交',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // 输入框
            TextField(
              controller: _inputController,
              maxLines: 3,
              minLines: 1,
              enabled: !_evaluating,
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: '用你自己的话回答，想到什么写什么...',
                hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.6),
                    fontSize: 13),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppTheme.accent, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitAnswer(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemButton(
    IconData icon,
    String label,
    String count,
    Color color,
    VoidCallback? onTap,
  ) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: disabled
              ? AppTheme.surfaceLight.withValues(alpha: 0.5)
              : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: disabled
                  ? AppTheme.border.withValues(alpha: 0.5)
                  : color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: disabled ? AppTheme.border : color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: disabled
                        ? AppTheme.textSecondary.withValues(alpha: 0.5)
                        : color)),
            Text(count,
                style: TextStyle(
                    fontSize: 9,
                    color: disabled
                        ? AppTheme.border
                        : AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildDamageNumber(bool isPlayerDamage) {
    return AnimatedBuilder(
      animation: _damageNumberController,
      builder: (_, child) {
        final progress = _damageNumberController.value;
        final opacity = progress < 0.3
            ? progress / 0.3
            : (1 - (progress - 0.3) / 0.7).clamp(0.0, 1.0);
        final translateY = -progress * 40;

        return Transform.translate(
          offset: Offset(0, translateY),
          child: Opacity(
            opacity: opacity,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isPlayerDamage
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '-$_lastDamage',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhaseOverlay() {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _phaseTransitionController,
        builder: (_, child) {
          final progress = _phaseTransitionController.value;
          final scale = 0.5 + progress * 0.5;
          final opacity = progress < 0.3
              ? progress / 0.3
              : (1 - (progress - 0.6) / 0.4).clamp(0.0, 1.0);

          return Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.red, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.5),
                        blurRadius: 30,
                      ),
                    ],
                  ),
                  child: Text(
                    _phaseTransitionText,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.red),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCriticalOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.orange.withValues(alpha: 0.15),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('💥', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.red],
                    ),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    '暴击！',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPerfectOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          color: Colors.amber.withValues(alpha: 0.1),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏆', style: TextStyle(fontSize: 72)),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    'PERFECT!',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
