import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../voice_service.dart';

/// 聊天消息模型 - 从 learn_screen.dart 抽取
class ChatMsg {
  final String emoji;
  String text;
  final bool isAI;
  ChatMsg({required this.emoji, required this.text, required this.isAI});

  Map<String, dynamic> toMap() => {
    'emoji': emoji,
    'text': text,
    'isAI': isAI,
  };

  factory ChatMsg.fromMap(Map<String, dynamic> m) => ChatMsg(
    emoji: m['emoji'] ?? '',
    text: m['text'] ?? '',
    isAI: m['isAI'] ?? true,
  );
}

/// 消息气泡组件 - 从 learn_screen.dart 抽取
/// 渲染系统消息面板、普通AI消息和用户消息三种样式
class ChatBubble extends StatelessWidget {
  final ChatMsg msg;
  final int index;
  final void Function(String title, String content)? onBookmark;

  const ChatBubble({
    super.key,
    required this.msg,
    required this.index,
    this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    // 检测系统消息(含特定 emoji 前缀)
    final isSystem = msg.text.startsWith('📋') ||
        msg.text.startsWith('📖') ||
        msg.text.startsWith('💡') ||
        msg.text.startsWith('📊') ||
        msg.text.startsWith('🎯') ||
        msg.text.startsWith('❌');

    if (msg.isAI) {
      if (isSystem) {
        return _buildSystemBubble();
      }
      return _buildAIBubble();
    } else {
      return _buildUserBubble();
    }
  }

  /// 系统面板风格(可收藏)
  Widget _buildSystemBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(
              msg.text,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textPrimary,
                height: 1.7,
                fontFamily: 'monospace',
              ),
            ),
            // 可收藏的消息显示收藏按钮
            if (msg.text.startsWith('📖') || msg.text.startsWith('📊'))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    // 朗读按钮
                    _SpeakButton(text: msg.text),
                    const SizedBox(width: 8),
                    // 收藏按钮
                    GestureDetector(
                      onTap: () {
                        final cleaned = msg.text
                            .replaceAll(RegExp(r'[*#\n]'), '')
                            .trim();
                        final title = cleaned.length > 30
                            ? cleaned.substring(0, 30)
                            : cleaned;
                        onBookmark?.call(title, msg.text);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppTheme.accent.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.bookmark_border,
                                size: 14, color: AppTheme.accentLight),
                            const SizedBox(width: 4),
                            Text('收藏',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.accentLight)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // 如果没有收藏按钮，就只显示朗读按钮
            if (!(msg.text.startsWith('📖') || msg.text.startsWith('📊')))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _SpeakButton(text: msg.text),
              ),
          ],
        ),
      ),
    );
  }

  /// 普通AI消息
  Widget _buildAIBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentLight],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
                child: Text(msg.emoji, style: const TextStyle(fontSize: 16))),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: SelectableText(
                    msg.text,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.7),
                  ),
                ),
                const SizedBox(height: 4),
                _SpeakButton(text: msg.text, compact: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 用户消息
  Widget _buildUserBubble() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Text(msg.text,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      height: 1.7)),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 14))),
          ),
        ],
      ),
    );
  }
}

/// ────────────────────────────────────────────
/// 朗读按钮组件
/// ────────────────────────────────────────────
class _SpeakButton extends StatefulWidget {
  final String text;
  final bool compact;

  const _SpeakButton({required this.text, this.compact = false});

  @override
  State<_SpeakButton> createState() => _SpeakButtonState();
}

class _SpeakButtonState extends State<_SpeakButton> {
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    VoiceService.addListener(_onSpeakingStateChanged);
  }

  @override
  void dispose() {
    VoiceService.removeListener(_onSpeakingStateChanged);
    super.dispose();
  }

  void _onSpeakingStateChanged(bool speaking) {
    if (mounted) {
      setState(() => _isSpeaking = speaking);
    }
  }

  Future<void> _toggleSpeak() async {
    if (_isSpeaking || VoiceService.isSpeaking) {
      await VoiceService.stop();
      return;
    }

    final speakable = VoiceService.extractSpeakableText(widget.text);
    if (speakable.isEmpty) return;

    final ok = await VoiceService.speak(speakable);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('语音朗读不可用'), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final speaking = _isSpeaking || VoiceService.isSpeaking;

    if (widget.compact) {
      return GestureDetector(
        onTap: _toggleSpeak,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
              size: 14,
              color: speaking ? AppTheme.accent : AppTheme.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              speaking ? '停止' : '朗读',
              style: TextStyle(
                fontSize: 12,
                color: speaking ? AppTheme.accent : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _toggleSpeak,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: speaking
              ? const Color(0xFFef4444).withValues(alpha: 0.12)
              : AppTheme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: speaking
                ? const Color(0xFFef4444).withValues(alpha: 0.25)
                : AppTheme.accent.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              speaking ? Icons.stop : Icons.volume_up,
              size: 14,
              color: speaking ? const Color(0xFFef4444) : AppTheme.accentLight,
            ),
            const SizedBox(width: 4),
            Text(
              speaking ? '停止朗读' : '朗读内容',
              style: TextStyle(
                fontSize: 12,
                color: speaking ? const Color(0xFFef4444) : AppTheme.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
