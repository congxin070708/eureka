import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'file_storage_service.dart';
import 'study_engine.dart';
import 'api_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  // API key 等小配置仍用 SharedPreferences（简单可靠）
  ApiService.apiKey = prefs.getString('api_key') ?? ApiService.builtinKey;
  ApiService.backend = prefs.getString('backend') ?? 'deepseek';
  ApiService.bailianKey = prefs.getString('bailian_key') ?? '';

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

  runApp(AITutorApp(engine: engine));
}

/// 将引擎数据写入文件
Future<void> _saveEngineData(StudyEngine engine) async {
  await FileStorageService.save({
    'engine_data': engine.toJson(),
  });
}

class AITutorApp extends StatefulWidget {
  final StudyEngine engine;
  const AITutorApp({super.key, required this.engine});

  @override
  State<AITutorApp> createState() => _AITutorAppState();
}

class _AITutorAppState extends State<AITutorApp> with WidgetsBindingObserver {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _saveEngine();
    }
  }

  void _saveEngine() {
    _saveEngineData(widget.engine);
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
      title: '元启AI学伴',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: HomeScreen(engine: widget.engine),
    );
  }
}
