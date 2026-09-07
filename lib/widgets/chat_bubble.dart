import 'package:flutter/material.dart';
import '../app_theme.dart';

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
          border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
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
                child: GestureDetector(
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
                        const SizedBox(width: 4),
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
              child: SelectableText(
                msg.text,
                style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    height: 1.7),
              ),
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
