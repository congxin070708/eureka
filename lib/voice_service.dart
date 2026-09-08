import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音服务 - 统一管理 TTS 朗读 + 语音识别
///
/// 功能:
/// - TTS 文字转语音朗读
/// - 语音识别转文字
/// - 朗读速度/音调/音量调节
/// - 中英文自动适配
class VoiceService {
  static final FlutterTts _tts = FlutterTts();
  static final stt.SpeechToText _speech = stt.SpeechToText();
  static bool _ttsReady = false;
  static bool _speechReady = false;
  static bool _isSpeaking = false;

  static double speechRate = 0.95;   // 朗读速度
  static double pitch = 1.0;        // 音调
  static double volume = 1.0;       // 音量
  static String language = 'zh-CN'; // 语言

  static bool get isTtsReady => _ttsReady;
  static bool get isSpeechReady => _speechReady;
  static bool get isListening => _speech.isListening;
  static bool get isSpeaking => _isSpeaking;

  // TTS 状态变化监听器列表（支持多个 UI 同时监听）
  static final List<void Function(bool speaking)> _listeners = [];

  /// 注册状态监听
  static void addListener(void Function(bool speaking) listener) {
    _listeners.add(listener);
  }

  /// 移除状态监听
  static void removeListener(void Function(bool speaking) listener) {
    _listeners.remove(listener);
  }

  /// 通知所有监听器
  static void _notifyListeners(bool speaking) {
    for (final listener in _listeners) {
      listener(speaking);
    }
  }

  /// 初始化 TTS
  static Future<bool> initTts() async {
    try {
      await _tts.setLanguage(language);
      await _tts.setSpeechRate(speechRate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(volume);

      // 中文设置
      await _tts.awaitSpeakCompletion(true);

      // 设置 TTS 状态回调
      _tts.setStartHandler(() {
        _isSpeaking = true;
        _notifyListeners(true);
      });
      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _notifyListeners(false);
      });
      _tts.setCancelHandler(() {
        _isSpeaking = false;
        _notifyListeners(false);
      });
      _tts.setErrorHandler((_) {
        _isSpeaking = false;
        _notifyListeners(false);
      });

      _ttsReady = true;
      return true;
    } catch (e) {
      _ttsReady = false;
      return false;
    }
  }

  /// 初始化语音识别
  static Future<bool> initSpeech() async {
    try {
      _speechReady = await _speech.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
      return _speechReady;
    } catch (e) {
      _speechReady = false;
      return false;
    }
  }

  /// 朗读文字
  static Future<bool> speak(String text) async {
    if (!_ttsReady) {
      final ok = await initTts();
      if (!ok) return false;
    }

    try {
      await _tts.stop();
      _isSpeaking = true;
      _notifyListeners(true);
      await _tts.speak(text);
      return true;
    } catch (e) {
      _isSpeaking = false;
      _notifyListeners(false);
      return false;
    }
  }

  /// 停止朗读
  static Future<void> stop() async {
    if (_ttsReady) {
      await _tts.stop();
    }
    _isSpeaking = false;
    _notifyListeners(false);
  }

  /// 暂停朗读
  static Future<void> pause() async {
    if (_ttsReady) {
      await _tts.pause();
      _isSpeaking = false;
      _notifyListeners(false);
    }
  }

  /// 设置朗读速度
  static Future<void> setRate(double rate) async {
    speechRate = rate.clamp(0.5, 2.0);
    if (_ttsReady) {
      await _tts.setSpeechRate(speechRate);
    }
  }

  /// 设置音量
  static Future<void> setVolume(double vol) async {
    volume = vol.clamp(0.0, 1.0);
    if (_ttsReady) {
      await _tts.setVolume(volume);
    }
  }

  /// 开始语音识别
  static Future<void> startListening({
    required Function(String) onResult,
    required Function() onListeningStart,
    required Function() onListeningEnd,
    Duration? listenFor,
  }) async {
    if (!_speechReady) {
      final ok = await initSpeech();
      if (!ok) return;
    }

    if (_speech.isListening) {
      await _speech.stop();
      return;
    }

    onListeningStart();

    _speech.listen(
      onResult: (result) {
        onResult(result.recognizedWords);
        if (result.finalResult) {
          onListeningEnd();
        }
      },
      listenFor: listenFor ?? const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      localeId: language,
    );
  }

  /// 停止语音识别
  static Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  /// 取消语音识别
  static Future<void> cancelListening() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }

  /// 从 AI 回复中提取要朗读的核心内容（去掉 markdown 格式）
  static String extractSpeakableText(String text) {
    String clean = text;
    // 去掉 markdown 加粗/斜体标记
    clean = clean.replaceAll(RegExp(r'\*\*(.+?)\*\*'), r'\1');
    clean = clean.replaceAll(RegExp(r'__(.+?)__'), r'\1');
    clean = clean.replaceAll(RegExp(r'\*(.+?)\*'), r'\1');
    // 去掉代码块
    clean = clean.replaceAll(RegExp(r'```[\s\S]*?```'), '代码部分略');
    clean = clean.replaceAll(RegExp(r'`([^`]+)`'), r'\1');
    // 去掉链接
    clean = clean.replaceAll(RegExp(r'\[([^\]]+)\]\([^)]+\)'), r'\1');
    // 去掉表情符号的一些特殊字符（保留 emoji 本身，但去掉多余的）
    // 去掉标题标记
    clean = clean.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');
    // 去掉列表符号
    clean = clean.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');
    clean = clean.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    // 去掉多余空行
    clean = clean.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return clean.trim();
  }
}
