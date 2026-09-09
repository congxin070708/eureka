import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 语音识别 - IO 实现（真实 speech_to_text 插件）
class SpeechRecognizerImpl {
  late final stt.SpeechToText _speech = stt.SpeechToText();

  Future<bool> initialize() => _speech.initialize();

  Future<void> stop() => _speech.stop();

  void listen({required void Function(String text) onResult}) {
    _speech.listen(
      onResult: (result) => onResult(result.recognizedWords),
      listenOptions: stt.SpeechListenOptions(
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
  }
}
