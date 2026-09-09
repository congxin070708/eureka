import 'speech_recognizer_io.dart'
    if (dart.library.js_interop) 'speech_recognizer_web.dart';

/// 语音识别统一接口
///
/// 通过条件导入选择实现：
/// - IO 平台（Android/iOS/桌面）→ speech_recognizer_io.dart（真实 speech_to_text）
/// - Web → speech_recognizer_web.dart（空实现，不打包插件，减小 JS 体积）
abstract class SpeechRecognizer {
  static SpeechRecognizer create() => SpeechRecognizerImpl();

  Future<bool> initialize();
  Future<void> stop();
  void listen({required void Function(String text) onResult});
}
