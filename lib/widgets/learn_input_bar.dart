import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 学习页输入栏 - 增强版引导系统
///
/// 包含:
/// - 文本输入框 + 语音 + 发送按钮
/// - 快捷短语芯片（根据场景动态变化）
/// - 上下文引导提示
/// - 帮助按钮（输入技巧说明）
class LearnInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isAnswering;
  final bool isListening;
  final String? hintOverride;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onQuickPhrase;

  const LearnInputBar({
    super.key,
    required this.controller,
    required this.isAnswering,
    required this.isListening,
    this.hintOverride,
    required this.onSend,
    required this.onMicTap,
    required this.onSubmitted,
    this.onQuickPhrase,
  });

  /// 答题模式下的快捷短语
  List<String> get _answerPhrases => const [
        '不太确定，让我想想',
        '我来试着回答',
        '能给点提示吗',
        '跳过这题',
      ];

  /// 对话模式下的快捷短语
  List<String> get _chatPhrases => const [
        '下一题',
        '再解释一下',
        '举个例子',
        '总结一下',
      ];

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _InputHelpSheet(isAnswering: isAnswering),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hint = hintOverride ??
        (isAnswering
            ? '用你自己的话回答，想到什么说什么...'
            : '输入你的想法，或输入"下一题"继续...');

    final phrases = isAnswering ? _answerPhrases : _chatPhrases;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 快捷短语芯片 ──
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: phrases.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final phrase = phrases[i];
                return GestureDetector(
                  onTap: () {
                    if (onQuickPhrase != null) {
                      onQuickPhrase!(phrase);
                    } else {
                      controller.text = phrase;
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _phraseIcon(phrase),
                          size: 12,
                          color: AppTheme.accent,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          phrase,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // ── 输入行 ──
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: 4,
                  minLines: 1,
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: hint,
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
                      borderSide:
                          BorderSide(color: AppTheme.accent, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.help_outline,
                          size: 20, color: AppTheme.textSecondary),
                      onPressed: () => _showHelpSheet(context),
                      tooltip: '输入技巧',
                    ),
                  ),
                  onSubmitted: onSubmitted,
                  textInputAction: TextInputAction.send,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onMicTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isListening
                        ? const Color(0xFFef4444)
                        : AppTheme.border,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    color: isListening
                        ? Colors.white
                        : AppTheme.textSecondary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onSend,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [AppTheme.accent, AppTheme.accentLight]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.send,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // ── 底部引导提示 ──
          SizedBox(
            height: 16,
            child: Text(
              isAnswering
                  ? '💡 用自己的话回答，即使不确定也没关系，AI 会帮你纠正'
                  : '💡 可以问问题、聊想法，或点击上方快捷短语',
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

  IconData _phraseIcon(String phrase) {
    if (phrase.contains('不确定') || phrase.contains('想想')) {
      return Icons.help_outline;
    } else if (phrase.contains('回答') || phrase.contains('试试')) {
      return Icons.edit_outlined;
    } else if (phrase.contains('提示')) {
      return Icons.lightbulb_outline;
    } else if (phrase.contains('跳过')) {
      return Icons.skip_next;
    } else if (phrase.contains('下一题')) {
      return Icons.skip_next;
    } else if (phrase.contains('解释')) {
      return Icons.menu_book_outlined;
    } else if (phrase.contains('例子')) {
      return Icons.emoji_objects_outlined;
    } else if (phrase.contains('总结')) {
      return Icons.summarize_outlined;
    }
    return Icons.bolt;
  }
}

/// 输入帮助弹窗
class _InputHelpSheet extends StatelessWidget {
  final bool isAnswering;
  const _InputHelpSheet({required this.isAnswering});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.8,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '💬 输入技巧',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  if (isAnswering) ..._buildAnswerTips(),
                  if (!isAnswering) ..._buildChatTips(),
                  const SizedBox(height: 16),
                  _buildSectionTitle('⌨️ 通用小技巧'),
                  const SizedBox(height: 10),
                  _buildTipTile(
                    '语音输入',
                    '点击麦克风图标可以语音输入，不用手动打字',
                    Icons.mic_none,
                  ),
                  _buildTipTile(
                    '快捷短语',
                    '点击输入框上方的快捷短语，快速填入常用内容',
                    Icons.bolt,
                  ),
                  _buildTipTile(
                    '随时提问',
                    '学习过程中随时可以打断，问你想问的问题',
                    Icons.question_answer,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAnswerTips() {
    return [
      _buildSectionTitle('🎯 答题模式怎么用？'),
      const SizedBox(height: 10),
      _buildTipTile(
        '用自己的话回答',
        '不要抄书，用你自己的理解说出来。说不出来说明还没真正掌握。',
        Icons.record_voice_over,
      ),
      _buildTipTile(
        '答错也没关系',
        'AI 会给你详细的反馈和纠正，这是学习过程中最重要的环节。',
        Icons.sentiment_satisfied,
      ),
      _buildTipTile(
        '想不出来就要提示',
        '输入「给点提示」或点击快捷短语，AI 会一步步引导你思考。',
        Icons.lightbulb_outline,
      ),
      _buildTipTile(
        '实在不会就跳过',
        '输入「跳过」看正确答案，理解后再继续下一题。',
        Icons.skip_next,
      ),
    ];
  }

  List<Widget> _buildChatTips() {
    return [
      _buildSectionTitle('💬 对话模式怎么用？'),
      const SizedBox(height: 10),
      _buildTipTile(
        '说「下一题」继续',
        '学完当前内容，输入「下一题」进入下一个知识点。',
        Icons.skip_next,
      ),
      _buildTipTile(
        '不懂就问',
        '哪里没听懂直接问，比如「再解释一下第二步」「什么是梯度下降」',
        Icons.help_outline,
      ),
      _buildTipTile(
        '要例子',
        '输入「举个例子」「举个生活中的类比」，抽象概念立刻变具体。',
        Icons.emoji_objects_outlined,
      ),
      _buildTipTile(
        '要总结',
        '输入「总结一下」，AI 会帮你梳理当前知识点的核心内容。',
        Icons.summarize_outlined,
      ),
    ];
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildTipTile(String title, String desc, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppTheme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  Text(desc,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                          height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
