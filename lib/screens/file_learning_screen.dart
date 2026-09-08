import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../app_theme.dart';
import '../api_service.dart';
import '../smart_content_detector.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/smart_learning_panel.dart';
import '../voice_service.dart';

/// 智能文件学习页面 - 自动识别内容类型，匹配最佳学习模式
///
/// 支持内容类型：
/// - 学术论文 → 两阶段深度学习（结构→内容）
/// - 代码文件 → 逐函数精读
/// - 教材章节 → 概念→例题→习题
/// - 技术文档 → 接口→示例→注意事项
/// - 普通文章 → 主旨→细节→启发
class FileLearningScreen extends ConsumerStatefulWidget {
  const FileLearningScreen({super.key});

  @override
  ConsumerState<FileLearningScreen> createState() => _FileLearningScreenState();
}

class _FileLearningScreenState extends ConsumerState<FileLearningScreen> {
  // 智能学习状态
  ContentTypeDetection? _detection;
  List<ContentSegment> _segments = [];
  LearningPhase _currentPhase = LearningPhase.detail;
  int _currentIndex = 0;

  // 聊天/答题状态
  final _messages = <ChatMsg>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _answering = false;
  String _currentQuestion = '';
  String _fileName = '';
  String _fileContent = '';

  // 语音识别
  late stt.SpeechToText _speech;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'dart', 'py', 'js', 'ts', 'java', 'cpp', 'c', 'h',
        'go', 'rs', 'rb', 'php', 'swift', 'kt', 'scala',
        'html', 'css', 'json', 'yaml', 'yml', 'xml',
        'txt', 'md', 'sh', 'sql', 'pdf', 'doc', 'docx',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final content = utf8.decode(file.bytes ?? []);
    final fileName = file.name;

    setState(() {
      _loading = true;
      _messages.clear();
      _fileName = fileName;
      _fileContent = content;
    });

    // 智能检测内容类型
    final detection = SmartContentDetector.detect(content, fileName);
    final config = LearningModeLibrary.get(detection.type);
    final segments = SmartSegmentationService.segment(content, fileName, detection.type);

    setState(() {
      _detection = detection;
      _segments = segments;
      _currentPhase = config.phases.first;
      _currentIndex = 0;
      _loading = false;
    });

    final typeName = SmartContentDetector.typeName(detection.type);
    final confidence = (detection.confidence * 100).toStringAsFixed(0);

    _addMsg('🤖', '📊 **内容智能识别**\n\n'
        '**类型**: ${config.icon} ${config.modeName}\n'
        '**置信度**: $confidence%\n'
        '**分段数**: ${segments.length} 段\n\n'
        '${config.description}\n\n'
        '准备好了吗？我们开始学习！', isAI: true);

