/// 语音识别 - Web 实现
///
/// Web 平台不引入 speech_to_text 插件（体积大且 Web 支持不稳定）。
/// initialize() 恒定返回 false，UI 显示"语音识别不可用"。
class SpeechRecognizerImpl {
  Future<bool> initialize() async => false;

  Future<void> stop() async {}

  void listen({required void Function(String text) onResult}) {
    // no-op
  }
}
