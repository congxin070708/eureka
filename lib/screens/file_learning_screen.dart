import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../app_theme.dart';
import '../api_service.dart';
import '../file_learning_service.dart';
import '../file_content_extractor.dart';
import '../widgets/chat_bubble.dart';

/// 文件学习页面 - 逐段理解代码/文档
///
/// 流程:
/// 1. 选择文件 → 自动分段
/// 2. 逐段学习：AI讲解 → AI出题 → 用户口述回答 → AI评分反馈
/// 3. 全部学完后有总评
class FileLearningScreen extends ConsumerStatefulWidget {
  const FileLearningScreen({super.key});

  @override
  ConsumerState<FileLearningScreen> createState() => _FileLearningScreenState();
}

class _FileLearningScreenState extends ConsumerState<FileLearningScreen> {
  FileLearningProgress? _progress;
  final _messages = <ChatMsg>[];
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _loading = false;
  bool _answering = false;
  String _currentQuestion = '';

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
        'go', 'rs', 'rb', 'php', 'swift', 'kt',
        'html', 'css', 'json', 'yaml', 'yml',
        'txt', 'md', 'sh', 'sql',
        'pdf', 'docx', 'xlsx', 'pptx',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;
    late final String content;
    try {
      content = await FileContentExtractor.extractFromBytes(
          fileName, file.bytes ?? Uint8List(0));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('文件解析失败：$e'),
              backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
      return;
    }

    setState(() {
      _loading = true;
      _messages.clear();
    });

    // 分段
    final chunks = FileLearningService.splitContent(content, fileName);

    setState(() {
      _progress = FileLearningProgress(
        fileName: fileName,
        content: content,
        chunks: chunks,
      );
      _loading = false;
    });

    _addMsg('📁', '已加载文件 **$fileName**\n\n'
        '共 ${chunks.length} 段，我们一段一段来理解。\n\n'
        '每段的学习流程：\n'
        '1️⃣ AI 先给你讲解这段代码\n'
        '2️⃣ 然后出一道思考题，你用自己的话回答\n'
        '3️⃣ AI 给你评分和反馈\n'
        '4️⃣ 觉得没问题了就进入下一段\n\n'
        '准备好了吗？我们开始第一段！', isAI: true);

