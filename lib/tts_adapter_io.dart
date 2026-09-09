import 'package:flutter_tts/flutter_tts.dart';
import 'voice_service.dart';

/// TTS 适配器 - IO 实现（Android/iOS/桌面等原生平台）
///
/// 使用真实 flutter_tts 插件。Web 构建不会包含本文件
/// （通过 tts_adapter.dart 的条件导入排除）。
class TtsAdapterImpl {
  static const bool isSupported = true;

  static Future<void> init() async {
    final tts = FlutterTts();
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.5);
    await tts.setVolume(1.0);
    await tts.setPitch(1.0);
    tts.setCompletionHandler(() => VoiceService.onComplete());
    tts.setErrorHandler((msg) => VoiceService.onError(msg));
    VoiceService.init(
      onSpeak: (text) async => await tts.speak(text),
      onStop: () async => await tts.stop(),
      onStateChange: (isSpeaking) {},
    );
  }
}