    // 延迟开始
    Future.delayed(const Duration(milliseconds: 1000), () {
      _startCurrentSegment();
    });
  }

  /// 开始当前段的学习
  Future<void> _startCurrentSegment() async {
    if (_detection == null || _segments.isEmpty) return;

    setState(() {
      _loading = true;
      _answering = false;
      _currentQuestion = '';
    });

    final seg = _segments[_currentIndex];
    final typeName = SmartContentDetector.typeName(_detection!.type);

    _addMsg('📖', '正在分析第 ${_currentIndex + 1} 段「${seg.title}」...', isAI: true);

    final prompt = SmartPromptGenerator.buildExplainPrompt(
      type: _detection!.type,
      segment: seg,
      fileName: _fileName,
      phase: _currentPhase,
      index: _currentIndex + 1,
      total: _segments.length,
    );

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位优秀的学习导师，擅长用通俗的语言和生活类比来讲解知识。',
    );

    if (!result.success) {
      _updateLast('❌ ${result.error}');
      setState(() => _loading = false);
      return;
    }

    // 如果是概览阶段且第一段，展示完整结构分析
    if (_currentPhase == LearningPhase.overview && _currentIndex == 0) {
      final overviewPrompt = SmartPromptGenerator.buildOverviewPrompt(
        type: _detection!.type,
        content: _fileContent,
        fileName: _fileName,
        segments: _segments,
      );

      _updateLast(result.content);

      // 再请求一个整体概览
      final overviewResult = await ApiService.chat(
        overviewPrompt,
        systemPrompt: '你是一位资深学习导师。',
      );

      if (overviewResult.success) {
        _addMsg('🗺️', '📋 **整体概览**\n\n${overviewResult.content}', isAI: true);
      }
    } else {
      _updateLast(result.content);
    }

    setState(() => _loading = false);
    _scrollToBottom();

    // 延迟出题
    Future.delayed(const Duration(milliseconds: 600), () {
      _askQuestion();
    });
  }

  /// 出题
  Future<void> _askQuestion() async {
    if (_detection == null || _segments.isEmpty) return;

    setState(() => _loading = true);
    _addMsg('🤔', '正在出题...', isAI: true);

    final prompt = SmartPromptGenerator.buildQuestionPrompt(
      type: _detection!.type,
      segment: _segments[_currentIndex],
      phase: _currentPhase,
    );

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位擅长出思考题的老师。',
    );

    if (!result.success) {
      _updateLast('❌ ${result.error}');
      setState(() => _loading = false);
      return;
    }

    final data = ApiService.parseJson(result);
    String question;
    List<String> keyPoints = [];

    if (data != null && data['question'] != null) {
      question = data['question'] as String;
      keyPoints = (data['keyPoints'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      _currentQuestion = question;

      final diff = (data['difficulty'] as String?) ?? 'medium';
      final diffEmoji = switch (diff) {
        'easy' => '🟢',
        'medium' => '🟡',
        'hard' => '🔴',
        _ => '⚪',
      };

      _updateLast('💡 **思考题** $diffEmoji\n\n$question\n\n'
          '${keyPoints.isNotEmpty ? "考察点：${keyPoints.join('、')}" : ""}'
          '\n\n用你自己的话回答，想到什么说什么！');
    } else {
      _currentQuestion = result.content;
      _updateLast('💡 **思考题**\n\n${result.content}');
    }

    setState(() {
      _loading = false;
      _answering = true;
    });
    _scrollToBottom();
  }

  /// 提交答案
  Future<void> _submitAnswer() async {
    if (_detection == null || !_answering) return;
    final answer = _inputController.text.trim();
    if (answer.isEmpty) return;

    _addMsg('✍️', answer, isAI: false);
    _inputController.clear();
    setState(() {
      _loading = true;
      _answering = false;
    });

    _addMsg('📝', '正在批改...', isAI: true);

    // 使用通用评分 prompt
    final evalPrompt = '''
你是一位严格但友善的学习导师。

学习内容类型：${SmartContentDetector.typeName(_detection!.type)}
当前阶段：${_phaseName(_currentPhase)}
学习段落：${_segments[_currentIndex].title}

题目：$_currentQuestion

学生的回答：
$answer

段落内容：
${_segments[_currentIndex].content.length > 1500 ? _segments[_currentIndex].content.substring(0, 1500) + '...' : _segments[_currentIndex].content}

请评估学生的回答，评分标准：
- 准确性（30分）：核心观点是否正确
- 深度（30分）：是否有深入思考，不只是表面
- 完整性（20分）：是否覆盖了关键点
- 表达（10分）：是否用自己的话清晰表达
- 批判性思维（10分）：是否有独立见解

请用 JSON 返回：
{
  "score": 0-100的整数,
  "feedback": "具体反馈，先肯定再指出不足，给出提升建议",
  "correctAnswer": "参考答案要点",
  "breakdown": {
    "accuracy": 得分,
    "depth": 得分,
    "completeness": 得分,
    "expression": 得分,
    "criticalThinking": 得分
  },
  "mastered": true/false（70分以上为true）
}

反馈语气要鼓励。只输出 JSON。''';

    final result = await ApiService.chat(
      evalPrompt,
      systemPrompt: '你是一位严格但友善的学习导师。',
    );

    if (!result.success) {
      _updateLast('❌ ${result.error}');
      setState(() => _loading = false);
      return;
    }

    final data = ApiService.parseJson(result);
    int score = 0;
    String feedback = result.content;
    bool mastered = false;

    if (data != null) {
      score = (data['score'] as num?)?.toInt() ?? 0;
      feedback = data['feedback']?.toString() ?? result.content;
      mastered = data['mastered'] as bool? ?? false;

      // 更新掌握度
      _segments[_currentIndex].mastery = score / 100.0;
    }

    final scoreColor = score >= 80
        ? const Color(0xFF22c55e)
        : score >= 60
            ? const Color(0xFFf59e0b)
            : const Color(0xFFef4444);

    final scoreEmoji = score >= 80
        ? '🎉'
        : score >= 70
            ? '👍'
            : '💪';

    _updateLast('$scoreEmoji **得分：$score 分**\n\n'
        '$feedback\n\n'
        '${mastered ? "✅ 这段内容你已经掌握了！可以进入下一段。" : "📝 建议再复习一下讲解内容，然后重新回答。"}');

    setState(() => _loading = false);
    _scrollToBottom();
  }

  /// 跳转到指定段落
  void _goToSegment(int index) {
    if (index < 0 || index >= _segments.length) return;
    setState(() {
      _currentIndex = index;
      _answering = false;
      _currentQuestion = '';
    });
    _startCurrentSegment();
  }

  /// 下一段
  void _nextSegment() {
    if (_currentIndex < _segments.length - 1) {
      _goToSegment(_currentIndex + 1);
    }
  }

  /// 推进到下一阶段
  void _advancePhase() {
    if (_detection == null) return;
    final config = LearningModeLibrary.get(_detection!.type);
    final currentIdx = config.phases.indexOf(_currentPhase);
    if (currentIdx < config.phases.length - 1) {
      setState(() {
        _currentPhase = config.phases[currentIdx + 1];
        _currentIndex = 0;
        _answering = false;
        _currentQuestion = '';
        _messages.clear();
      });

      final nextPhaseName = _phaseName(_currentPhase);
      _addMsg('🎯', '✨ **进入$nextPhaseName阶段**\n\n'
          '现在我们${_phaseHint(_currentPhase)}', isAI: true);

      Future.delayed(const Duration(milliseconds: 800), () {
        _startCurrentSegment();
      });
    }
  }

  /// 检查是否可以推进阶段
  bool get _canAdvancePhase {
    if (_detection == null) return false;
    final config = LearningModeLibrary.get(_detection!.type);
    final currentIdx = config.phases.indexOf(_currentPhase);
    if (currentIdx >= config.phases.length - 1) return false;

    // 当前阶段完成度 >= 70% 可以进入下一阶段
    final learnedCount = _segments.where((s) => s.mastery >= 0.7).length;
    return learnedCount / _segments.length >= 0.7;
  }

  double get _overallProgress {
    if (_segments.isEmpty) return 0.0;
    return _segments.map((s) => s.mastery).reduce((a, b) => a + b) / _segments.length;
  }

  String _phaseName(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return '结构概览';
      case LearningPhase.detail: return '内容精读';
      case LearningPhase.practice: return '练习巩固';
      case LearningPhase.review: return '总结回顾';
    }
  }

  String _phaseHint(LearningPhase phase) {
    switch (phase) {
      case LearningPhase.overview: return '先了解整体框架和结构';
      case LearningPhase.detail: return '深入学习每一部分的核心内容';
      case LearningPhase.practice: return '通过练习来检验和巩固所学';
      case LearningPhase.review: return '串联总结，形成完整的知识体系';
    }
  }

  // ── 语音输入 ──
  void _startListening() async {
    if (_isListening) {
      await _speech.stop();
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
        if (result.finalResult) {
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      localeId: 'zh-CN',
    );
  }

  // ── 辅助方法 ──
  void _addMsg(String emoji, String text, {bool isAI = true}) {
    setState(() => _messages.add(ChatMsg(emoji: emoji, text: text, isAI: isAI)));
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

  @override
  Widget build(BuildContext context) {
    final hasData = _detection != null && _segments.isNotEmpty;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: hasData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  Text(
                    '${LearningModeLibrary.get(_detection!.type).modeName} · '
                    '${(_overallProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              )
            : Text('智能学习',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
        actions: [
          if (hasData)
            IconButton(
              icon: Icon(Icons.description_outlined, color: AppTheme.textSecondary),
              tooltip: '查看原文',
              onPressed: _showOriginalText,
            ),
        ],
      ),
      body: !hasData
          ? _buildEmptyState()
          : Row(
              children: [
                // 左侧学习面板
                SmartLearningPanel(
                  detection: _detection!,
                  currentPhase: _currentPhase,
                  segments: _segments,
                  currentIndex: _currentIndex,
                  overallProgress: _overallProgress,
                  onSegmentTap: _goToSegment,
                  onAdvancePhase: _canAdvancePhase ? _advancePhase : null,
                ),
                // 右侧学习内容区
                Expanded(child: _buildLearningView()),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.2),
                  AppTheme.accentLight.withValues(alpha: 0.05),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text('🧠', style: TextStyle(fontSize: 56)),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'AI 智能学习',
            style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            '自动识别内容类型，匹配最佳学习模式',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          // 支持的类型展示
          _buildTypeCards(),
          const SizedBox(height: 36),
          SizedBox(
            width: 260,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.upload_file, size: 22),
              label: const Text(
                '选择文件开始学习',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '支持论文、代码、教材、文档、文章等多种类型',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCards() {
    final types = [
      ('📄', '论文', '两阶段深度学习'),
      ('💻', '代码', '逐函数精读'),
      ('📚', '教材', '概念→例题→习题'),
      ('📖', '文档', '实用导向学习'),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: types.map((t) {
        return Container(
          width: 110,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.$1, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(t.$2,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(t.$3,
                  style: TextStyle(
                      fontSize: 10, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLearningView() {
    return Column(
      children: [
        // 阶段横幅
        PhaseBanner(
          contentType: _detection!.type,
          currentPhase: _currentPhase,
          totalSegments: _segments.length,
          currentSegment: _currentIndex,
          canAdvancePhase: _canAdvancePhase,
          onAdvancePhase: _advancePhase,
        ),
        // 聊天区
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: _messages.length,
            itemBuilder: (_, i) => ChatBubble(
              msg: _messages[i],
              index: i,
              onBookmark: (title, content) {},
            ),
          ),
        ),
        // 输入区
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    final isAnswering = _answering;
    final hasNext = _currentIndex < _segments.length - 1;
    final currentMastery = _currentIndex < _segments.length
        ? _segments[_currentIndex].mastery
        : 0.0;
    final isMastered = currentMastery >= 0.7;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷操作
          if (!isAnswering) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _startCurrentSegment,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.menu_book_outlined,
                        size: 17, color: AppTheme.textSecondary),
                    label: Text('再讲一遍',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _askQuestion,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.help_outline,
                        size: 17, color: AppTheme.textSecondary),
                    label: Text('再出一题',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ),
                ),
                if (hasNext && isMastered) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextSegment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.taskDone,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 17),
                      label: const Text('下一段',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          // 输入框
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _inputController,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: isAnswering
                        ? '用你自己的话回答，想到什么说什么...'
                        : '输入你的想法或问题...',
                    hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.7),
                        fontSize: 14),
                    filled: true,
                    fillColor: AppTheme.surfaceLight,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppTheme.accent, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                  ),
                  onSubmitted: (_) => _answering ? _submitAnswer() : null,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              // 语音输入按钮
              GestureDetector(
                onTap: _startListening,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? const Color(0xFFef4444)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _isListening
                            ? const Color(0xFFef4444)
                            : AppTheme.border),
                  ),
                  child: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening
                        ? Colors.white
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 发送按钮
              GestureDetector(
                onTap: _answering ? _submitAnswer : () {},
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 16,
            child: Text(
              isAnswering
                  ? '💡 用自己的话回答，即使不确定也没关系，AI 会帮你纠正'
                  : '💡 可以问问题、让 AI 再讲一遍、或者出一道新题',
              style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary.withValues(alpha: 0.8)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showOriginalText() {
    if (_segments.isEmpty) return;
    final seg = _segments[_currentIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        seg.title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: SelectableText(
                      seg.content,
                      style: TextStyle(
                        fontFamily: seg.segmentType == 'function' ||
                                seg.segmentType == 'class' ||
                                seg.segmentType == 'code'
                            ? 'monospace'
                            : null,
                        fontSize: 13,
                        color: AppTheme.textPrimary,
                        height: 1.7,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
