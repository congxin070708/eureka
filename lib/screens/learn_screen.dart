import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../api_service.dart';
import '../app_theme.dart';
import '../file_storage_service.dart';
import '../review_scheduler.dart';
import '../providers/app_providers.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/learn_input_bar.dart';
import '../widgets/demo_panel.dart';
import '../utils/input_validation.dart';
import 'stats_screen.dart';

/// 学习页面 - 模块化重构后
/// 聊天气泡、输入栏、演示面板、输入验证已抽取为独立模块
/// 状态管理通过 Riverpod(studyEngineProvider) 共享引擎数据
class LearnScreen extends ConsumerStatefulWidget {
  final String subject;
  const LearnScreen({super.key, required this.subject});

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

  // 语音识别
  late stt.SpeechToText _speech;
  bool _isListening = false;

  // 防抖保存
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
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
      } catch (_) {}
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
  }

  void _askQuestion(String topic) async {
    _answering = true;
    _topic = topic;
    final engine = ref.read(studyEngineProvider);
    final mode = engine.studyMode;
    final kpType = mode == '速学' ? 'memory'
        : (mode == '挑战' ? 'procedure' : 'concept');
    engine.getOrCreateKnowledgePoint(
      widget.subject.trim(), topic.trim(),
      type: kpType, importance: _subjectImportance,
    );
    _addMsg('💡', '正在出题...', isAI: true);
    final result = await ApiService.generateQuestion(topic, mode: mode);
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
    String hint = data['hint'] ?? '';
    String msg = '💡 **思考题**\n\n$_lastQ\n';
    if (hint.isNotEmpty) msg += '\n💬 提示：$hint';
    _updateLast(msg);
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
    final result = await ApiService.scoreAnswer(_lastQ, answer);
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
    int score = data['score'] ?? 0;
    String feedback = data['feedback'] ?? '';
    String suggest = data['suggest'] ?? '';
    String missed = '';
    if (data['missed'] != null) {
      missed = (data['missed'] as List).join('、');
    }

    String scoreEmoji;
    if (score >= 90) scoreEmoji = '🌟';
    else if (score >= 70) scoreEmoji = '🔥';
    else if (score >= 50) scoreEmoji = '⭐';
    else scoreEmoji = '📗';

    String msg = '📊 评分结果\n\n';
    msg += '$scoreEmoji 得分：$score/100\n';
    msg += '   (${score >= 90 ? '神级' : score >= 70 ? '优质' : score >= 50 ? '中等' : '基础'})\n\n';
    msg += '📝 反馈：$feedback\n\n';
    if (suggest.isNotEmpty) msg += '💡 建议：$suggest\n';
    if (missed.isNotEmpty) msg += '\n📌 遗漏要点：$missed\n';

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
    await FileStorageService.save({'engine_data': engine.toJson()});

    _updateLast(msg);
    _answering = false;

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

  void _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;
    final engine = ref.read(studyEngineProvider);
    _inputController.clear();
    _addMsg('👤', text, isAI: false);

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
        mode: engine.studyMode, history: _buildHistory());
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
    msg += '**要点：**\n';
    if (data['points'] != null) {
      for (final p in data['points']) {
        msg += '• $p\n';
      }
    }
    _updateLast(msg);
    if (isFollowUp) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('💡', '还有想继续问的吗？直接说你的问题，或者输"出题"来一道思考题', isAI: true);
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () => _askQuestion(text));
    }
  }

  void _skipQuestion() async {
    _addMsg('📚', '正在生成参考答案...', isAI: true);
    final result = await ApiService.skipAnswer(_lastQ);
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
      onResult: (result) {
        _inputController.text = result.recognizedWords;
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
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
      } catch (_) {}
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
    final engine = ref.read(studyEngineProvider);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          engine: engine,
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

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(studyEngineProvider);
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
