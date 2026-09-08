import 'smart_content_detector.dart';

/// 文件学习服务
///
/// 功能:
/// - 读取文本/代码文件
/// - 智能分段（委托给 SmartContentDetector 自动检测内容类型并选择最优策略）
/// - 生成针对每段的理解问题
/// - 评估用户对每段的理解程度
class FileLearningService {
  /// 分段策略 - 使用 SmartContentDetector 自动检测内容类型
  static List<String> splitContent(String content, String fileName) {
    return SmartContentDetector.segment(content, fileName);
  }

  /// 生成针对某段代码/文本的讲解 prompt
  static String buildExplainPrompt(String chunk, String fileName, int chunkIndex, int totalChunks) {
    final ext = fileName.split('.').last.toLowerCase();
    final lang = _languageName(ext);

    return '''
你正在帮助一位学习者逐段理解一份 $lang 代码文件：$fileName

这是第 $chunkIndex / $totalChunks 段内容：

\`\`\`$ext
$chunk
\`\`\`

请用通俗易懂的方式讲解这段代码：
1. 这段代码整体做了什么？（一句话概括）
2. 逐部分解释关键逻辑
3. 这段代码的设计思路是什么？为什么要这样写？
4. 有哪些需要注意的细节或坑？

语气要像一位耐心的学长，不要太学术，要结合生活中的类比。
如果这段代码里有不认识的函数/类，先猜测它的作用，然后标记出来。''';
  }

  /// 生成针对某段的理解测试题
  static String buildQuestionPrompt(String chunk, String fileName, int chunkIndex, int totalChunks) {
    final ext = fileName.split('.').last.toLowerCase();
    final lang = _languageName(ext);

    return '''
你正在测试一位学习者对以下 $lang 代码的理解程度：

\`\`\`$ext
$chunk
\`\`\`

请出一道思考题，考察学生对这段代码的**理解深度**，而不是死记硬背。

要求：
- 题目应该是开放式的，需要学生用自己的话回答
- 考察的是"为什么"和"怎么运作"，而不是"是什么"
- 不要出语法细节题，要出设计思路/逻辑理解题
- 可以让学生预测代码行为、分析设计意图、或者找出潜在问题

请用 JSON 格式返回：
{
  "question": "题目内容",
  "keyPoints": ["考察的核心知识点1", "知识点2"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  /// 生成用户回答的评分 prompt
  static String buildEvaluatePrompt(
    String chunk,
    String question,
    String answer,
    String fileName,
  ) {
    final ext = fileName.split('.').last.toLowerCase();

    return '''
你是一位严格但友善的编程老师。以下是一段代码和一道理解题，以及学生的回答。

代码片段：
\`\`\`$ext
$chunk
\`\`\`

题目：$question

学生的回答：
$answer

请评估学生的回答，评分标准：
- 准确性（40分）：核心概念是否正确
- 深度（30分）：是否理解了背后的设计思路，而不只是表面
- 完整性（20分）：是否覆盖了关键点
- 表达（10分）：是否用自己的话清晰表达

请用 JSON 返回：
{
  "score": 0-100的整数,
  "feedback": "具体的反馈和修正，先肯定好的地方，再指出不足",
  "correctAnswer": "参考答案要点",
  "breakdown": {
    "accuracy": 得分,
    "depth": 得分,
    "completeness": 得分,
    "expression": 得分
  },
  "mastered": true/false（80分以上为true）
}

反馈语气要鼓励，即使答错了也要让学生觉得"学到了"。只输出 JSON。''';
  }

  static String _languageName(String ext) {
    const map = {
      'dart': 'Dart',
      'py': 'Python',
      'js': 'JavaScript',
      'ts': 'TypeScript',
      'java': 'Java',
      'cpp': 'C++',
      'c': 'C',
      'go': 'Go',
      'rs': 'Rust',
      'rb': 'Ruby',
      'php': 'PHP',
      'swift': 'Swift',
      'kt': 'Kotlin',
      'html': 'HTML',
      'css': 'CSS',
      'sh': 'Shell',
      'sql': 'SQL',
    };
    return map[ext] ?? ext.toUpperCase();
  }
}

/// 文件学习进度
class FileLearningProgress {
  final String fileName;
  final String content;
  final List<String> chunks;
  int currentChunkIndex;
  final List<double> chunkScores; // 每段的得分
  final List<String> explanations; // 每段的讲解

  FileLearningProgress({
    required this.fileName,
    required this.content,
    required this.chunks,
    this.currentChunkIndex = 0,
    List<double>? chunkScores,
    List<String>? explanations,
  })  : chunkScores = chunkScores ?? List.filled(chunks.length, 0.0),
        explanations = explanations ?? [];

  int get totalChunks => chunks.length;
  double get overallScore {
    if (chunkScores.isEmpty) return 0.0;
    final validScores = chunkScores.where((s) => s > 0);
    if (validScores.isEmpty) return 0.0;
    return validScores.reduce((a, b) => a + b) / validScores.length;
  }

  double get progress =>
      chunkScores.where((s) => s >= 0.6).length / totalChunks;

  bool get isComplete =>
      chunkScores.every((s) => s >= 0.6);

  String get currentChunk =>
      currentChunkIndex < chunks.length ? chunks[currentChunkIndex] : '';

  bool get hasNext => currentChunkIndex < totalChunks - 1;
  bool get hasPrev => currentChunkIndex > 0;

  void nextChunk() {
    if (hasNext) currentChunkIndex++;
  }

  void prevChunk() {
    if (hasPrev) currentChunkIndex--;
  }

  void setScore(double score) {
    if (currentChunkIndex < chunkScores.length) {
      if (score > chunkScores[currentChunkIndex]) {
        chunkScores[currentChunkIndex] = score;
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'content': content,
    'chunks': chunks,
    'currentChunkIndex': currentChunkIndex,
    'chunkScores': chunkScores,
    'explanations': explanations,
  };

  factory FileLearningProgress.fromJson(Map<String, dynamic> json) =>
      FileLearningProgress(
        fileName: json['fileName'] as String,
        content: json['content'] as String,
        chunks: (json['chunks'] as List).cast<String>(),
        currentChunkIndex: json['currentChunkIndex'] as int? ?? 0,
        chunkScores: (json['chunkScores'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
        explanations: (json['explanations'] as List?)?.cast<String>() ?? [],
      );
}