    // 延迟一下开始第一段
    Future.delayed(const Duration(milliseconds: 800), () {
      _explainCurrentChunk();
    });
  }

  Future<void> _explainCurrentChunk() async {
    if (_progress == null) return;
    final prog = _progress!;

    setState(() {
      _loading = true;
      _answering = false;
      _currentQuestion = '';
    });

    _addMsg('📖', '正在分析第 ${prog.currentChunkIndex + 1} 段...', isAI: true);

    final prompt = FileLearningService.buildExplainPrompt(
      prog.currentChunk,
      prog.fileName,
      prog.currentChunkIndex + 1,
      prog.totalChunks,
    );

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位耐心的编程老师，擅长用通俗的语言和生活类比来讲解代码。',
    );

    if (!result.success) {
      _updateLast('❌ ${result.error}');
      setState(() => _loading = false);
      return;
    }

    _updateLast(result.content);

    setState(() => _loading = false);
    _scrollToBottom();

    // 延迟一会儿然后出题
    Future.delayed(const Duration(milliseconds: 500), () {
      _askQuestion();
    });
  }

  Future<void> _askQuestion() async {
    if (_progress == null) return;
    final prog = _progress!;

    setState(() => _loading = true);

    _addMsg('🤔', '正在出题...', isAI: true);

    final prompt = FileLearningService.buildQuestionPrompt(
      prog.currentChunk,
      prog.fileName,
      prog.currentChunkIndex + 1,
      prog.totalChunks,
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

    // 尝试解析 JSON
    final data = ApiService.parseJson(result);
    String question;
    if (data != null && data['question'] != null) {
      question = data['question'] as String;
      final keyPoints = (data['keyPoints'] as List?)
          ?.map((e) => e.toString())
          .toList() ?? [];
      _currentQuestion = question;
      _updateLast('💡 **思考题**\n\n$question\n\n'
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

  Future<void> _submitAnswer() async {
    if (_progress == null || !_answering) return;
    final answer = _inputController.text.trim();
    if (answer.isEmpty) return;

    _addMsg('✍️', answer, isAI: false);
    _inputController.clear();
    setState(() {
      _loading = true;
      _answering = false;
    });

    _addMsg('📝', '正在批改...', isAI: true);

    final prompt = FileLearningService.buildEvaluatePrompt(
      _progress!.currentChunk,
      _currentQuestion,
      answer,
      _progress!.fileName,
    );

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是一位严格但友善的编程老师。',
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

      // 更新得分
      _progress!.setScore(score / 100.0);
    }

    final scoreEmoji = score >= 80
        ? '🎉'
        : score >= 60
            ? '👍'
            : '💪';

    _updateLast('$scoreEmoji **得分：$score 分**\n\n'
        '$feedback\n\n'
        '${mastered ? "✅ 这段代码你已经掌握了！" : "📝 建议再复习一下讲解内容，然后重新回答。"}');

    setState(() => _loading = false);
    _scrollToBottom();
  }

  void _nextChunk() {
    if (_progress == null || !_progress!.hasNext) return;
    _progress!.nextChunk();
    setState(() {
      _answering = false;
      _currentQuestion = '';
    });
    _explainCurrentChunk();
  }

  void _prevChunk() {
    if (_progress == null || !_progress!.hasPrev) return;
    _progress!.prevChunk();
    setState(() {
      _answering = false;
      _currentQuestion = '';
    });
    _explainCurrentChunk();
  }

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
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: _progress != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progress!.fileName,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary),
                  ),
                  Text(
                    '第 ${_progress!.currentChunkIndex + 1} / ${_progress!.totalChunks} 段 · '
                    '总进度 ${(_progress!.progress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                ],
              )
            : Text('文件学习',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
        actions: [
          if (_progress != null)
            IconButton(
              icon: Icon(Icons.code, color: AppTheme.textSecondary),
              tooltip: '查看当前段代码',
              onPressed: _showCurrentChunk,
            ),
        ],
      ),
      body: _progress == null
          ? _buildEmptyState()
          : _buildLearningView(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📚', style: TextStyle(fontSize: 72)),
          const SizedBox(height: 24),
          Text(
            '逐段学习代码',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            '上传代码文件，AI 带你一段一段读懂',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 240,
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
                '选择文件',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '支持 .dart .py .js .ts .java .go .cpp .rs .md .txt 等',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningView() {
    return Column(
      children: [
        // 进度条
        if (_progress != null)
          LinearProgressIndicator(
            value: _progress!.progress,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
            minHeight: 3,
          ),
        // 段导航
        if (_progress != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.surfaceLight,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: AppTheme.textSecondary),
                  onPressed: _progress!.hasPrev ? _prevChunk : null,
                ),
                Expanded(
                  child: Text(
                    '第 ${_progress!.currentChunkIndex + 1} 段 / 共 ${_progress!.totalChunks} 段',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  onPressed: _progress!.hasNext ? _nextChunk : null,
                ),
              ],
            ),
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
        if (!_loading)
          _buildInputBar()
        else
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildInputBar() {
    final isAnswering = _answering;
    final hasNext = _progress?.hasNext ?? false;
    final currentScore = _progress != null &&
            _progress!.currentChunkIndex < _progress!.chunkScores.length
        ? _progress!.chunkScores[_progress!.currentChunkIndex]
        : 0.0;
    final isMastered = currentScore >= 0.6;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷操作
          if (!isAnswering) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _explainCurrentChunk,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppTheme.border),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: Icon(Icons.menu_book, size: 18, color: AppTheme.textSecondary),
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
                    icon: Icon(Icons.help_outline, size: 18, color: AppTheme.textSecondary),
                    label: Text('再出一题',
                        style: TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ),
                ),
                if (hasNext && isMastered) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextChunk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.taskDone,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.arrow_forward, size: 18),
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
              GestureDetector(
                onTap: _answering ? _submitAnswer : () {
                  // 普通对话模式（暂时复用出题逻辑）
                },
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

  void _showCurrentChunk() {
    if (_progress == null) return;
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
            color: const Color(0xFF1e293b),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      '第 ${_progress!.currentChunkIndex + 1} 段代码',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
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
                      color: const Color(0xFF0f172a),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(
                      _progress!.currentChunk,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Color(0xFFe2e8f0),
                        height: 1.6,
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
