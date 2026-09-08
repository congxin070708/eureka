import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'prompts.dart';

/// API调用结果封装
class ApiResult {
  final bool success;
  final String content;   // 成功时: AI返回的文本
  final String error;     // 失败时: 错误描述
  final int? statusCode;  // HTTP状态码
  final bool fromCache;   // 是否来自缓存(降级时)
  ApiResult.success(this.content)
      : success = true, error = '', statusCode = null, fromCache = false;
  ApiResult.failure(this.error, {this.statusCode})
      : success = false, content = '', fromCache = false;
  ApiResult.cache(this.content)
      : success = true, error = '', statusCode = null, fromCache = true;
}

class ApiService {
  // ── 内置后端地址 ──
  static const String _deepseekUrl = 'https://api.deepseek.com/v1';
  static const String _bailianUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1';
  static const String _openaiUrl = 'https://api.openai.com/v1';
  static const String _siliconflowUrl = 'https://api.siliconflow.cn/v1';

  static String apiKey = '';
  static String customBaseUrl = ''; // 用户自定义 Base URL

  /// 检测结果
  static ApiDetectionResult? _cachedDetection;

  /// 后端类型:按 Key 前缀识别
  /// sk-sp- → 百炼；sk-proj- → OpenAI；sk-sid- → SiliconFlow；其他 sk- → DeepSeek
  static String get _backendByPrefix {
    final k = apiKey.trim();
    if (customBaseUrl.isNotEmpty) return 'custom';
    if (k.startsWith('sk-sp-')) return 'bailian';
    if (k.startsWith('sk-proj-')) return 'openai';
    if (k.startsWith('sk-sid-')) return 'siliconflow';
    return 'deepseek';
  }

  /// Base URL（不带 chat/completions 后缀，用于探测模型列表等）
  static String get baseUrlRoot {
    switch (_backendByPrefix) {
      case 'bailian': return _bailianUrl;
      case 'openai': return _openaiUrl;
      case 'siliconflow': return _siliconflowUrl;
      case 'custom': return _normalizeBaseUrl(customBaseUrl);
      default: return _deepseekUrl;
    }
  }

  /// 完整的 chat completions 地址
  static String get baseUrl => '$baseUrlRoot/chat/completions';

  /// 默认模型（按后端）
  static String get defaultModel {
    switch (_backendByPrefix) {
      case 'bailian': return 'qwen-plus';
      case 'openai': return 'gpt-4o-mini';
      case 'siliconflow': return 'deepseek-ai/DeepSeek-V3';
      default: return 'deepseek-v4-flash';
    }
  }

  /// 当前使用的模型（如果探测到了就用探测结果，否则用默认）
  static String get _model {
    return _cachedDetection?.firstModel ?? defaultModel;
  }

