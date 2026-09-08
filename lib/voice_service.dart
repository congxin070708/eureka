import 'package:flutter/foundation.dart';

/// 语音服务 - 统一管理 TTS 朗读和语音识别
///
/// 功能:
/// - TTS 文本转语音（AI 消息朗读）
/// - 语音识别输入（口述答题）
/// - 朗读状态管理（播放/停止）
/// - 错误处理与降级
///
/// 注意: speech_to_text 已在 learn_screen.dart 中直接使用,
/// 本服务封装 TTS 朗读功能, 并提供统一的语音交互接口。
class VoiceService {
  static bool _initialized = false;
  static bool _ttsAvailable = false;
  static bool _isSpeaking = false;

  /// 外部注入的 TTS 回调（由调用方在平台可用时注入）
  static void Function(String text)? _speakCallback;
  static void Function()? _stopCallback;
  static void Function(bool isSpeaking)? _stateCallback;

  /// 初始化 TTS 引擎
  static void init({
    required void Function(String text) onSpeak,
    required void Function() onStop,
    void Function(bool isSpeaking)? onStateChange,
  }) {
    _speakCallback = onSpeak;
    _stopCallback = onStop;
    _stateCallback = onStateChange;
    _initialized = true;
    _ttsAvailable = true;
  }

  /// 标记 TTS 不可用（平台不支持时）
  static void markUnavailable() {
    _ttsAvailable = false;
    _initialized = true;
  }

  /// 是否已初始化
  static bool get isInitialized => _initialized;

  /// TTS 是否可用
  static bool get isTtsAvailable => _ttsAvailable;

  /// 当前是否正在朗读
  static bool get isSpeaking => _isSpeaking;

  /// 朗读文本
  ///
  /// 清理 AI 返回的 Markdown 格式，只朗读纯文本部分
  static void speak(String text) {
    if (!_ttsAvailable || _speakCallback == null) {
      debugPrint('[VoiceService] TTS 不可用，跳过朗读');
      return;
    }

    // 如果正在朗读，先停止
    if (_isSpeaking && _stopCallback != null) {
      _stopCallback!();
    }

    // 清理文本：去除 Markdown 标记
    final cleaned = _cleanTextForTts(text);
    if (cleaned.isEmpty) {
      debugPrint('[VoiceService] 清理后文本为空，跳过朗读');
      return;
    }

    _isSpeaking = true;
    _stateCallback?.call(true);
    _speakCallback!(cleaned);
  }

  /// 停止朗读
  static void stop() {
    if (_stopCallback != null) {
      _stopCallback!();
    }
    _isSpeaking = false;
    _stateCallback?.call(false);
  }

  /// 朗读状态回调（TTS 引擎完成时调用）
  static void onComplete() {
    _isSpeaking = false;
    _stateCallback?.call(false);
  }

  /// 朗读出错时的回调
  static void onError(String error) {
    debugPrint('[VoiceService] TTS 错误: $error');
    _isSpeaking = false;
    _stateCallback?.call(false);
  }

  /// 清理文本，去除 Markdown 格式和不可朗读的内容
  ///
  /// - 去除 ** 加粗、* 斜体、# 标题、` 代码块 标记
  /// - 去除 emoji（系统消息前缀）
  /// - 去除 URL
  /// - 保留标点和换行，让朗读自然停顿
  static String _cleanTextForTts(String text) {
    var result = text;

    // 去除代码块
    result = result.replaceAll(RegExp(r'```[\s\S]*?```'), '（代码省略）');

    // 去除行内代码
    result = result.replaceAll(RegExp(r'`([^`]+)`'), r'$1');

    // 去除加粗/斜体标记
    result = result.replaceAll(RegExp(r'\*{1,3}([^*]+)\*{1,3}'), r'$1');

    // 去除标题标记
    result = result.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');

    // 去除 URL
    result = result.replaceAll(RegExp(r'https?://\S+'), '（链接省略）');

    // 去除开头的 emoji 前缀（如 📋 📖 💡 📊 🎯）
    result = result.replaceAll(RegExp(r'^[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}]+\s*', multiLine: true), '');

    // 去除 Markdown 表格语法
    result = result.replaceAll(RegExp(r'\|'), ' ');
    result = result.replaceAll(RegExp(r'^[\s-:]+\s*$', multiLine: true), '');

    // 去除列表标记
    result = result.replaceAll(RegExp(r'^\s*[-*]\s+', multiLine: true), '');
    result = result.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // 多余空行压缩
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }

  /// 释放资源
  static void dispose() {
    stop();
    _speakCallback = null;
    _stopCallback = null;
    _stateCallback = null;
    _initialized = false;
    _ttsAvailable = false;
  }
}
