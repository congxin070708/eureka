import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../speech_recognizer.dart';
import '../api_service.dart';
import '../app_theme.dart';
import '../file_storage_service.dart';
import '../review_scheduler.dart';
import '../prompts.dart';
import '../providers/app_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/learn_input_bar.dart';
import '../widgets/demo_panel.dart';
import '../widgets/level_up_overlay.dart';
import '../widgets/api_key_guide_sheet.dart';
import '../skill_tree.dart';
import '../utils/input_validation.dart';
import '../preset_courses.dart';
import '../secure_storage_service.dart';
import 'stats_screen.dart';

/// 学习页面 - 模块化重构后
/// 聊天气泡、输入栏、演示面板、输入验证已抽取为独立模块
/// 状态管理通过 Riverpod(studyEngineProvider) 共享引擎数据
class LearnScreen extends ConsumerStatefulWidget {
  final String subject;
  final String? skillNodeId;   // 对应的技能节点 ID
  final bool isBossMode;      // Boss 关模式（应用题 + 多解法加分）

  const LearnScreen({
    super.key,
    required this.subject,
    this.skillNodeId,
    this.isBossMode = false,
  });

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen> {
  final _messages = <ChatMsg>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _answering = false;
  String _lastQ = '';
  String _topic = '';
  int _subjectImportance = 70;

  // 结构化评分：当前题目的答案要点关键词（由 AI 出题时生成）
  // 评分时用关键词匹配计算确定性分数，LLM 仅提供反馈解释
  List<String> _currentAnswerKeys = [];

  // 预置课程模式步骤：0=讲解, 1=出题(等待作答), 2=评分完成
  int _presetStep = 0;

  // 语音识别
  late dynamic _speech;  // SpeechRecognizerImpl (IO/Web 条件实现)
  bool _isListening = false;

  // 防抖保存
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _speech = SpeechRecognizer.create();
    setState(() => _messages.add(ChatMsg(emoji: '⏳', text: '初始化中...', isAI: true)));
    _loadMessages();
  }

