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
/// AI 消息和系统消息支持语音朗读
class ChatBubble extends StatefulWidget {
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
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isSpeaking = false;

  void _toggleSpeak() {
    if (_isSpeaking) {
      VoiceService.stop();
      setState(() => _isSpeaking = false);
    } else {
      VoiceService.speak(widget.msg.text);
      setState(() => _isSpeaking = true);
    }
  }

  @override
  void dispose() {
    // 如果这条消息正在朗读，停止它
    if (_isSpeaking) {
      VoiceService.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    // 检测系统消息(含特定 emoji 前缀)
    final isSystem = msg.text.startsWith('📋') ||
        msg.text.startsWith('📖') ||
        msg.text.startsWith('💡') ||
        msg.text.startsWith('📊') ||
        msg.text.startsWith('🎯') ||
        msg.text.startsWith('❌') ||
        msg.text.startsWith('👹');

    if (msg.isAI) {
      if (isSystem) {
        return _buildSystemBubble();
      }
      return _buildAIBubble();
    } else {
      return _buildUserBubble();
    }
  }

  /// 语音朗读按钮
  Widget _buildSpeakButton({bool isLight = false}) {
    if (!VoiceService.isTtsAvailable) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _toggleSpeak,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (isLight ? Colors.white : AppTheme.accent).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: (isLight ? Colors.white : AppTheme.accent).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
              size: 13,
              color: isLight ? Colors.white70 : AppTheme.accentLight,
            ),
            const SizedBox(width: 3),
            Text(
              _isSpeaking ? '停止' : '朗读',
              style: TextStyle(
                fontSize: 11,
                color: isLight ? Colors.white70 : AppTheme.accentLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 系统面板风格(可收藏)
  Widget _buildSystemBubble() {
    final msg = widget.msg;
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
            const SizedBox(height: 8),
            // 按钮行：朗读 + 收藏
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSpeakButton(),
                const SizedBox(width: 8),
                // 可收藏的消息显示收藏按钮
                if (msg.text.startsWith('📖') || msg.text.startsWith('📊'))
                  GestureDetector(
                    onTap: () {
                      final cleaned = msg.text
                          .replaceAll(RegExp(r'[*#\n]'), '')
                          .trim();
                      final title = cleaned.length > 30
                          ? cleaned.substring(0, 30)
                          : cleaned;
                      widget.onBookmark?.call(title, msg.text);
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
          ],
        ),
      ),
    );
  }

  /// 普通AI消息
  Widget _buildAIBubble() {
    final msg = widget.msg;
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
            child: Container(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    msg.text,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.7),
                  ),
                  const SizedBox(height: 6),
                  _buildSpeakButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 用户消息
  Widget _buildUserBubble() {
    final msg = widget.msg;
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
