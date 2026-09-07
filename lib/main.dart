import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';
import 'file_storage_service.dart';
import 'study_engine.dart';
import 'api_service.dart';
import 'secure_storage_service.dart';
import 'notification_service.dart';
import 'providers/app_providers.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // API Key 改用安全存储(Keystore/Keychain 加密)
  final secureKey = await SecureStorageService.getApiKey();
  // 兼容旧版:如果安全存储没有,尝试从 SharedPreferences 迁移
  if (secureKey.isEmpty) {
    final oldKey = prefs.getString('api_key') ?? '';
    if (oldKey.isNotEmpty) {
      await SecureStorageService.saveApiKey(oldKey);
      await prefs.remove('api_key'); // 迁移后清除明文
      ApiService.apiKey = oldKey;
    }
  } else {
    ApiService.apiKey = secureKey;
  }

  // 主题模式:默认白色(亮色),可切换
  AppTheme.isDark = prefs.getBool('dark_theme') ?? false;

  // 初始化本地通知(用于复习提醒)
  await NotificationService.init();

  // 引擎数据从文件加载（代替 SharedPreferences 的大数据存储）
  StudyEngine engine;
  try {
    final fileData = await FileStorageService.loadEngineData();
    if (fileData != null) {
      engine = StudyEngine.fromJson(fileData);
      debugPrint('[Main] 从文件加载引擎数据成功');
    } else {
      // 兼容旧版：从 SharedPreferences 迁移
      final stored = prefs.getString('engine_data');
      if (stored != null && stored.isNotEmpty) {
        engine = StudyEngine.fromJson(jsonDecode(stored));
        debugPrint('[Main] 从 SharedPreferences 迁移引擎数据');
      } else {
        engine = StudyEngine();
        debugPrint('[Main] 初始创建新引擎');
      }
    }
  } catch (e) {
    debugPrint('[Main] 加载引擎失败: $e，创建新引擎');
    engine = StudyEngine();
  }

  // 启动时立刻保存一次，确保文件被创建
  await _saveEngineData(engine);

  runApp(ProviderScope(
    overrides: [
      // 用已加载的引擎初始化 Provider
      studyEngineProvider.overrideWith((ref) {
        final notifier = StudyEngineNotifier();
        notifier.setEngine(engine);
        return notifier;
      }),
      themeProvider.overrideWith((ref) {
        final notifier = ThemeNotifier();
        notifier.setDark(AppTheme.isDark);
        return notifier;
      }),
    ],
    child: const EurekaApp(),
  ));
}

/// 将引擎数据写入文件
Future<void> _saveEngineData(StudyEngine engine) async {
  await FileStorageService.save({
    'engine_data': engine.toJson(),
  });
}

class EurekaApp extends ConsumerStatefulWidget {
  const EurekaApp({super.key});

  @override
  ConsumerState<EurekaApp> createState() => _EurekaAppState();
}

class _EurekaAppState extends ConsumerState<EurekaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _saveEngine();
    }
  }

  void _saveEngine() {
    final engine = ref.read(studyEngineProvider);
    ref.read(studyEngineProvider.notifier).save();
    _saveEngineData(engine);
  }

  @override
  void dispose() {
    _saveEngine();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '尤里卡',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: AppTheme.isDark ? Brightness.dark : Brightness.light,
        fontFamily: 'AppFont',
      ),
      home: const HomeScreen(),
    );
  }
}
