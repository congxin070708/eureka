import 'voice_service.dart';

/// TTS 适配器 - Web 实现
///
/// Web 平台不引入 flutter_tts 插件（该插件在 Web 无实现且体积大）。
/// 直接在入口标记 TTS 不可用，朗读按钮保持禁用。
class TtsAdapterImpl {
  static const bool isSupported = false;

  static Future<void> init() async {
    VoiceService.markUnavailable();
  }
}
