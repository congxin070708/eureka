import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

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
  // ── 后端(按 Key 前缀自动识别) ──
  static const String _deepseekUrl = 'https://api.deepseek.com/v1/chat/completions';
  static const String _bailianUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String _openaiUrl = 'https://api.openai.com/v1/chat/completions';

  static String apiKey = '';

  /// 后端类型:按 Key 前缀识别
  /// sk-sp- → 百炼(TokenPlan)；sk-proj- → OpenAI；其他 sk- → DeepSeek
  static String get _backend {
    final k = apiKey.trim();
    if (k.startsWith('sk-sp-')) return 'bailian';
    if (k.startsWith('sk-proj-')) return 'openai';
    return 'deepseek';
  }

  static String get baseUrl {
    switch (_backend) {
      case 'bailian': return _bailianUrl;
      case 'openai': return _openaiUrl;
      default: return _deepseekUrl;
    }
  }

  static String get _model {
    switch (_backend) {
      case 'bailian': return 'qwen-plus';
      case 'openai': return 'gpt-4o-mini';
      default: return 'deepseek-v4-flash';
    }
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
      if (_backend == 'deepseek') 'thinking': {'type': 'disabled'},
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

  /// startSubject 改为输出阶梯书单+学习路径，学习模式真正生效
  static Future<ApiResult> startSubject(String subject, {String extraHint = '', String mode = '深度'}) async {
    // 随机种子让每次推荐不同的书
    final seeds = ['入门推荐看这本', '经典必读', '过来人强推', '口碑最好的', '豆瓣高分'];
    final seed = seeds[DateTime.now().millisecondsSinceEpoch % seeds.length];

    // 学习模式真正影响 prompt
    String modePrompt;
    if (mode == '速学') {
      modePrompt = '用户选择速学模式：只给1个阶段、最多2本书，重点给出最核心的5个要点和3-4个速学话题，节奏要快。';
    } else if (mode == '挑战') {
      modePrompt = '用户选择挑战模式：不要先讲基础，直接出一道有难度的挑战题（放在"challenge"字段，格式{"q":"题目","points":["要点"],"hint":"提示"}），书单照常给但阶段从实战/进阶开始。';
    } else {
      modePrompt = '用户选择深度模式：给出完整分阶段书单(3-4个阶段)和5-8个学习话题，讲解要系统深入。';
    }

    final r = await _call('你是AI导师，回答简洁精准，只输出纯JSON',
      '学生想学「$subject」。$extraHint\n$modePrompt\n'
      '请生成一份完整学习路径，用JSON回复：'
      '1)简短欢迎语 2)分阶段书单(按模式要求，每阶段1-2本，含书名+作者+价值系数1-100+推荐理由) '
      '注意：每次推荐的书要不同，这次重点推荐$seed的教材 '
      '价值系数根据书籍难度和重要性评分：90-100神级(红色)、70-89优质(橙色)、50-69中等(黄色)、30-49基础(绿色)、0-29拓展(灰色) '
      '3)列出学习话题。'
      '格式{"welcome":"...","stages":[{"level":"入门/进阶/精通/实战","books":[{"name":"...","author":"...","value":85,"reason":"...","tag":"$seed"}]}],"topics":["..."]} 纯JSON。不要问用户想学哪个，直接出第一个话题的讲解。',
      cacheKey: 'start_${subject}_$mode');
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 讲解，支持学习模式和上下文记忆
  static Future<ApiResult> teach(String topic,
      {String mode = '深度', List<Map<String, String>>? history}) async {
    String modePrompt;
    if (mode == '速学') {
      modePrompt = '讲解要极度精炼，200字以内，要点不超过3个，每点一句话。';
    } else if (mode == '挑战') {
      modePrompt = '讲解可以深入一些，要点要覆盖难点和易错点，思考题要有挑战性。';
    } else {
      modePrompt = '讲解要通俗系统，覆盖核心概念和关键细节。';
    }
    final r = await _call('你是AI导师，回答简洁精准，只输出纯JSON',
      '$modePrompt 用200字以内通俗讲解「$topic」。必须用JSON：{"explain":"讲解","points":["要点1","要点2"],"question":"一道思考题"} 纯JSON',
      history: history);
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  static Future<ApiResult> generateQuestion(String topic, {String mode = '深度'}) async {
    String diff;
    if (mode == '挑战') {
      diff = '出有难度的挑战题，考察理解和应用，不要送分题。';
    } else if (mode == '速学') {
      diff = '出基础概念题，检验是否掌握核心要点。';
    } else {
      diff = '出中等难度的概念题。';
    }
    final r = await _call('你是AI导师，只输出纯JSON',
      '$diff 出一道关于「$topic」的概念题，让学生用自己的话回答。JSON：{"q":"题目","points":["关键要点1","关键要点2","关键要点3"],"hint":"提示"} 纯JSON');
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  static Future<ApiResult> scoreAnswer(String question, String answer) async {
    final r = await _call('你是严格的AI导师，只输出纯JSON',
      '问题：$question\n学生回答：$answer\n请评分0-100并给出简短反馈和建议。\n注意：如果学生回答与问题完全无关（闲聊、答非所问、复读题目），score必须为0，feedback写明"回答与问题无关"。JSON：{"score":数字,"feedback":"反馈","suggest":"建议","missed":["遗漏要点"]} 纯JSON');
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 跳过问题：直接给出参考答案和讲解
  static Future<ApiResult> skipAnswer(String question) async {
    final r = await _call('你是AI导师，回答简洁精准，只输出纯JSON',
      '学生跳过了这道题：$question\n请给出参考答案和简短解析，让学生看懂。JSON：{"answer":"参考答案","explain":"解析"} 纯JSON');
    if (!r.success) return r;
    return _wrapJson(r.content);
  }

  /// 工具：从成功ApiResult中解析JSON
  static Map<String, dynamic>? parseJson(ApiResult r) {
    if (!r.success) return null;
    try { return jsonDecode(r.content); } catch (_) { return null; }
  }
}
