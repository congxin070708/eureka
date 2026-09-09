import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../knowledge_base_service.dart';
import '../api_service.dart';
import '../prompts.dart';
import '../widgets/chat_bubble.dart';

/// 文档详情页 - 知识库模式
///
/// 两种模式:
/// 1. 引导式阅读 - 逐段学习，AI讲解 → 出题 → 评分
/// 2. RAG 问答 - 自由提问，基于文档内容回答 + 引用来源
class KbDocumentScreen extends ConsumerStatefulWidget {
  final int docId;
  final String docTitle;
  const KbDocumentScreen({
    super.key,
    required this.docId,
    required this.docTitle,
  });

  @override
  ConsumerState<KbDocumentScreen> createState() => _KbDocumentScreenState();
}

class _KbDocumentScreenState extends ConsumerState<KbDocumentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  KbDocument? _doc;
  bool _loading = true;

  // ── 引导式阅读状态 ──
  final _readMessages = <ChatMsg>[];
  final _readInputCtrl = TextEditingController();
  final _readScrollCtrl = ScrollController();
  bool _readLoading = false;
  int _currentChunk = 0;
  int _totalChunks = 0;
  bool _readingAnswering = false;
  String _readingQuestion = '';
  List<String> _readingKeys = []; // 当前题的答案关键词

  // ── RAG 问答状态 ──
  final _ragMessages = <ChatMsg>[];
  final _ragInputCtrl = TextEditingController();
  final _ragScrollCtrl = ScrollController();
  bool _ragLoading = false;
  final List<List<KbSearchResult>> _ragReferences = []; // 每条回答对应的引用

  // ── 阅读进度持久化 ──

  String get _progressKey => 'kb_read_progress_${widget.docId}';

  Future<void> _saveReadProgress(int chunkIndex) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_progressKey, chunkIndex);
  }

  Future<int> _loadReadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_progressKey) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadDoc();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _readInputCtrl.dispose();
    _readScrollCtrl.dispose();
    _ragInputCtrl.dispose();
    _ragScrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDoc() async {
    setState(() => _loading = true);
    final doc = await KnowledgeBaseService.getDocument(widget.docId);
    final savedChunk = await _loadReadProgress();
    setState(() {
      _doc = doc;
      _totalChunks = doc?.totalChunks ?? 0;
      _currentChunk = savedChunk;
      _loading = false;
    });
    if (doc != null) {
      // 初始化引导式阅读
      if (savedChunk > 0 && savedChunk < doc.totalChunks) {
        _addReadMsg('📚', '欢迎回来！\n\n'
            '上次学到第 $savedChunk / ${doc.totalChunks} 段。\n\n'
            '发送「继续」从上次的位置开始，或「从头开始」重新学习。');
      } else {
        _addReadMsg('📚', '文档加载完成：**${doc.title}**\n\n'
            '共 ${doc.totalChunks} 段，我们一段一段来理解。\n\n'
            '每段流程：\n'
            '1️⃣ AI 讲解这段内容\n'
            '2️⃣ 出思考题，你用自己的话回答\n'
            '3️⃣ AI 评分和反馈\n\n'
            '准备好了就发送「开始」或点击下方按钮。');
      }
    }
  }

  // ════════════════════════════════════════
  // 引导式阅读
  // ════════════════════════════════════════

  void _addReadMsg(String role, String text, {bool isAI = true}) {
    setState(() {
      _readMessages.add(ChatMsg(role: role, text: text, isAI: isAI));
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_readScrollCtrl.hasClients) {
        _readScrollCtrl.animateTo(
          _readScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateLastRead(String text) {
    if (_readMessages.isEmpty) return;
    setState(() {
      _readMessages.last = ChatMsg(
        role: _readMessages.last.role,
        text: text,
        isAI: _readMessages.last.isAI,
      );
    });
  }

  Future<void> _sendRead() async {
    final text = _readInputCtrl.text.trim();
    if (text.isEmpty || _readLoading) return;

    _addReadMsg('👤', text, isAI: false);
    _readInputCtrl.clear();

    // 如果还没开始第一段，先开始
    if (_currentChunk == 0 && _readingQuestion.isEmpty && !_readingAnswering) {
      await _explainCurrentChunk();
      return;
    }

    // 如果正在答题
    if (_readingAnswering) {
      await _scoreReadingAnswer(text);
      return;
    }

    // 普通对话
    _readLoading = true;
    setState(() {});

    try {
      // 简单回应对话，引导用户继续学习
      _addReadMsg('💡', '准备好了就继续学习吧～\n\n'
          '当前进度：第 $_currentChunk / $_totalChunks 段\n\n'
          '发送「讲解」重新听这段讲解，或「继续」进入下一段。');
    } finally {
      _readLoading = false;
      setState(() {});
    }
  }

  Future<void> _explainCurrentChunk() async {
    _readLoading = true;
    setState(() {});

    // 获取当前切片内容（按序号直接读取，不走检索）
    final doc = _doc;
    if (doc == null) {
      _readLoading = false;
      setState(() {});
      return;
    }

    final chunk = await KnowledgeBaseService.getChunkByIndex(
      doc.id!,
      _currentChunk,
    );
    final chunkContent = chunk?.content ?? '';

    if (chunkContent.isEmpty) {
      _addReadMsg('❌', '无法获取第 ${_currentChunk + 1} 段内容');
      _readLoading = false;
      setState(() {});
      return;
    }

    _addReadMsg('🤖', '正在讲解第 ${_currentChunk + 1} 段...');

    final prompt = '''
你正在帮助一位学习者逐段理解一份文档：${doc.title}

这是第 ${_currentChunk + 1} / ${doc.totalChunks} 段内容：

$chunkContent

请用通俗易懂的方式讲解这段内容：
1. 这段主要讲了什么？（一句话概括）
2. 核心要点有哪些？（分点说明）
3. 有什么需要注意的地方？

语气要像一位耐心的学长，结合生活中的类比帮助理解。
如果有不认识的术语，先解释清楚。
最后出一道思考题，考察学生对这段内容的理解（开放式问题，需要用自己的话回答）。

输出 JSON 格式:
- explain: 讲解内容
- keyPoints: 3-5 个核心要点
- question: 思考题
- answerKeys: 5-8 个答案关键词（用于评分）

只输出纯 JSON。''';

    try {
      final result = await ApiService.chat(
        Prompts.knowledgeGuideSystem,
        prompt,
      );
      if (!result.success) {
        _updateLastRead('❌ AI 讲解失败：${result.error}');
        _readLoading = false;
        setState(() {});
        return;
      }

      final data = ApiService.parseJson(result);
      if (data == null) {
        _updateLastRead(result.content);
        _readLoading = false;
        setState(() {});
        return;
      }

      final explain = data['explain'] ?? '';
      final points = (data['keyPoints'] as List?)?.cast<String>() ?? [];
      final question = data['question'] ?? '';
      _readingKeys = (data['answerKeys'] as List?)?.cast<String>() ?? [];

      String msg = '📖 **第 ${_currentChunk + 1} / ${doc.totalChunks} 段讲解**\n\n$explain';
      if (points.isNotEmpty) {
        msg += '\n\n**核心要点：**';
        for (int i = 0; i < points.length; i++) {
          msg += '\n${i + 1}. ${points[i]}';
        }
      }
      msg += '\n\n🤔 **思考题：**\n$question';

      _updateLastRead(msg);
      _readingQuestion = question;
      _readingAnswering = true;
    } catch (e) {
      _updateLastRead('❌ 出错了：$e');
    } finally {
      _readLoading = false;
      setState(() {});
    }
  }

  Future<void> _scoreReadingAnswer(String answer) async {
    _readLoading = true;
    setState(() {});

    final doc = _doc;
    if (doc == null) {
      _readLoading = false;
      setState(() {});
      return;
    }

    // 结构化评分：关键词匹配 + LLM 反馈
    int score;
    String feedback = '';

    if (_readingKeys.isNotEmpty) {
      final result = PresetCourses.localScore(answer, _readingKeys);
      score = result['score'] as int;

      // 同时调用 LLM 获取反馈
      final prompt = '''
题目：$_readingQuestion

学生回答：$answer

请给出详细的反馈和解析。评分由关键词匹配确定，你的主要职责是解释和补充。

输出 JSON：
- feedback: 反馈内容（先肯定对的地方，再指出不足）
- correct: 答对的要点列表
- missed: 遗漏的要点列表

只输出 JSON。''';

      try {
        final llmResult = await ApiService.chat(
          Prompts.knowledgeGuideSystem,
          prompt,
        );
        if (llmResult.success) {
          final data = ApiService.parseJson(llmResult);
          if (data != null) {
            feedback = data['feedback'] ?? '';
          }
        }
      } catch (_) {}

      if (feedback.isEmpty) {
        if (score >= 80) {
          feedback = '回答中包含了大部分关键要点，理解到位。';
        } else if (score >= 60) {
          feedback = '答对了一部分要点，但还有重要的知识点需要补充。';
        } else {
          feedback = '只答对了少量要点，建议重新阅读这段内容。';
        }
      }
    } else {
      // 无关键词，直接 LLM 评分
      score = 0;
    }

    String emoji = score >= 80 ? '🎉' : score >= 60 ? '👍' : score >= 30 ? '💪' : '📚';
    String label = score >= 80 ? '掌握良好' : score >= 60 ? '基本理解' : score >= 30 ? '还需努力' : '需要复习';

    String msg = '📊 **评分结果**\n\n'
        '$emoji 得分：$score / 100 （$label）\n'
        '（基于答案要点匹配 · 确定性评分）\n\n'
        '**反馈：**\n$feedback';

    _addReadMsg('📊', msg);

    _readingAnswering = false;
    _readingQuestion = '';
    _readingKeys = [];

    // 显示下一步按钮
    final isLast = _currentChunk >= _totalChunks - 1;
    if (isLast) {
      _addReadMsg('🎓', '恭喜你完成了整份文档的学习！🎉\n\n'
          '你可以切换到「问答模式」继续深入探讨，或者返回知识库查看其他文档。');
    } else {
      _addReadMsg('💡', '这段学得不错！\n\n'
          '发送「下一段」继续学习，或「重学」再听一遍讲解。');
    }

    _readLoading = false;
    setState(() {});
  }

  void _nextChunk() {
    if (_currentChunk < _totalChunks - 1) {
      _currentChunk++;
      _saveReadProgress(_currentChunk);
      _readingAnswering = false;
      _readingQuestion = '';
      _readingKeys = [];
      _explainCurrentChunk();
    }
  }

  void _prevChunk() {
    if (_currentChunk > 0) {
      _currentChunk--;
      _saveReadProgress(_currentChunk);
      _readingAnswering = false;
      _readingQuestion = '';
      _readingKeys = [];
      _explainCurrentChunk();
    }
  }

  // ════════════════════════════════════════
  // RAG 问答
  // ════════════════════════════════════════

  void _addRagMsg(String role, String text, {bool isAI = true, List<KbSearchResult>? refs}) {
    setState(() {
      _ragMessages.add(ChatMsg(role: role, text: text, isAI: isAI));
      _ragReferences.add(refs ?? []);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_ragScrollCtrl.hasClients) {
        _ragScrollCtrl.animateTo(
          _ragScrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _updateLastRag(String text, {List<KbSearchResult>? refs}) {
    if (_ragMessages.isEmpty) return;
    setState(() {
      _ragMessages.last = ChatMsg(
        role: _ragMessages.last.role,
        text: text,
        isAI: _ragMessages.last.isAI,
      );
      if (refs != null && _ragReferences.isNotEmpty) {
        _ragReferences[_ragReferences.length - 1] = refs;
      }
    });
  }

  Future<void> _sendRag() async {
    final query = _ragInputCtrl.text.trim();
    if (query.isEmpty || _ragLoading) return;

    _addRagMsg('👤', query, isAI: false);
    _ragInputCtrl.clear();

    _ragLoading = true;
    _addRagMsg('🤖', '正在检索文档并思考...');
    setState(() {});

    try {
      // 1) 从知识库检索相关片段
      final results = await KnowledgeBaseService.search(
        query,
        docIds: [widget.docId],
        topK: 5,
      );

      if (results.isEmpty) {
        _updateLastRag('📭 没有在文档中找到相关内容。\n\n'
            '你可以换个问法试试，或者确认文档是否已完成索引。');
        _ragLoading = false;
        setState(() {});
        return;
      }

      // 2) 构建带引用的 prompt
      String context = '';
      for (int i = 0; i < results.length; i++) {
        final r = results[i];
        context += '\n[${i + 1}] ${r.chunk.content}\n';
      }

      final prompt = '''
请基于以下参考资料回答用户的问题。

参考资料：
$context

用户问题：$query

回答要求：
1. 只能使用参考资料中的信息回答问题
2. 如果参考资料中没有答案，直接说「文档中没有提到相关内容」
3. 回答中用 [1]、[2] 这样的上标标注引用来源（对应参考资料编号）
4. 语言要清晰易懂，适合学习者
5. 如果用户的问题涉及多个知识点，分点回答

不要编造参考资料中没有的内容。''';

      // 3) 调用 AI 回答
      final result = await ApiService.chat(
        Prompts.knowledgeQaSystem,
        prompt,
      );

      if (!result.success) {
        _updateLastRag('❌ 回答失败：${result.error}', refs: results);
      } else {
        // 在回答末尾加上引用来源列表
        final answer = result.content;
        String fullAnswer = answer;
        fullAnswer += '\n\n---\n**📚 引用来源：**\n';
        for (int i = 0; i < results.length; i++) {
          final r = results[i];
          final preview = r.chunk.content.length > 60
              ? '${r.chunk.content.substring(0, 60)}...'
              : r.chunk.content;
          final simScore = (r.score * 100).round();
          fullAnswer += '[${i + 1}] 第${r.chunk.index + 1}段（相关度 $simScore%）— $preview\n';
        }

        _updateLastRag(fullAnswer, refs: results);
      }
    } catch (e) {
      _updateLastRag('❌ 出错了：$e');
    } finally {
      _ragLoading = false;
      setState(() {});
    }
  }

  // ════════════════════════════════════════
  // UI 构建
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _doc?.title ?? '文档',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_doc != null)
              Text(
                '${_doc!.totalChunks} 段 · ${_formatFileSize(_doc!.totalChars)}',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
              ),
          ],
        ),
        centerTitle: false,
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          indicatorWeight: 2,
          tabs: const [
            Tab(text: '引导阅读'),
            Tab(text: '问答模式'),
          ],
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _buildReadingTab(),
                _buildRagTab(),
              ],
            ),
    );
  }

  Widget _buildReadingTab() {
    return Column(
      children: [
        // 进度条
        LinearProgressIndicator(
          value: _totalChunks == 0 ? 0 : _currentChunk / _totalChunks,
          backgroundColor: AppTheme.border,
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
          minHeight: 2,
        ),
        // 消息列表
        Expanded(
          child: ListView.builder(
            controller: _readScrollCtrl,
            padding: const EdgeInsets.all(16),
            itemCount: _readMessages.length,
            itemBuilder: (_, i) {
              final msg = _readMessages[i];
              return ChatBubble(msg: msg);
            },
          ),
        ),
        // 快捷操作
        if (_readingAnswering)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text('答题中...', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                const Spacer(),
                Text('第 $_currentChunk / $_totalChunks 段',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          )
        else if (_readMessages.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                if (_currentChunk > 0)
                  TextButton(
                    onPressed: _readLoading ? null : _prevChunk,
                    child: Text('上一段', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                const Spacer(),
                Text('第 $_currentChunk / $_totalChunks 段',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const Spacer(),
                if (_currentChunk < _totalChunks - 1)
                  TextButton(
                    onPressed: _readLoading ? null : _nextChunk,
                    child: Text('下一段', style: TextStyle(color: AppTheme.accent)),
                  ),
              ],
            ),
          ),
        // 输入框
        _buildInputBar(
          controller: _readInputCtrl,
          onSend: _sendRead,
          loading: _readLoading,
          hint: _readingAnswering ? '输入你的回答...' : '发送「开始」开始学习',
        ),
      ],
    );
  }

  Widget _buildRagTab() {
    return Column(
      children: [
        Expanded(
          child: _ragMessages.isEmpty
              ? _buildRagEmpty()
              : ListView.builder(
                  controller: _ragScrollCtrl,
                  padding: const EdgeInsets.all(16),
                  itemCount: _ragMessages.length,
                  itemBuilder: (_, i) {
                    final msg = _ragMessages[i];
                    return ChatBubble(msg: msg);
                  },
                ),
        ),
        _buildInputBar(
          controller: _ragInputCtrl,
          onSend: _sendRag,
          loading: _ragLoading,
          hint: '基于文档内容提问...',
        ),
      ],
    );
  }

  Widget _buildRagEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.question_answer_outlined, size: 56, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('基于文档问答', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '输入你的问题，AI 会基于文档内容\n给出回答并标注引用来源',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickChip('主要讲了什么？'),
                _buildQuickChip('核心概念是什么？'),
                _buildQuickChip('总结一下'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return GestureDetector(
      onTap: () {
        _ragInputCtrl.text = text;
        _sendRag();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        child: Text(text, style: TextStyle(fontSize: 12, color: AppTheme.accent)),
      ),
    );
  }

  Widget _buildInputBar({
    required TextEditingController controller,
    required VoidCallback onSend,
    required bool loading,
    required String hint,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16, 8, 16,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.bg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.border),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  onSubmitted: (_) => onSend(),
                  enabled: !loading,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: loading ? null : onSend,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: loading ? AppTheme.textSecondary.withValues(alpha: 0.3) : AppTheme.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  loading ? Icons.hourglass_empty : Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int chars) {
    if (chars < 1000) return '$chars 字';
    if (chars < 10000) return '${(chars / 1000).toStringAsFixed(1)}k 字';
    return '${(chars / 10000).toStringAsFixed(1)} 万字';
  }
}

// 临时：引用 PresetCourses 的 localScore
// （避免循环 import，这里直接复制一份简化版）
class PresetCourses {
  static Map<String, dynamic> localScore(String userAnswer, List<String> keyPoints) {
    final lowerAnswer = userAnswer.toLowerCase();
    final matched = <String>[];
    final missed = <String>[];
    for (final point in keyPoints) {
      if (lowerAnswer.contains(point.toLowerCase())) {
        matched.add(point);
      } else {
        missed.add(point);
      }
    }
    final score = keyPoints.isEmpty
        ? 100
        : (matched.length / keyPoints.length * 100).round();
    return {
      'score': score,
      'matched': matched,
      'missed': missed,
    };
  }
}