  void _loadMessages() async {
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 3; i++) {
      try {
        final fileData = await FileStorageService.loadEngineData();
        if (fileData != null) {
          final msgs = fileData['chatHistory']?[widget.subject.trim()];
          if (msgs != null && msgs.isNotEmpty) {
            setState(() => _messages.clear());
            for (final m in msgs) {
              _messages.add(ChatMsg.fromMap(Map<String, dynamic>.from(m)));
            }
            final engine = ref.read(studyEngineProvider);
            engine.chatHistory[widget.subject.trim()] =
                (msgs as List).cast<Map<String, dynamic>>();
            setState(() {});
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            return;
          }
        }
      } catch (_) {
        // 历史记录读取或类型转换失败时忽略，继续后续初始化流程
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    if (_messages.length == 1 && _messages[0].text == '初始化中...') {
      _updateLast('📋 正在准备学习方案...');
    }
    _startSubject();
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _saveChatHistory();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveChatHistory() async {
    final engine = ref.read(studyEngineProvider);
    final key = widget.subject.trim();
    if (_messages.isNotEmpty) {
      engine.chatHistory[key] = _cappedMessages();
    }
    await FileStorageService.save({'engine_data': engine.toJson()});
  }

  void _startSubject() async {
    if (!InputValidation.isValidSubject(widget.subject)) {
      _addMsg('⚠️', '【系统】未识别的学科，请输入一个有效的学科名称\n\n'
          '例如：高等数学、英语、编程、物理学...', isAI: true);
      return;
    }

    // 预置课程模式：无 API Key 且当前科目有预置课程时，走本地流程
    final preset = PresetCourses.findBySubject(widget.subject);
    if (ApiService.apiKey.isEmpty && preset != null) {
      _topic = preset.topic;
      _presetStep = 0;
      _updateLast('📋 【系统提示】${widget.subject} · 体验模式\n\n'
          '当前未配置 API Key，已为你准备内置课程「${preset.topic}」。\n\n'
          '直接输入任意内容即可开始学习（无需联网）');
      return;
    }

    if (_messages.isNotEmpty && _messages.last.text.contains('初始化')) {
      _updateLast('📋 【系统提示】${widget.subject}\n\n正在生成学习方案...');
    } else {
      _addMsg('📋', '📋 【系统提示】${widget.subject}\n\n正在生成学习方案...', isAI: true);
    }

    final engine = ref.read(studyEngineProvider);
    final mode = engine.studyMode;
    final input = widget.subject;
    final purposeHint = InputValidation.detectPurposeHint(input);

    final result = await ApiService.startSubject(widget.subject,
        extraHint: purposeHint, mode: mode)
        .timeout(const Duration(seconds: 25), onTimeout: () {
      _updateLast('❌ 连接超时，请检查网络后重试');
      return ApiResult.failure('timeout');
    });
    if (!result.success) {
      if (result.error == 'timeout') return;
      _updateLast('❌ 系统错误\n${result.error}');
      return;
    }
    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ 系统错误：AI返回格式异常');
      return;
    }

    engine.getSubject(widget.subject);
    await FileStorageService.save({'engine_data': engine.toJson()});

    StringBuffer buf = StringBuffer();
    buf.writeln('📋 【系统提示】${widget.subject} · 学习路线');
    buf.writeln('─── ─── ─── ─── ─── ─── ─── ───');
    buf.writeln('');
    buf.writeln('${data['welcome'] ?? '开始学习吧！'}');
    buf.writeln('');

    if (data['stages'] != null) {
      for (final stage in data['stages']) {
        final level = stage['level'] ?? '阶段';
        buf.writeln('');
        buf.writeln('┌─ $level ───────────────');
        buf.writeln('');
        if (stage['books'] != null) {
          for (final b in stage['books']) {
            final name = b['name'] ?? '';
            final author = b['author'] ?? '';
            final value = b['value'];
            final reason = b['reason'] ?? '';

            if (value is int && value > _subjectImportance) {
              _subjectImportance = value;
            }

            String valueTag;
            if (value is int) {
              if (value >= 90) valueTag = '⭐⭐⭐⭐⭐ 力荐';
              else if (value >= 70) valueTag = '⭐⭐⭐⭐ 推荐';
              else if (value >= 50) valueTag = '⭐⭐⭐ 值得看';
              else if (value >= 30) valueTag = '⭐⭐ 参考';
              else valueTag = '⭐ 了解';
            } else {
              valueTag = '📖 推荐';
            }

            buf.writeln('   📖 $name');
            if (author.isNotEmpty) buf.writeln('      作者：$author');
            buf.writeln('      $valueTag');
            buf.writeln('      $reason');
            buf.writeln('   ─ ─ ─ ─ ─ ─ ─ ─');
            buf.writeln('');
          }
        }
        buf.writeln('└─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─');
        buf.writeln('');
      }
    }

    buf.writeln('');
    buf.writeln('─── ─── ─── ─── ─── ─── ─── ───');
    buf.writeln('🗺️ 学习路线');
    if (data['topics'] != null) {
      var i = 1;
      for (final t in data['topics']) {
        buf.writeln('   $i. $t');
        i++;
      }
    }

    _updateLast(buf.toString());
    await FileStorageService.save({'engine_data': engine.toJson()});

    if (mode == '挑战') {
      if (data['challenge'] != null) {
        final ch = data['challenge'];
        _lastQ = ch['q'] ?? '';
        _topic = widget.subject;
        String hint = ch['hint'] ?? '';
        String msg = '💡 **挑战题**\n\n$_lastQ\n';
        if (hint.isNotEmpty) msg += '\n💬 提示：$hint';
        Future.delayed(const Duration(milliseconds: 500), () {
          _addMsg('💡', msg, isAI: true);
          _answering = true;
        });
        return;
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('🎯', '挑战模式未生成挑战题（AI返回格式问题），已退回学习路线。\n输入任意话题名继续学习，或回复"跳过"看参考。', isAI: true);
      });
      return;
    }

    if (data['topics'] != null && (data['topics'] as List).isNotEmpty) {
      final topics = (data['topics'] as List).take(6).join('\n   ');
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('🎯', '以上是为你定制的学习方案。\n\n想从哪个话题开始？\n    $topics\n\n直接输入话题名称即可', isAI: true);
      });
    }

    if (data['ask'] != null) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('🎯', data['ask'], isAI: true);
      });
    }

    // 首次使用引导
    _checkFirstTimeGuide();
  }

  /// 检查并显示首次使用引导
  void _checkFirstTimeGuide() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenGuide = prefs.getBool('learn_guide_seen') ?? false;
    if (!hasSeenGuide) {
      await prefs.setBool('learn_guide_seen', true);
      // 延迟一会儿再显示，避免和欢迎消息挤在一起
      Future.delayed(const Duration(milliseconds: 1500), () {
        _addMsg('💡', '**新手指南**\n\n'
            '欢迎使用尤里卡！这里有一些使用小技巧：\n\n'
            '📝 **答题时**：用自己的话回答，答错也没关系，AI 会帮你纠正\n'
            '💬 **对话时**：可以说「下一题」「举个例子」「再解释一下」\n'
            '⚡ **快捷短语**：点击输入框上方的芯片，快速输入常用内容\n'
            '❓ **帮助**：点击输入框右侧的 ? 查看完整使用技巧\n\n'
            '准备好了就输入话题名称开始学习吧！', isAI: true);
      });
    }
  }

  void _askQuestion(String topic) async {
    _answering = true;
    _topic = topic;
    _currentAnswerKeys = []; // 清空上一题的答案关键词
    final engine = ref.read(studyEngineProvider);
    final mode = engine.studyMode;
    final kpType = EurekaPrompts.knowledgeTypeLabel(mode);
    engine.getOrCreateKnowledgePoint(
      widget.subject.trim(), topic.trim(),
      type: kpType, importance: _subjectImportance,
    );
    _addMsg('💡', '正在出题...', isAI: true);

    // Boss 模式：出应用题
    if (widget.isBossMode) {
      await _askBossQuestion(topic);
      return;
    }

    final result = await ApiService.generateQuestion(topic, mode: mode, subject: widget.subject);
    if (!result.success) {
      _updateLast('❌ 出题失败\n${result.error}');
      _answering = false;
      return;
    }
    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ AI返回格式异常');
      _answering = false;
      return;
    }
    _lastQ = data['q'] ?? '';
    // 存储答案关键词用于结构化评分
    if (data['answerKeys'] != null && (data['answerKeys'] as List).isNotEmpty) {
      _currentAnswerKeys = (data['answerKeys'] as List)
          .map((e) => e.toString())
          .toList();
    } else if (data['points'] != null && (data['points'] as List).isNotEmpty) {
      // 兼容：如果没有 answerKeys，用 points 的简短形式
      _currentAnswerKeys = (data['points'] as List)
          .map((e) => e.toString())
          .toList();
    }
    String hint = data['hint'] ?? '';
    String msg = '💡 **思考题**\n\n$_lastQ\n';
    if (hint.isNotEmpty) msg += '\n💬 提示：$hint';
    _updateLast(msg);
  }

  /// Boss 模式：出真实场景应用题
  Future<void> _askBossQuestion(String topic) async {
    final prompt = '''
请围绕「$topic」这个知识点，出一道 Boss 级应用题。
${EurekaPrompts.bossQuestionPrompt}''';

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位擅长出应用题的老师，题目要有代入感。',
      subject: widget.subject,
    );

    if (!result.success) {
      _updateLast('❌ 出题失败\n${result.error}');
      _answering = false;
      return;
    }

    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ AI返回格式异常\n\n${result.content}');
      _answering = false;
      return;
    }

    final title = data['title']?.toString() ?? 'Boss 挑战';
    final scenario = data['scenario']?.toString() ?? '';
    final question = data['question']?.toString() ?? '';
    final kps = (data['knowledgePoints'] as List?)?.cast<String>() ?? [];
    _lastQ = question;

    String msg = '👹 **Boss 挑战：$title**\n\n';
    if (scenario.isNotEmpty) {
      msg += '📖 $scenario\n\n';
    }
    msg += '❓ **问题**\n$question\n\n';
    if (kps.isNotEmpty) {
      msg += '📌 考察知识点：${kps.join('、')}\n\n';
    }
    msg += '💡 这道题有多种解法，用越巧妙的方法得分越高！';

    _updateLast(msg);
  }

  /// Boss 模式评分：多解法加分
  Future<void> _scoreBossAnswer(String answer, dynamic engine) async {
    final prompt = '''
题目：$_lastQ

学生的回答/解法：
$answer

${EurekaPrompts.bossGradingPrompt}''';

    final result = await ApiService.chat(
      prompt,
      systemPrompt: EurekaPrompts.systemStrictGrader,
      subject: widget.subject,
    );

    if (!result.success) {
      _updateLast('❌ 评分失败\n${result.error}');
      setState(() {
        _answering = false;
        _loading = false;
      });
      return;
    }

    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ AI评分格式异常\n\n${result.content}');
      setState(() {
        _answering = false;
        _loading = false;
      });
      return;
    }

    final score = (data['score'] as num?)?.toInt() ?? 0;
    final bonusScore = (data['bonusScore'] as num?)?.toInt() ?? 0;
    final feedback = data['feedback']?.toString() ?? '';
    final bonusReasons = (data['bonusReasons'] as List?)?.cast<String>() ?? [];
    final methodUsed = data['methodUsed']?.toString() ?? '';
    final isClever = data['isClever'] as bool? ?? false;
    final bestMethod = data['bestMethod']?.toString() ?? '';
    final mastered = data['mastered'] as bool? ?? false;

    // 计算展示用的分数（超过100分显示为100+）
    final displayScore = score > 120 ? 120 : score;

    String scoreEmoji;
    String scoreLabel;
    if (score >= 100) {
      scoreEmoji = '🏆';
      scoreLabel = '完美通关';
    } else if (score >= 80) {
      scoreEmoji = '🌟';
      scoreLabel = '优秀通关';
    } else if (score >= 60) {
      scoreEmoji = '⭐';
      scoreLabel = '勉强通过';
    } else {
      scoreEmoji = '💪';
      scoreLabel = '挑战失败';
    }

    String msg = '👹 **Boss 战结果**\n\n';
    msg += '$scoreEmoji 得分：$displayScore / 100';
    if (bonusScore > 0) msg += ' (+$bonusScore 额外加分)';
    msg += '  [$scoreLabel]\n\n';

    if (methodUsed.isNotEmpty) {
      msg += '📝 使用方法：$methodUsed\n';
      if (isClever) msg += '✨ 巧妙解法！\n';
      msg += '\n';
    }

    if (bonusReasons.isNotEmpty) {
      msg += '🎁 额外加分：\n';
      for (final r in bonusReasons) {
        msg += '  · $r\n';
      }
      msg += '\n';
    }

    msg += '💬 $feedback\n\n';

    if (bestMethod.isNotEmpty && !isClever) {
      msg += '💡 推荐更优解法：\n$bestMethod\n\n';
    }

    if (mastered) {
      msg += '🎉 Boss 已击败！你已经完全掌握了这个知识点。';
    } else {
      msg += '📝 再来一次？Boss 还在等你挑战！';
    }

    // 更新掌握度（Boss 分数需要按比例换算到 1.0）
    final normalizedScore = (score / 100.0).clamp(0.0, 1.2);
    final kp = engine.findKnowledgePoint(widget.subject.trim(), _topic.trim());
    if (kp != null) {
      kp.recordAttempt(mastered);
      if (mastered) kp.qualitativeMastery = true;
    }

    // 更新技能树
    if (widget.skillNodeId != null) {
      engine.completeSkillNode(widget.subject, widget.skillNodeId!,
          normalizedScore.clamp(0.0, 1.0));
    }

    // 任务进度
    engine.taskManager.recordAnswer(mastered);

    await FileStorageService.save({'engine_data': engine.toJson()});

    _updateLast(msg);
    setState(() {
      _answering = false;
      _loading = false;
    });
    _scrollToBottom();

    // 检查升级
    final prevLevel = engine.level;
    if (engine.checkLevelUp() && context.mounted) {
      final unlocks = <String>['Boss 技能已掌握！'];
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => LevelUpOverlay(
          oldLevel: prevLevel,
          newLevel: engine.level,
          xpGained: score,
          unlocks: unlocks,
          onDismiss: () => Navigator.pop(context),
        ),
      );
    }
  }

  void _submitAnswer() async {
    final answer = _inputController.text.trim();
    if (answer.isEmpty) return;
    final engine = ref.read(studyEngineProvider);
    if (InputValidation.isOtherSubject(answer, widget.subject, engine.subjects)) {
      _inputController.clear();
      _addMsg('👤', answer, isAI: false);
      _addMsg('💡', '「$answer」是其他学科。当前在挑战「${widget.subject}」,请回答当前问题;\n想学其他学科请返回书架切换。', isAI: true);
      return;
    }
    if (InputValidation.isIrrelevantInput(answer)) {
      _inputController.clear();
      _addMsg('👤', answer, isAI: false);
      _addMsg('💡', '这条和问题无关,请认真回答:\n$_lastQ\n\n答不上来可以输"跳过"看答案', isAI: true);
      return;
    }
    _inputController.clear();
    _addMsg('👤', answer, isAI: false);
    _addMsg('📊', '系统评分中...', isAI: true);
    _loading = true;

    // Boss 模式用多解法评分
    if (widget.isBossMode) {
      await _scoreBossAnswer(answer, engine);
      return;
    }

    // ── 结构化评分：优先使用关键词匹配计算确定性分数 ──
    int score;
    String feedback = '';
    String suggest = '';
    String missed = '';
    String correctPoints = '';
    bool usedStructuredScoring = false;

    if (_currentAnswerKeys.isNotEmpty) {
      usedStructuredScoring = true;
      // 1) 本地关键词匹配评分（确定性，不受 LLM 随机性影响）
      final result = PresetCourses.localScore(answer, _currentAnswerKeys);
      score = result['score'] as int;
      final matched = (result['matched'] as List).cast<String>();
      final missedList = (result['missed'] as List).cast<String>();
      correctPoints = matched.join('、');
      missed = missedList.join('、');

      // 2) 调用 LLM 获取反馈解释（非评分，仅解释）
      final llmResult = await ApiService.scoreAnswer(_lastQ, answer, subject: widget.subject);
      if (llmResult.success) {
        final llmData = ApiService.parseJson(llmResult);
        if (llmData != null) {
          feedback = llmData['feedback'] ?? '';
          suggest = llmData['suggest'] ?? '';
          // 如果 LLM 也返回了 missed/correct，优先用 LLM 的（更语义化）
          if (llmData['missed'] != null && (llmData['missed'] as List).isNotEmpty) {
            missed = (llmData['missed'] as List).join('、');
          }
          if (llmData['correct'] != null && (llmData['correct'] as List).isNotEmpty) {
            correctPoints = (llmData['correct'] as List).join('、');
          }
        }
      }
      // LLM 调用失败时，用本地评分结果生成基础反馈
      if (feedback.isEmpty) {
        if (score >= 80) {
          feedback = '回答中包含了大部分关键要点，理解到位。';
        } else if (score >= 60) {
          feedback = '答对了一部分要点，但还有重要的知识点需要补充。';
        } else if (score >= 30) {
          feedback = '只答对了少量要点，建议重新回顾讲解内容。';
        } else {
          feedback = '答案与关键要点差距较大，请仔细阅读讲解后再试。';
        }
      }
      if (suggest.isEmpty) {
        suggest = missed.isNotEmpty ? '重点复习：$missed' : '继续保持！';
      }
    } else {
      // 无答案关键词（挑战模式等），回退到纯 LLM 评分
      final result = await ApiService.scoreAnswer(_lastQ, answer, subject: widget.subject);
      if (!result.success) {
        _updateLast('❌ 评分失败\n${result.error}');
        _answering = false;
        return;
      }
      final data = ApiService.parseJson(result);
      if (data == null) {
        _updateLast('❌ AI评分格式异常');
        _answering = false;
        return;
      }
      score = data['score'] ?? 0;
      feedback = data['feedback'] ?? '';
      suggest = data['suggest'] ?? '';
      if (data['missed'] != null && (data['missed'] as List).isNotEmpty) {
        missed = (data['missed'] as List).join('、');
      }
      if (data['correct'] != null && (data['correct'] as List).isNotEmpty) {
        correctPoints = (data['correct'] as List).join('、');
      }
    }
    // 清空答案关键词，避免下一题误用
    _currentAnswerKeys = [];

    String scoreEmoji;
    String scoreLabel;
    String encourageMsg;
    if (score >= 90) {
      scoreEmoji = '🌟';
      scoreLabel = '神级';
      encourageMsg = '太棒了！你已经完全掌握了这个知识点 🎉';
    } else if (score >= 80) {
      scoreEmoji = '🔥';
      scoreLabel = '优秀';
      encourageMsg = '答得很好！差一点就完美了，继续保持！';
    } else if (score >= 60) {
      scoreEmoji = '⭐';
      scoreLabel = '及格';
      encourageMsg = '还不错！再巩固一下薄弱点就能更上一层楼。';
    } else if (score >= 30) {
      scoreEmoji = '📗';
      scoreLabel = '加油';
      encourageMsg = '别灰心，回顾一下要点，我们再来一次！';
    } else {
      scoreEmoji = '💪';
      scoreLabel = '继续努力';
      encourageMsg = '没关系，学习就是不断试错的过程。先看看解析，再试一次！';
    }

    String msg = '📊 评分结果\n\n';
    msg += '$scoreEmoji 得分：$score / 100  ($scoreLabel)\n';
    if (usedStructuredScoring) {
      msg += '  （基于答案要点匹配 · 确定性评分）\n';
    }
    msg += '\n';
    msg += '📝 $feedback\n\n';
    if (correctPoints.isNotEmpty) msg += '✅ 答对了：$correctPoints\n\n';
    if (missed.isNotEmpty) msg += '📌 还需要掌握：$missed\n\n';
    if (suggest.isNotEmpty) msg += '💡 建议：$suggest\n';
    msg += '\n$encourageMsg';

    final kp = engine.findKnowledgePoint(widget.subject.trim(), _topic.trim());
    if (kp != null) {
      final passed = score >= 60;
      final mastery = kp.recordAttempt(passed);
      if (kp.type == 'concept' || kp.type == 'design') {
        if (score >= 90) kp.qualitativeMastery = true;
      }
      ReviewScheduler.updateKnowledgePoint(kp, passed);
      final need = kp.gateThreshold;
      final pct = (mastery * 100).round();
      final gatePct = (need * 100).round();
      msg += '\n🎯 掌握度：${pct}% / ${gatePct}%';
      if (kp.isMastered) {
        msg += ' ✅ 已掌握，可进入下一个知识点';
      } else {
        msg += '\n   未达标，继续练习「$_topic」直到掌握';
      }
    }

    // ── 技能树：更新对应节点的掌握度 ──
    final tree = engine.getSkillTree(widget.subject);
    SkillNode? matchedNode;
    for (final node in tree.nodes.values) {
      // 用名称模糊匹配（如果当前 topic 和节点名相关）
      if (_topic.contains(node.name) || node.name.contains(_topic)) {
        matchedNode = node;
        break;
      }
    }
    List<SkillNode> newlyUnlocked = [];
    if (matchedNode != null) {
      newlyUnlocked = engine.completeSkillNode(
        widget.subject,
        matchedNode.id,
        score / 100.0,
      );
    }

    // ── 记录任务进度 ──
    engine.taskManager.recordAnswer(score >= 60);

    await FileStorageService.save({'engine_data': engine.toJson()});

    _updateLast(msg);
    _answering = false;

    // ── 显示解锁提示 ──
    if (newlyUnlocked.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        UnlockToast.show(
          context,
          newlyUnlocked.map((n) => n.name).toList(),
        );
      });
    }

    // ── 检查升级 ──
    final prevLevel = engine.level;
    engine.checkLevelUp();
    if (engine.level > prevLevel) {
      final xpGained = score; // 简化：得分就是获得的经验
      final unlocks = <String>[];
      if (newlyUnlocked.isNotEmpty) {
        unlocks.addAll(newlyUnlocked.map((n) => '技能：${n.name}'));
      }
      if (unlocks.isEmpty) {
        unlocks.add('继续加油，解锁更多内容！');
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => LevelUpOverlay(
            oldLevel: prevLevel,
            newLevel: engine.level,
            xpGained: xpGained,
            unlocks: unlocks,
            onDismiss: () => Navigator.pop(context),
          ),
        );
      });
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      _addMsg('🎯', '要继续深入讲解「$_topic」的下一个知识点吗？\n回复"继续"或说新的知识点', isAI: true);
    });
  }

  void _handleSubmit() {
    final text = _inputController.text.trim();
    if ((text == '跳过' || text == '看答案' || text == '不会') && _lastQ.isNotEmpty) {
      _skipQuestion();
      return;
    }
    if (_answering) {
      if (InputValidation.isFollowUp(text)) {
        _answering = false;
        _send();
      } else {
        _submitAnswer();
      }
    } else {
      _send();
    }
  }

  /// 快捷短语处理
  void _handleQuickPhrase(String phrase) {
    if (phrase == '跳过这题' && _lastQ.isNotEmpty) {
      _skipQuestion();
      return;
    }
    if (phrase == '下一题') {
      _inputController.text = '下一题';
      _handleSubmit();
      return;
    }
    // 其他短语直接填入输入框
    _inputController.text = phrase;
  }

  void _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;
    final engine = ref.read(studyEngineProvider);
    _inputController.clear();
    _addMsg('👤', text, isAI: false);

    // 预置课程模式：无 API Key 且当前科目有预置课程时，走本地流程
    final isPresetMode = ApiService.apiKey.isEmpty;
    final preset = PresetCourses.findBySubject(widget.subject);
    if (isPresetMode && preset != null) {
      _handlePresetMode(preset, text);
      return;
    }

    if (InputValidation.isOtherSubject(text, widget.subject, engine.subjects)) {
      _addMsg('💡', '「$text」是其他学科。当前在学「${widget.subject}」;\n想学其他学科请返回书架切换。', isAI: true);
      return;
    }

    if ((text == '跳过' || text == '看答案' || text == '不会') && _lastQ.isNotEmpty) {
      _skipQuestion();
      return;
    }

    if (_answering && _lastQ.isNotEmpty) {
      if (text.length < 3 || RegExp(r'^(什么|怎么|如何|为什么|是|有|能)').hasMatch(text)) {
        _addMsg('💡', '请先回答当前的问题：\n$_lastQ\n\n或者输入"跳过"看答案', isAI: true);
        return;
      }
      _submitAnswer();
      return;
    }

    if (text == '继续' || text == '继续学习') {
      _answering = false;
      _addMsg('🤖', '好的！你想深入哪个知识点？或者换一个话题？', isAI: true);
      return;
    }

    if (text == '出题' || text == '来一道题' || text == '出一道题') {
      if (_topic.isNotEmpty) {
        _askQuestion(_topic);
      } else {
        _addMsg('🤖', '先告诉我你想学什么知识点，我再出题', isAI: true);
      }
      return;
    }

    _loading = true;
    _addMsg('🤖', '正在思考...', isAI: true);
    final isFollowUp = InputValidation.isFollowUp(text);
    final result = await ApiService.teach(text,
        mode: engine.studyMode, subject: widget.subject, history: _buildHistory());
    _loading = false;
    if (!result.success) {
      _updateLast('❌ 系统错误\n${result.error}');
      return;
    }
    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ AI返回格式异常');
      return;
    }
    String msg = '📖 **${text}**\n\n';
    msg += '${data['explain'] ?? ''}\n\n';
    // 生活化类比（新字段，有就显示）
    if (data['analogy'] != null && data['analogy'].toString().isNotEmpty) {
      msg += '💡 类比理解：${data['analogy']}\n\n';
    }
    msg += '**🎯 核心要点：**\n';
    if (data['points'] != null) {
      for (final p in data['points']) {
        msg += '  • $p\n';
      }
    }
    msg += '\n🤔 思考题：${data['question'] ?? '你理解了吗？用自己的话说说看'}';
    _updateLast(msg);
    // 存储 teach 返回的答案关键词（如果有，后续 generateQuestion 会覆盖）
    if (data['answerKeys'] != null && (data['answerKeys'] as List).isNotEmpty) {
      _currentAnswerKeys = (data['answerKeys'] as List)
          .map((e) => e.toString())
          .toList();
    }
    if (isFollowUp) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('💡', '还有想继续问的吗？直接说你的问题，或者输"出题"来一道思考题', isAI: true);
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () => _askQuestion(text));
    }
  }

  /// 预置课程模式：完全本地化的「讲解 → 出题 → 评分」流程
  ///
  /// 无 API Key 时使用 [PresetCourses] 内置内容，不调用任何 AI 接口。
  /// 通过 [_presetStep] 跟踪进度：
  ///   0 = 首次发消息，展示讲解 + 出题
  ///   1 = 等待用户作答，调用本地评分
  ///   2 = 评分完成，提示配置 API Key
  void _handlePresetMode(PresetCourse preset, String text) {
    switch (_presetStep) {
      case 0:
        // 1) 本地讲解（模拟 AI 回复格式）
        _addMsg(preset.emoji, preset.explanation, isAI: true);
        // 2) 出题
        Future.delayed(const Duration(milliseconds: 400), () {
          _addMsg('💡', '💡 **思考题**\n\n${preset.question}', isAI: true);
        });
        setState(() {
          _presetStep = 1;
          _topic = preset.topic;
        });
        break;

      case 1:
        // 用户已作答，本地评分
        _addMsg('📊', '系统评分中...', isAI: true);
        final result = PresetCourses.localScore(text, preset.answerKeyPoints);
        final score = result['score'] as int;
        final matched = (result['matched'] as List).cast<String>();
        final missed = (result['missed'] as List).cast<String>();

        String scoreEmoji;
        String scoreLabel;
        String encourageMsg;
        if (score >= 90) {
          scoreEmoji = '🌟';
          scoreLabel = '神级';
          encourageMsg = '太棒了！你已经完全掌握了这个知识点 🎉';
        } else if (score >= 80) {
          scoreEmoji = '🔥';
          scoreLabel = '优秀';
          encourageMsg = '答得很好！差一点就完美了，继续保持！';
        } else if (score >= 60) {
          scoreEmoji = '⭐';
          scoreLabel = '及格';
          encourageMsg = '还不错！再巩固一下薄弱点就能更上一层楼。';
        } else if (score >= 30) {
          scoreEmoji = '📗';
          scoreLabel = '加油';
          encourageMsg = '别灰心，回顾一下要点，我们再来一次！';
        } else {
          scoreEmoji = '💪';
          scoreLabel = '继续努力';
          encourageMsg = '没关系，学习就是不断试错的过程。先看看解析，再试一次！';
        }

        final matchedStr = matched.isNotEmpty ? matched.join('、') : '';
        final missedStr = missed.isNotEmpty ? missed.join('、') : '';

        String msg = '📊 评分结果\n\n';
        msg += '$scoreEmoji 得分：$score / 100  ($scoreLabel)\n\n';
        if (matchedStr.isNotEmpty) msg += '✅ 答对了：$matchedStr\n\n';
        if (missedStr.isNotEmpty) msg += '📌 还需要掌握：$missedStr\n\n';
        msg += '📝 参考答案：\n${preset.referenceAnswer}\n\n';
        msg += '📖 解析：\n${preset.explanationDetail}\n';
        msg += '\n$encourageMsg';
        _updateLast(msg);

        setState(() => _presetStep = 2);
        _scrollToBottom();
        break;

      case 2:
        // 评分已完成，提示配置 API Key 解锁更多
        _addMsg('🎯', '配置 API Key 后，可以学习更多知识点，'
            'AI 会根据你的情况个性化出题', isAI: true);
        break;
    }
  }

  void _skipQuestion() async {
    _currentAnswerKeys = []; // 清空答案关键词
    _addMsg('📚', '正在生成参考答案...', isAI: true);
    final result = await ApiService.skipAnswer(_lastQ, subject: widget.subject);
    if (!result.success) {
      _updateLast('❌ 获取答案失败\n${result.error}');
      return;
    }
    final data = ApiService.parseJson(result);
    if (data == null) {
      _updateLast('❌ AI返回格式异常');
      return;
    }
    final answer = data['answer'] ?? '';
    final explain = data['explain'] ?? '';
    String msg = '📚 **参考答案**\n\n$answer\n';
    if (explain.isNotEmpty) msg += '\n📖 解析：$explain\n';
    // 核心知识点（新字段）
    if (data['keyPoints'] != null && (data['keyPoints'] as List).isNotEmpty) {
      msg += '\n🎯 本题核心知识点：\n';
      for (final kp in data['keyPoints']) {
        msg += '  • $kp\n';
      }
    }
    msg += '\n💪 没关系，跳过很正常，看懂了下次就会了！';
    _updateLast(msg);
    _answering = false;
    Future.delayed(const Duration(milliseconds: 800), () {
      _addMsg('🎯', '要继续深入讲解「$_topic」的下一个知识点吗？\n回复"继续"或说新的知识点', isAI: true);
    });
  }

  List<Map<String, String>> _buildHistory() {
    final hist = <Map<String, String>>[];
    final skipEmojis = {'📋', '🎯', '❌', '📚'};
    for (final m in _messages.reversed) {
      if (hist.length >= 6) break;
      if (skipEmojis.contains(m.emoji)) continue;
      if (m.text.startsWith('【系统') || m.text.startsWith('正在') ||
          m.text.startsWith('📊') || m.text.startsWith('💡')) continue;
      hist.add({
        'role': m.isAI ? 'assistant' : 'user',
        'content': m.text,
      });
    }
    return hist.reversed.toList();
  }

  void _startListening() async {
    if (_isListening) {
      _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize();
    if (!available) {
      _addMsg('❌', '语音识别不可用', isAI: true);
      return;
    }
    setState(() => _isListening = true);
    _speech.listen(
      onResult: (text) {
        _inputController.text = text;
      },
    );
  }

  void _saveToStorage() async {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final engine = ref.read(studyEngineProvider);
        final key = widget.subject.trim();
        if (_messages.isNotEmpty) {
          engine.chatHistory[key] = _cappedMessages();
        }
        await FileStorageService.save({'engine_data': engine.toJson()});
      } catch (_) {
        // 防抖保存失败时忽略，下次输入会再次触发保存
      }
    });
  }

  List<Map<String, dynamic>> _cappedMessages() {
    final list = _messages.map((m) => m.toMap()).toList();
    if (list.length > 50) return list.sublist(list.length - 50);
    return list;
  }

  void _addMsg(String emoji, String text, {bool isAI = true}) {
    setState(() => _messages.add(ChatMsg(emoji: emoji, text: text, isAI: isAI)));
    _saveToStorage();
    _scrollToBottom();
  }

  void _updateLast(String text) {
    if (_messages.isNotEmpty) {
      setState(() => _messages.last.text = text);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showReport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          subject: widget.subject,
        ),
      ),
    );
  }

  void _bookmarkCurrent(String title, String content) {
    final engine = ref.read(studyEngineProvider);
    final exists = engine.bookmarks.any((b) => b.content == content);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📌 已收藏过'),
            backgroundColor: AppTheme.dimGray,
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    engine.addBookmark(widget.subject, title, content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📌 已收藏'),
          backgroundColor: AppTheme.accent,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  /// 预置模式顶部提示条
  Widget _buildPresetBanner() {
    return GestureDetector(
      onTap: _openApiKeySettings,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        color: AppTheme.accent.withValues(alpha: 0.12),
        child: Row(
          children: [
            const Icon(Icons.lock_open, size: 16, color: Color(0xFFf97316)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '体验模式 · 配置 API Key 解锁完整功能',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  /// 打开 API Key 配置页（点击 banner 跳转设置）
  void _openApiKeySettings() {
    final controller = TextEditingController(text: ApiService.apiKey);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApiKeyGuideSheet(
        controller: controller,
        onSaved: (baseUrl) async {
          ApiService.apiKey = controller.text.trim();
          ApiService.customBaseUrl = baseUrl;
          await SecureStorageService.saveApiKey(ApiService.apiKey);
          await SecureStorageService.saveBaseUrl(baseUrl);
          ApiService.clearDetectionCache();
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ApiService.apiKey.isEmpty
                    ? '⚠️ API Key 不能为空'
                    : '✅ API Key 已保存，重新进入即可使用完整功能'),
                backgroundColor: ApiService.apiKey.isEmpty
                    ? Colors.orange
                    : AppTheme.success,
                duration: const Duration(seconds: 2),
              ),
            );
            // 保存后刷新界面，隐藏体验模式 banner
            setState(() {});
          }
        },
        onClosed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(studyEngineProvider);
    final isPresetMode = ApiService.apiKey.isEmpty &&
        PresetCourses.findBySubject(widget.subject) != null;
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text(widget.subject, style: AppTheme.systemTitle),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              _saveToStorage();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('✅ 已保存'),
                  backgroundColor: AppTheme.success,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            tooltip: '保存',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: AppTheme.textSecondary),
            onPressed: _showReport,
          ),
          if (kDemoMode)
            IconButton(
              icon: Icon(Icons.science, color: AppTheme.textSecondary),
              tooltip: '演示模式',
              onPressed: () {
                DemoPanel(engine: engine, subject: widget.subject)
                    .show(context);
              },
            ),
        ],
      ),
      body: Column(
        children: [
          if (isPresetMode) _buildPresetBanner(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) => ChatBubble(
                msg: _messages[i],
                index: i,
                onBookmark: _bookmarkCurrent,
              ),
            ),
          ),
          if (!_loading)
            LearnInputBar(
              controller: _inputController,
              isAnswering: _answering,
              isListening: _isListening,
              onSend: _handleSubmit,
              onMicTap: _startListening,
              onSubmitted: (_) => _handleSubmit(),
              onQuickPhrase: _handleQuickPhrase,
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
        ],
      ),
    );
  }
}