  /// 规范化 Base URL（去掉末尾的 /，确保不以 /chat/completions 结尾）
  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.endsWith('/chat/completions')) {
      u = u.substring(0, u.length - '/chat/completions'.length);
    }
    return u;
  }

  // ── 简易缓存: 缓存最近成功的响应,网络失败时降级返回 ──
  static final Map<String, String> _cache = {};
  static const int _maxRetries = 2; // 重试次数(不含首次)
  static const Duration _retryDelay = Duration(seconds: 1);

  static Future<ApiResult> _call(
    String system,
    String userMsg, {
    List<Map<String, String>>? history,
    String cacheKey = '', // 传入则启用缓存降级
  }) async {
    String key = apiKey.trim();
    if (key.isEmpty) return ApiResult.failure('请先在设置中填入 API Key');
    // 组装 messages:system + 最近对话上下文 + 当前提问
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': system},
      if (history != null) ...history,
      {'role': 'user', 'content': userMsg},
    ];
    final body = <String, dynamic>{
      'model': _model,
      'messages': messages,
      'temperature': 0.6,
      'max_tokens': 4000,
      // DeepSeek v4-flash 正式版(0731)默认走思考模式会返回空 content,
      // 显式禁用思考模式,保证普通聊天可用(仅 DeepSeek 支持该参数)
      if (_backendByPrefix == 'deepseek') 'thinking': {'type': 'disabled'},
    };

    ApiResult? lastError;
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final resp = await http.post(
          Uri.parse(baseUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $key',
          },
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 60));

        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final msg = data['choices'][0]['message'];
          var content = msg['content'] ?? '';
          // 推理模型内容可能放在 reasoning_content
          if (content.toString().trim().isEmpty) {
            content = msg['reasoning_content'] ?? '';
          }
          final result = ApiResult.success(content.toString());
          // 缓存成功结果
          if (cacheKey.isNotEmpty) {
            _cache[cacheKey] = content.toString();
            // 缓存上限 20 条
            if (_cache.length > 20) {
              _cache.remove(_cache.keys.first);
            }
          }
          return result;
        }
        // 4xx 错误不重试(客户端错误,重试也没用)
        if (resp.statusCode >= 400 && resp.statusCode < 500) {
          String detail = '';
          try {
            final err = jsonDecode(resp.body);
            detail = err['error']?['message'] ?? err.toString();
          } catch (_) {
            detail = resp.body.length > 200
                ? resp.body.substring(0, 200)
                : resp.body;
          }
          return ApiResult.failure('API错误(${resp.statusCode}): $detail',
              statusCode: resp.statusCode);
        }
        // 5xx 错误可以重试
        String detail = '';
        try {
          final err = jsonDecode(resp.body);
          detail = err['error']?['message'] ?? err.toString();
        } catch (_) {
          detail = resp.body.length > 200
              ? resp.body.substring(0, 200)
              : resp.body;
        }
        lastError = ApiResult.failure('API错误(${resp.statusCode}): $detail',
            statusCode: resp.statusCode);
      } on TimeoutException {
        lastError = ApiResult.failure('连接超时,请检查网络');
      } catch (e) {
        lastError = ApiResult.failure('连接失败: $e');
      }
      // 重试前等待(指数退避)
      if (attempt < _maxRetries) {
        await Future.delayed(_retryDelay * (attempt + 1));
      }
    }
    // 所有重试都失败,尝试返回缓存
    if (cacheKey.isNotEmpty && _cache.containsKey(cacheKey)) {
      return ApiResult.cache(_cache[cacheKey]!);
    }
    return lastError ?? ApiResult.failure('未知错误');
  }

  /// 从模型输出中提取纯 JSON(容忍 markdown 代码围栏等杂质)
  static String? _extractJsonText(String raw) {
    var t = raw.trim();
    // 去掉 ```json ... ``` 围栏
    t = t.replaceAll(RegExp(r'^```(?:json)?\s*', caseSensitive: false), '');
    t = t.replaceAll(RegExp(r'\s*```$'), '');
    // 取第一个 { 到最后一个 } 之间的部分
    final start = t.indexOf('{');
    final end = t.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return t.substring(start, end + 1);
  }

  static ApiResult _wrapJson(String raw) {
    final json = _extractJsonText(raw);
    if (json == null) return ApiResult.failure('AI返回格式异常，请重试');
    try {
      return ApiResult.success(jsonEncode(jsonDecode(json)));
    } catch (_) {
      return ApiResult.failure('AI返回格式异常，请重试');
    }
  }

  /// startSubject 生成阶梯书单+学习路径
  static Future<ApiResult> startSubject(String subject, {String extraHint = '', String mode = '深度'}) async {
    // 随机种子让每次推荐不同的书
    final seeds = ['入门推荐看这本', '经典必读', '过来人强推', '口碑最好的', '豆瓣高分'];
    final seed = seeds[DateTime.now().millisecondsSinceEpoch % seeds.length];
    final modePrompt = EurekaPrompts.modeDescription(mode);
    final systemPrompt = EurekaPrompts.systemTutor + EurekaPrompts.subjectGuard(subject);

    final userPrompt = '''
学生想学「$subject」。$extraHint

$modePrompt

请生成一份完整的学习路径,严格用 JSON 输出:

1) welcome: 一句热情的欢迎语,点明这个学科的价值和学习它的意义(不超过50字)
2) stages: 分阶段书单(根据模式要求的阶段数),每阶段 1-2 本书:
   - name: 书名
   - author: 作者
   - value: 价值系数(1-100),90-100神级、70-89优质、50-69中等、30-49基础、0-29拓展
   - reason: 为什么推荐这本书(20字以内)
   - tag: 推荐标签(这次用"$seed")
3) topics: 学习话题列表(根据模式调整数量)

注意:
- 每次推荐的书要不一样,这次重点推荐$seed的教材
- 不要问用户想学哪个,直接生成第一条话题的内容
- 所有内容用简体中文

格式示例:
{"welcome":"...","stages":[{"level":"入门","books":[{"name":"...","author":"...","value":85,"reason":"...","tag":"$seed"}]}],"topics":["..."]}
只输出纯 JSON,不要加任何其他文字。''';

    final r = await _call(systemPrompt, userPrompt,
        cacheKey: 'start_${subject}_$mode');
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 讲解知识点
  static Future<ApiResult> teach(String topic,
      {String mode = '深度', String subject = '', List<Map<String, String>>? history}) async {
    final modePrompt = EurekaPrompts.modeDescription(mode);
    final systemPrompt = EurekaPrompts.systemTutor + EurekaPrompts.subjectGuard(subject);
    final userPrompt = '''
$modePrompt

请用通俗的方式讲解「$topic」。

输出 JSON 格式:
- explain: 核心讲解(根据模式控制长度,用自己的话讲,不要照本宣科)
- points: 3-5 个关键要点(每个要点一句话,简洁有力)
- question: 一道思考题(让学生用自己的话回答,检验是否真的理解了)
- analogy: 一个生活化的类比/例子(帮助理解抽象概念)

只输出纯 JSON,不要加其他说明。''';
    final r = await _call(systemPrompt, userPrompt, history: history);
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 生成考题
  static Future<ApiResult> generateQuestion(String topic, {String mode = '深度', String subject = ''}) async {
    final modePrompt = EurekaPrompts.modeDescription(mode);
    final systemPrompt = EurekaPrompts.systemTutor + EurekaPrompts.subjectGuard(subject);
    final userPrompt = '''
$modePrompt

请出一道关于「$topic」的概念题,让学生用自己的话回答。

要求:
- 题目要明确,不能有歧义
- 不是选择题,是开放式问答题
- 考察的是理解,不是死记硬背

输出 JSON 格式:
- q: 题目
- points: 3-5 个评分关键要点(答对一个要点得相应分数)
- hint: 提示(学生卡住时可以看,不要直接给答案)
- difficulty: 难度等级(简单/中等/困难)

只输出纯 JSON。''';
    final r = await _call(systemPrompt, userPrompt);
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 评分学生答案
  static Future<ApiResult> scoreAnswer(String question, String answer, {String subject = ''}) async {
    final systemPrompt = EurekaPrompts.systemStrictGrader + EurekaPrompts.subjectGuard(subject);
    final userPrompt = '''
题目: $question

学生回答: $answer

请严格评分并给出反馈。

评分标准:
- 0-30 分:基本没答对,或者答非所问
- 31-60 分:只答对了部分要点,理解不完整
- 61-80 分:大部分要点都答对了,有小疏漏
- 81-95 分:回答得很好,基本都对了
- 96-100 分:非常完美,甚至有自己的见解

输出 JSON 格式:
- score: 0-100 的整数
- feedback: 总体评价(先肯定对的地方,再指出不足,语气鼓励)
- suggest: 下一步学习建议(一句话)
- missed: 遗漏的要点列表(如果全答对了就放空数组)
- correct: 学生答对的要点列表

只输出纯 JSON。''';
    final r = await _call(systemPrompt, userPrompt);
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 跳过问题：给出参考答案
  static Future<ApiResult> skipAnswer(String question, {String subject = ''}) async {
    final systemPrompt = EurekaPrompts.systemTutor + EurekaPrompts.subjectGuard(subject);
    final userPrompt = '''
学生跳过了这道题: $question

请给出:
- answer: 参考答案(完整、准确)
- explain: 解析(讲清楚为什么,帮助学生理解)
- keyPoints: 这道题考察的核心知识点列表

语气要鼓励,告诉学生跳过也没关系,看懂了下次就会了。

只输出纯 JSON。''';
    final r = await _call(systemPrompt, userPrompt);
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 通用聊天接口（Boss 出题/评分等场景直接用）
  static Future<ApiResult> chat(String userMsg, {String? systemPrompt, String subject = ''}) {
    final sys = (systemPrompt ?? EurekaPrompts.systemTutor) + EurekaPrompts.subjectGuard(subject);
    return _call(sys, userMsg);
  }

  /// 工具：从成功ApiResult中解析JSON
  static Map<String, dynamic>? parseJson(ApiResult r) {
    if (!r.success) return null;
    try { return jsonDecode(r.content); } catch (_) { return null; }
  }

  // ── API 自动检测 ──

  /// 检测 API Key 和 Base URL 是否有效
  /// 返回检测结果：是否连通、后端名称、可用模型列表
  static Future<ApiDetectionResult> detectApi({
    String? testKey,
    String? testBaseUrl,
  }) async {
    final key = (testKey ?? apiKey).trim();
    final base = testBaseUrl != null && testBaseUrl.isNotEmpty
        ? _normalizeBaseUrl(testBaseUrl)
        : baseUrlRoot;

    if (key.isEmpty) {
      return ApiDetectionResult(
        success: false,
        error: '请输入 API Key',
        backendName: '未知',
        models: [],
      );
    }

    // 1. 先尝试获取模型列表（轻量探测）
    try {
      final modelsUrl = '$base/models';
      final resp = await http.get(
        Uri.parse(modelsUrl),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final List<dynamic> modelList = data['data'] ?? [];
        final models = modelList
            .map((m) => m['id']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();

        final backendName = _guessBackendName(models, base);
        final result = ApiDetectionResult(
          success: true,
          backendName: backendName,
          models: models,
          firstModel: models.isNotEmpty ? models[0] : null,
        );
        _cachedDetection = result;
        return result;
      }

      // 401/403 = Key 错了
      if (resp.statusCode == 401 || resp.statusCode == 403) {
        return ApiDetectionResult(
          success: false,
          error: 'API Key 无效，请检查是否正确',
          backendName: '未知',
          models: [],
        );
      }
    } catch (e) {
      // 模型列表接口不支持，继续往下试
    }

    // 2. 模型列表接口不通，就发一个最简单的 chat 请求测试
    try {
      final testBody = jsonEncode({
        'model': _guessDefaultModel(base),
        'messages': [
          {'role': 'user', 'content': 'hi'},
        ],
        'max_tokens': 5,
      });

      final resp = await http.post(
        Uri.parse('$base/chat/completions'),
        headers: {
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
        body: testBody,
      ).timeout(const Duration(seconds: 15));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final modelUsed = data['model']?.toString() ?? _guessDefaultModel(base);
        final result = ApiDetectionResult(
          success: true,
          backendName: _guessBackendName([], base),
          models: [modelUsed],
          firstModel: modelUsed,
        );
        _cachedDetection = result;
        return result;
      }

      String errorMsg = '连接失败 (${resp.statusCode})';
      try {
        final err = jsonDecode(resp.body);
        errorMsg = err['error']?['message'] ?? errorMsg;
      } catch (_) {
        // 响应体非合法 JSON，保持默认错误信息
      }

      return ApiDetectionResult(
        success: false,
        error: errorMsg,
        backendName: '未知',
        models: [],
      );
    } on TimeoutException {
      return ApiDetectionResult(
        success: false,
        error: '连接超时，请检查网络或 Base URL 是否正确',
        backendName: '未知',
        models: [],
      );
    } catch (e) {
      return ApiDetectionResult(
        success: false,
        error: '连接失败：$e',
        backendName: '未知',
        models: [],
      );
    }
  }

  static String _guessDefaultModel(String base) {
    if (base.contains('deepseek')) return 'deepseek-v4-flash';
    if (base.contains('dashscope') || base.contains('aliyun')) return 'qwen-plus';
    if (base.contains('openai')) return 'gpt-4o-mini';
    if (base.contains('siliconflow')) return 'deepseek-ai/DeepSeek-V3';
    return 'gpt-4o-mini';
  }

  static String _guessBackendName(List<String> models, String base) {
    final b = base.toLowerCase();
    if (b.contains('deepseek')) return 'DeepSeek';
    if (b.contains('dashscope') || b.contains('aliyun')) return '阿里云百炼';
    if (b.contains('openai')) return 'OpenAI';
    if (b.contains('siliconflow')) return 'SiliconFlow';
    if (b.contains('moonshot')) return '月之暗面 Kimi';
    if (b.contains('zhipu') || b.contains('chatglm')) return '智谱 AI';
    if (b.contains('xinghuo') || b.contains('xfyun') || b.contains('iflytek')) return '讯飞星火';
    if (models.any((m) => m.toLowerCase().contains('qwen'))) return '兼容 OpenAI 协议（通义千问系列）';
    if (models.any((m) => m.toLowerCase().contains('deepseek'))) return '兼容 OpenAI 协议（DeepSeek 系列）';
    if (models.any((m) => m.toLowerCase().contains('gpt'))) return '兼容 OpenAI 协议（GPT 系列）';
    return '兼容 OpenAI 协议';
  }

  /// 清除缓存的检测结果
  static void clearDetectionCache() {
    _cachedDetection = null;
  }
}

/// API 检测结果
class ApiDetectionResult {
  final bool success;
  final String error;
  final String backendName;
  final List<String> models;
  final String? firstModel;

  ApiDetectionResult({
    required this.success,
    required this.backendName,
    required this.models,
    this.error = '',
    this.firstModel,
  });

  int get modelCount => models.length;
}
