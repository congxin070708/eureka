import 'tts_adapter_io.dart'
    if (dart.library.js_interop) 'tts_adapter_web.dart';

/// TTS 适配器统一入口
///
/// 通过条件导入在构建期选择实现：
/// - IO 平台（Android/iOS/桌面）→ tts_adapter_io.dart（真实 flutter_tts）
/// - Web → tts_adapter_web.dart（空实现，不打包插件，减小 JS 体积）
class TtsAdapter {
  static const bool isSupported = TtsAdapterImpl.isSupported;

  static Future<void> init() => TtsAdapterImpl.init();
}
