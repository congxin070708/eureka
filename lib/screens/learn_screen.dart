import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../api_service.dart';
import '../study_engine.dart';
import '../app_theme.dart';
import '../file_storage_service.dart';
import 'stats_screen.dart';

/// 演示模式开关:构建时用 --dart-define=DEMO_MODE=true 开启(测试/预览版),
/// 正式版(APK release)不传该参数,演示按钮自动消失并被优化掉。
const bool kDemoMode = bool.fromEnvironment('DEMO_MODE');

class LearnScreen extends StatefulWidget {
  final StudyEngine engine;
  final String subject;
  const LearnScreen({super.key, required this.engine, required this.subject});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _messages = <ChatMsg>[];
  final _inputController = TextEditingController();
  bool _loading = false;
  bool _answering = false;
  String _lastQ = '';
  String _topic = '';
  /// 学科代表价值系数(书单最高价值,默认70)
  int _subjectImportance = 70;
  final _scrollController = ScrollController();

  // 语音识别
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // 立即显示"初始化中"，不让用户看到空白页面
    setState(() => _messages.add(ChatMsg(emoji: '⏳', text: '初始化中...', isAI: true)));
    // 从存储加载聊天记录
    _loadMessages();
  }

  void _loadMessages() async {
    // 减少延迟，快速尝试读取
    await Future.delayed(const Duration(milliseconds: 100));
    for (int i = 0; i < 3; i++) {
      try {
        final fileData = await FileStorageService.loadEngineData();
        if (fileData != null) {
          final msgs = fileData['chatHistory']?[widget.subject.trim()];
          if (msgs != null && msgs.isNotEmpty) {
            // 清除"初始化中"消息
            setState(() => _messages.clear());
            for (final m in msgs) {
              _messages.add(ChatMsg(
                emoji: m['emoji'] ?? '',
                text: m['text'] ?? '',
                isAI: m['isAI'] ?? true,
              ));
            }
            widget.engine.chatHistory[widget.subject.trim()] =
                (msgs as List).cast<Map<String, dynamic>>();
            setState(() {});
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
            return;
          }
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    // 读不到，替换"初始化中"为生成提示，然后调AI
    if (_messages.length == 1 && _messages[0].text == '初始化中...') {
      _updateLast('📋 正在准备学习方案...');
    }
    _startSubject();
  }

  @override
  void dispose() {
    // 冲刷未保存的防抖写入，再保存聊天记录
    _saveDebounce?.cancel();
    _saveChatHistory();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _saveChatHistory() async {
    final key = widget.subject.trim();
    if (_messages.isNotEmpty) {
      widget.engine.chatHistory[key] = _cappedMessages();
    }
    await FileStorageService.save({'engine_data': widget.engine.toJson()});
  }

  // ── AI 生成学习路线 + 推荐书单 ──
  // ── 检查是否是正经学科 ──
  bool _isValidSubject(String text) {
    if (text.length < 2) return false;
    // 允许含目的词的输入（考研、期末、竞赛等）
    if (RegExp(r'考研|期末|竞赛|考试|自考|留学|面试|工作|项目|实战').hasMatch(text)) return true;
    // 排除问句
    if (RegExp(r'[?？吗么吧呢呀的怎么什么是如何为什么哪哪些]').hasMatch(text)) return false;
    // 排除命令/请求
    if (RegExp(r'^(帮我|给我|请|介绍|解释|说明|推荐|搜索|查)').hasMatch(text)) return false;
    // 排除乱输
    final hasMeaningfulChar = text.contains(RegExp(
      r'[数学物理化英语文历地政经编程算机网工原逻心哲艺设]'
      r'|学|论|理|法|术|导|程|基|概|原|设|计|管|统|分|析'
    ));
    if (hasMeaningfulChar) return true;
    if (RegExp(r'^(.)\1+$').hasMatch(text)) return false;
    if (text.length <= 4 && RegExp(r'^[顶啊哦嗯哈嘻哇呀哟]+$').hasMatch(text)) return false;
    return true;
  }

  void _startSubject() async {
    if (!_isValidSubject(widget.subject)) {
      _addMsg('⚠️', '【系统】未识别的学科，请输入一个有效的学科名称\n\n'
          '例如：高等数学、英语、编程、物理学...', isAI: true);
      return;
    }
    // 替换"初始化中"或"正在准备"为正式消息
    if (_messages.isNotEmpty && _messages.last.text.contains('初始化')) {
      _updateLast('📋 【系统提示】${widget.subject}\n\n正在生成学习方案...');
    } else {
      _addMsg('📋', '📋 【系统提示】${widget.subject}\n\n正在生成学习方案...', isAI: true);
    }

    // 根据用户输入和学习模式调整 prompt
    final mode = widget.engine.studyMode;
    final input = widget.subject;
    
    // 智能识别用户目的
    String purposeHint = '';
    if (input.contains('考研')) purposeHint = '用户目的是考研，推荐考研辅导书（如张宇、汤家凤、李永乐等），侧重真题和应试技巧。';
    else if (input.contains('四级')) purposeHint = '用户目的是英语四级，推荐四级真题、词汇书、听力材料。';
    else if (input.contains('六级')) purposeHint = '用户目的是英语六级，推荐六级真题、词汇书、听力材料。';
    else if (input.contains('期末')) purposeHint = '用户目的是期末考试，推荐复习资料、重点归纳、习题集。';
    else if (input.contains('竞赛')) purposeHint = '用户目的是学科竞赛，推荐竞赛辅导书、历年真题、进阶教材。';
    else if (input.contains('雅思') || input.contains('托福')) purposeHint = '用户目的是出国留学考试，推荐雅思/托福备考资料。';
    else if (input.contains('自考')) purposeHint = '用户目的是自学考试，推荐自考教材和真题。';
    else if (input.contains('面试')) purposeHint = '用户目的是面试准备，推荐面试题集和实战指南。';
    
    // 带目的+模式提示生成学习路线
    final result = await ApiService.startSubject(widget.subject, extraHint: purposeHint, mode: mode)
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

    // 生成成功 → 加入书架
    widget.engine.getSubject(widget.subject);
    // 保存到文件
    await FileStorageService.save({'engine_data': widget.engine.toJson()});

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

            // 记录学科代表价值系数(书单最高价值)
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

    // 保存书单到文件
    await FileStorageService.save({'engine_data': widget.engine.toJson()});

    // 挑战模式：直接出挑战题，不列话题（追加消息，保留学习路线）
    if (mode == '挑战') {
      if (data['challenge'] != null) {
        final ch = data['challenge'];
        _lastQ = ch['q'] ?? '';
        _topic = widget.subject; // 挑战题也属于当前学科
        String hint = ch['hint'] ?? '';
        String msg = '💡 **挑战题**\n\n$_lastQ\n';
        if (hint.isNotEmpty) msg += '\n💬 提示：$hint';
        Future.delayed(const Duration(milliseconds: 500), () {
          _addMsg('💡', msg, isAI: true);
          _answering = true;
        });
        return;
      }
      // AI没返回挑战题时的兜底：不静默退化，明确提示
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('🎯', '挑战模式未生成挑战题（AI返回格式问题），已退回学习路线。\n输入任意话题名继续学习，或回复"跳过"看参考。', isAI: true);
      });
      return;
    }

    // 列出话题让用户选择，不自启动讲解
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
    _topic = topic; // 记录当前话题,评分/跳过/继续都用它
    // 注册知识点(掌握度门控):话题 → 知识点,类型按学习模式映射
    final mode = widget.engine.studyMode;
    final kpType = mode == '速学' ? 'memory'
        : (mode == '挑战' ? 'procedure' : 'concept');
    widget.engine.getOrCreateKnowledgePoint(
      widget.subject.trim(), topic.trim(),
      type: kpType, importance: _subjectImportance,
    );
    _addMsg('💡', '正在出题...', isAI: true);
    final result = await ApiService.generateQuestion(topic, mode: widget.engine.studyMode);
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
    // 学科名拦截:输入的是其他学科名(想切换学科),提示返回书架,不进评分
    if (_isOtherSubject(answer)) {
      _inputController.clear();
      _addMsg('👤', answer, isAI: false);
      _addMsg('💡', '「$answer」是其他学科。当前在挑战「${widget.subject}」,请回答当前问题;\n想学其他学科请返回书架切换。', isAI: true);
      return;
    }
    // 规则拦截:明显无关的输入(闲聊/纯符号/反问)直接打回,不进评分
    if (_isIrrelevantInput(answer)) {
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

    // 颜色分级的分数展示
    String scoreEmoji;
    if (score >= 90) {
      scoreEmoji = '🌟';
    } else if (score >= 70) {
      scoreEmoji = '🔥';
    } else if (score >= 50) {
      scoreEmoji = '⭐';
    } else {
      scoreEmoji = '📗';
    }

    String msg = '📊 评分结果\n\n';
    msg += '$scoreEmoji 得分：$score/100\n';
    msg += '   (${score >= 90 ? '神级' : score >= 70 ? '优质' : score >= 50 ? '中等' : '基础'})\n\n';
    msg += '📝 反馈：$feedback\n\n';
    if (suggest.isNotEmpty) msg += '💡 建议：$suggest\n';
    if (missed.isNotEmpty) msg += '\n📌 遗漏要点：$missed\n';

    // ── 掌握度门控:记录答题结果,更新掌握度 ──
    final kp = widget.engine.findKnowledgePoint(
        widget.subject.trim(), _topic.trim());
    if (kp != null) {
      final passed = score >= 60;
      final mastery = kp.recordAttempt(passed);
      // 概念/设计型由AI评分≥90判定为"费曼讲解通过"
      if (kp.type == 'concept' || kp.type == 'design') {
        if (score >= 90) kp.qualitativeMastery = true;
      }
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
    await FileStorageService.save({'engine_data': widget.engine.toJson()});

    _updateLast(msg);
    _answering = false;

    // 询问是否继续深入
    Future.delayed(const Duration(milliseconds: 800), () {
      _addMsg('🎯', '要继续深入讲解「$_topic」的下一个知识点吗？\n回复"继续"或说新的知识点', isAI: true);
    });
  }

  /// 统一提交入口:先拦截"跳过/看答案/不会",再按答题状态分发
  void _handleSubmit() {
    final text = _inputController.text.trim();
    // 跳过看答案:不依赖 _answering 状态,只要当前有问题就响应
    if ((text == '跳过' || text == '看答案' || text == '不会') && _lastQ.isNotEmpty) {
      _skipQuestion();
      return;
    }
    if (_answering) {
      // 追问 → 退出答题模式,转自由对话;回答 → 正常评分
      if (_isFollowUp(text)) {
        _answering = false;
        _send();
      } else {
        _submitAnswer();
      }
    } else {
      _send();
    }
  }

  /// 追问识别:输入看起来像"追问/请教"而非"回答问题"
  bool _isFollowUp(String text) {
    final t = text.trim();
    if (t.length < 3) return false;
    // 以问词开头
    if (RegExp(r'^(为什么|怎么|如何|什么是|啥是|是不是|能否|能不能|可以|请|帮我|解释|讲讲|说明|举个例子)').hasMatch(t)) return true;
    // 含追问特征词
    if (RegExp(r'(是什么意思|怎么理解|怎么用|为什么|能不能再|再讲讲|详细说说|展开讲讲)').hasMatch(t)) return true;
    // 以问号结尾
    if (t.endsWith('?') || t.endsWith('？')) return true;
    return false;
  }

  /// 学科名识别:输入是否为其他学科名(整词匹配,避免误伤"英语语法"这类组合)
  bool _isOtherSubject(String text) {
    final t = text.trim();
    if (t.isEmpty) return false;
    // 书架里已有的其他学科
    for (final s in widget.engine.subjects.keys) {
      if (s != widget.subject && t == s) return true;
    }
    // 常见学科名单(整词匹配)
    const common = ['英语', '数学', '物理', '化学', '生物', '历史', '地理', '政治',
      '语文', '编程', '计算机', '高数', '线代', '概率论', '经济学', '心理学',
      '哲学', '法学', '医学', '艺术', '设计', 'C语言', 'Python', 'Java'];
    if (common.contains(t)) return true;
    return false;
  }

  /// 规则拦截:判断输入是否明显与问题无关(闲聊/纯符号/反问/超短)
  bool _isIrrelevantInput(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    // 纯符号/表情/无意义字符
    if (!RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(t)) return true;
    // 闲聊/敷衍词
    if (RegExp(r'^(你好|哈哈|呵呵|好的|嗯|哦|知道|不知道|谢谢|不错|666|nb|行|可以|对|是|随便|不会|没想好|跳过|看答案)$',
        caseSensitive: false).hasMatch(t)) return true;
    // 太短(<3字)视为敷衍
    if (t.length < 3) return true;
    return false;
  }

  void _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _loading) return;
    _inputController.clear();
    _addMsg('👤', text, isAI: false);

    // 学科名拦截(自由对话/普通输入):想切换学科请返回书架
    if (_isOtherSubject(text)) {
      _addMsg('💡', '「$text」是其他学科。当前在学「${widget.subject}」;\n想学其他学科请返回书架切换。', isAI: true);
      return;
    }

    // 跳过看答案：不依赖 _answering 状态，只要当前有问题就响应
    if ((text == '跳过' || text == '看答案' || text == '不会') && _lastQ.isNotEmpty) {
      _skipQuestion();
      return;
    }

    // 如果当前在回答模式，检查是否答非所问
    if (_answering && _lastQ.isNotEmpty) {
      // 简单判断：如果用户输入太短或是学科名而非回答，提示请回答问题
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

    // 自由对话中主动要求出题
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
    // 判断是追问还是新话题(追问 → 只讲解不出题,保持对话)
    final isFollowUp = _isFollowUp(text);
    // 简单教学对话（带模式+上下文记忆）
    final result = await ApiService.teach(text,
        mode: widget.engine.studyMode, history: _buildHistory());
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
      // 追问：保持对话,不出题,鼓励继续问
      Future.delayed(const Duration(milliseconds: 500), () {
        _addMsg('💡', '还有想继续问的吗？直接说你的问题，或者输"出题"来一道思考题', isAI: true);
      });
    } else {
      Future.delayed(const Duration(seconds: 1), () => _askQuestion(text));
    }
  }

  /// 跳过当前问题，请求AI给参考答案
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

  /// 从最近对话构建上下文（最多6条，跳过系统提示）
  List<Map<String, String>> _buildHistory() {
    final hist = <Map<String, String>>[];
    final skipEmojis = {'📋', '🎯', '❌', '📚'};
    for (final m in _messages.reversed) {
      if (hist.length >= 6) break;
      // 跳过系统提示/学习路线/提问引导，保留讲解和问答
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

  // ── 核心持久化方案 ──
  // 每次消息变化时防抖保存到文件（800ms 内合并多次写入）
  Timer? _saveDebounce;

  void _saveToStorage() async {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 800), () async {
      try {
        final key = widget.subject.trim();
        if (_messages.isNotEmpty) {
          widget.engine.chatHistory[key] = _cappedMessages();
        }
        await FileStorageService.save({'engine_data': widget.engine.toJson()});
      } catch (_) {}
    });
  }

  /// 聊天记录上限 50 条，避免文件无限膨胀
  List<Map<String, dynamic>> _cappedMessages() {
    final list = _messages
        .map((m) => {'emoji': m.emoji, 'text': m.text, 'isAI': m.isAI})
        .toList();
    if (list.length > 50) return list.sublist(list.length - 50);
    return list;
  }

  // build 时从存储恢复聊天记录
  void _addMsg(String emoji, String text, {bool isAI = true}) {
    setState(() => _messages.add(ChatMsg(emoji: emoji, text: text, isAI: isAI)));
    _saveToStorage(); // 异步保存，不等待
    _scrollToBottom();
  }

  void _updateLast(String text) {
    if (_messages.isNotEmpty) {
      setState(() => _messages.last.text = text);
    }
  }

  void _scrollToBottom() {
    Future.delayed(      Duration(milliseconds: 100), () {
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
          engine: widget.engine,
          subject: widget.subject,
        ),
      ),
    );
  }

  /// 演示模式:模拟答题,不调 API 直接看掌握度变化(测试/演示用)
  void _showDemoPanel() {
    if (!kDemoMode) return; // 正式版永远不可达(编译期常量,release被优化)
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final sub = widget.engine.getSubject(widget.subject.trim());
          final kps = sub.knowledgePoints;
          return Padding(
            padding:       EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.science, color: AppTheme.accent, size: 18),
                    SizedBox(width: 8),
                    Text('🧪 演示模式 · 模拟答题',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  ],
                ),
                const SizedBox(height: 4),
                      Text('不调AI,直接模拟答对/答错,看掌握度如何变化',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                const SizedBox(height: 12),
                if (kps.isEmpty)
                        Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('还没有知识点\n先学一个话题(输入话题名→讲解→出题)才会生成',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6)),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: kps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final kp = kps[i];
                        final pct = (kp.mastery * 100).round();
                        final gatePct = (kp.gateThreshold * 100).round();
                        final status = kp.isMastered
                            ? '✅ 已掌握'
                            : '⏳ ${pct}%/${gatePct}%';
                        return Container(
                          padding:       EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kp.isMastered ?       Color(0xFF22c55e).withValues(alpha: 0.4) : AppTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${kp.name}  $status',
                                      style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                                    SizedBox(height: 4),
                              // 掌握度进度条
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: kp.mastery,
                                  minHeight: 4,
                                  backgroundColor: AppTheme.border,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    kp.isMastered ?       Color(0xFF22c55e) : AppTheme.accent),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _demoBtn('答对', const Color(0xFF22c55e), () {
                                    kp.recordAttempt(true);
                                    setSheetState(() {});
                                  }),
                                  const SizedBox(width: 6),
                                  _demoBtn('答错', const Color(0xFFef4444), () {
                                    kp.recordAttempt(false);
                                    setSheetState(() {});
                                  }),
                                        SizedBox(width: 6),
                                  _demoBtn('重置', AppTheme.textSecondary, () {
                                    kp.attempts.clear();
                                    kp.consecutiveCorrect = 0;
                                    kp.consecutiveWrong = 0;
                                    setSheetState(() {});
                                  }),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _demoBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── 收藏当前讲解/评分 ──
  void _bookmarkCurrent(String title, String content) {
    // 防重复收藏：检查是否已存在相同内容
    final exists = widget.engine.bookmarks.any((b) => b.content == content);
    if (exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📌 已收藏过'),
            backgroundColor: Color(0xFF888888),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }
    widget.engine.addBookmark(widget.subject, title, content);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
          content: Text('📌 已收藏'),
          backgroundColor: AppTheme.accent,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text(
          widget.subject,
          style: AppTheme.systemTitle,
        ),
        actions: [
          // 保存按钮
          IconButton(
            icon: Icon(Icons.save, color: AppTheme.textSecondary, size: 20),
            onPressed: () {
              _saveToStorage();
              ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✅ 已保存'), backgroundColor: Color(0xFF22c55e), duration: Duration(seconds: 1)),
              );
            },
            tooltip: '保存',
          ),
          IconButton(
            icon: Icon(Icons.bar_chart, color: AppTheme.textSecondary),
            onPressed: _showReport,
          ),
          // 演示模式:模拟答题,看掌握度变化(仅测试/预览版)
          if (kDemoMode)
            IconButton(
              icon: Icon(Icons.science, color: AppTheme.textSecondary),
              tooltip: '演示模式',
              onPressed: _showDemoPanel,
            ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return _buildMessageBubble(m, i);
              },
            ),
          ),
          // 输入区
          if (!_loading)
            Container(
              padding:       EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      maxLines: 3,
                      minLines: 1,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                      decoration: InputDecoration(
                        hintText: _answering ? '用你自己的话回答...' : '输入你的想法...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary),
                        filled: true,
                        fillColor: AppTheme.surfaceLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onSubmitted: (_) => _handleSubmit(),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _startListening,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _isListening ?       Color(0xFFef4444) : AppTheme.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _isListening ? Icons.mic : Icons.mic_none,
                        color: _isListening ? Colors.white : AppTheme.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                        SizedBox(width: 6),
                  GestureDetector(
                    onTap: _handleSubmit,
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppTheme.accent, AppTheme.accentLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            )
          else
                  Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(
                backgroundColor: AppTheme.border,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMsg m, int index) {
    // 检测系统消息（含【】前缀）
    final isSystem = m.text.startsWith('📋') || m.text.startsWith('📖') ||
        m.text.startsWith('💡') || m.text.startsWith('📊') ||
        m.text.startsWith('🎯') || m.text.startsWith('❌');

    if (m.isAI) {
      if (isSystem) {
        // 系统面板风格
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            width: double.infinity,
            padding:       EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(
                  m.text,
                  style: TextStyle(
                    fontSize: 14, color: AppTheme.textPrimary, height: 1.7,
                    fontFamily: 'monospace',
                  ),
                ),
                // 可收藏的消息显示收藏按钮
                if (m.text.startsWith('📖') || m.text.startsWith('📊'))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: GestureDetector(
                      onTap: () {
                        // 取前30字做标题（安全截取，避免短文本崩溃）
                        final cleaned = m.text
                            .replaceAll(RegExp(r'[*#\n]'), '')
                            .trim();
                        final title = cleaned.length > 30
                            ? cleaned.substring(0, 30)
                            : cleaned;
                        _bookmarkCurrent(title, m.text);
                      },
                      child: Container(
                        padding:       EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 14, color: AppTheme.accentLight),
                            SizedBox(width: 4),
                            Text('收藏',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentLight)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }
      // 普通AI消息
      return Padding(
        padding:       EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.accent, AppTheme.accentLight],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Text(m.emoji, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:       EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius:       BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: SelectableText(
                  m.text,
                  style: TextStyle(fontSize: 14, color: AppTheme.textPrimary, height: 1.7),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 用户消息
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding:       EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(4),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(14),
                  ),
                ),
                child: Text(m.text, style: const TextStyle(fontSize: 14, color: Colors.white, height: 1.7)),
              ),
            ),
                  SizedBox(width: 8),
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                border: Border.all(color: AppTheme.border),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(child: Text('👤', style: TextStyle(fontSize: 14))),
            ),
          ],
        ),
      );
    }
  }
}

// ── 聊天消息模型 ──
class ChatMsg {
  final String emoji;
  String text;
  final bool isAI;
  ChatMsg({required this.emoji, required this.text, required this.isAI});
}
