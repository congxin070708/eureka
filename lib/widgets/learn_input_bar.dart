import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 学习页输入栏 - 从 learn_screen.dart 抽取
/// 包含文本输入框、语音识别按钮和发送按钮
class LearnInputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool isAnswering;
  final bool isListening;
  final VoidCallback onSend;
  final VoidCallback onMicTap;
  final ValueChanged<String> onSubmitted;

  const LearnInputBar({
    super.key,
    required this.controller,
    required this.isAnswering,
    required this.isListening,
    required this.onSend,
    required this.onMicTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: 3,
              minLines: 1,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: isAnswering ? '用你自己的话回答...' : '输入你的想法...',
                hintStyle: TextStyle(color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.border),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
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
    );
  }
}
