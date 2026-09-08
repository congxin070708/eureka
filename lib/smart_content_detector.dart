import 'dart:convert';
import 'paper_learning_service.dart';

/// ────────────────────────────────────────────
/// 智能内容类型检测 + 多模式学习框架
///
/// 自动识别学习内容的类型，匹配合适的学习策略
/// ────────────────────────────────────────────

/// 内容类型枚举
enum ContentType {
  academicPaper,    // 学术论文 - 两阶段学习
  codeFile,         // 代码文件 - 逐函数/逐段讲解
  textbookChapter,  // 教材章节 - 概念→例题→习题
  techDoc,          // 技术文档 - 接口→示例→注意事项
  article,          // 普通文章 - 主旨→细节→启发
  unknown,          // 未知类型 - 通用模式
}

/// 学习阶段（通用）
enum LearningPhase {
  overview,    // 概览/结构阶段
  detail,      // 细节/内容阶段
  practice,    // 练习/应用阶段
  review,      // 总结/回顾阶段
}

/// 内容类型检测结果
class ContentTypeDetection {
  final ContentType type;
  final double confidence;   // 置信度 0.0 ~ 1.0
  final Map<String, int> featureScores; // 各特征得分
  final String suggestedMode; // 建议的学习模式描述

  const ContentTypeDetection({
    required this.type,
    required this.confidence,
    required this.featureScores,
    required this.suggestedMode,
  });
}

/// 内容分段策略
class ContentSegment {
  final String id;
  final String title;       // 段标题
  final String content;     // 段内容
  final int order;          // 顺序
  final String? sectionPath; // 所属章节路径
  final String segmentType; // 段类型（概念/例题/代码/说明等）
  double mastery;           // 掌握度

  ContentSegment({
    required this.id,
    required this.title,
    required this.content,
    required this.order,
    this.sectionPath,
    this.segmentType = 'content',
    this.mastery = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'order': order,
    'sectionPath': sectionPath,
    'segmentType': segmentType,
    'mastery': mastery,
  };

  factory ContentSegment.fromJson(Map<String, dynamic> json) => ContentSegment(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    order: json['order'] as int? ?? 0,
    sectionPath: json['sectionPath'] as String?,
    segmentType: json['segmentType'] as String? ?? 'content',
    mastery: (json['mastery'] as num?)?.toDouble() ?? 0.0,
  );
}

/// 学习模式配置
class LearningModeConfig {
  final ContentType contentType;
  final String modeName;        // 模式名称
  final String description;     // 模式描述
  final String icon;            // 图标 emoji
  final List<LearningPhase> phases; // 学习阶段
  final bool supportsStructurePhase; // 是否有结构学习阶段

  const LearningModeConfig({
    required this.contentType,
    required this.modeName,
    required this.description,
    required this.icon,
    required this.phases,
    this.supportsStructurePhase = false,
  });
}

/// 学习模式配置库
class LearningModeLibrary {
  static const Map<ContentType, LearningModeConfig> _configs = {
    ContentType.academicPaper: LearningModeConfig(
      contentType: ContentType.academicPaper,
      modeName: '论文深度学习',
      description: '先搭框架再填内容，像学术导师一样带你读论文',
      icon: '📄',
      phases: [LearningPhase.overview, LearningPhase.detail, LearningPhase.review],
      supportsStructurePhase: true,
    ),
    ContentType.codeFile: LearningModeConfig(
      contentType: ContentType.codeFile,
      modeName: '代码精读',
      description: '逐函数拆解，从接口到实现彻底搞懂',
      icon: '💻',
      phases: [LearningPhase.overview, LearningPhase.detail, LearningPhase.practice],
    ),
    ContentType.textbookChapter: LearningModeConfig(
      contentType: ContentType.textbookChapter,
      modeName: '教材学习',
      description: '概念→例题→习题，经典三段式学习',
      icon: '📚',
      phases: [LearningPhase.overview, LearningPhase.detail, LearningPhase.practice, LearningPhase.review],
      supportsStructurePhase: true,
    ),
    ContentType.techDoc: LearningModeConfig(
      contentType: ContentType.techDoc,
      modeName: '文档研读',
      description: '接口说明→用法示例→注意事项，实用导向',
      icon: '📖',
      phases: [LearningPhase.overview, LearningPhase.detail],
    ),
    ContentType.article: LearningModeConfig(
      contentType: ContentType.article,
      modeName: '文章精读',
      description: '抓住主旨，理解细节，获得启发',
      icon: '📰',
      phases: [LearningPhase.overview, LearningPhase.detail, LearningPhase.review],
    ),
    ContentType.unknown: LearningModeConfig(
      contentType: ContentType.unknown,
      modeName: '通用学习',
      description: '逐段学习，边读边练',
      icon: '📝',
      phases: [LearningPhase.detail],
    ),
  };

  static LearningModeConfig get(ContentType type) =>
      _configs[type] ?? _configs[ContentType.unknown]!;
}

/// ────────────────────────────────────────────
/// 智能内容检测器
/// ────────────────────────────────────────────
class SmartContentDetector {
  /// 检测内容类型
  static ContentTypeDetection detect(String content, String fileName) {
    final scores = <String, int>{};
    final lowerContent = content.toLowerCase();
    final lowerName = fileName.toLowerCase();

    // ── 论文检测 ──
    int paperScore = 0;
    // 文件名特征
    if (lowerName.contains('paper') ||
        lowerName.contains('thesis') ||
        lowerName.contains('dissertation') ||
        lowerName.contains('论文') ||
        lowerName.contains('综述') ||
        lowerName.contains('survey') ||
        lowerName.contains('research')) {
      paperScore += 3;
    }
    // 内容特征
    if (lowerContent.contains('abstract') || content.contains('摘要')) paperScore += 2;
    if (lowerContent.contains('introduction') || content.contains('引言')) paperScore += 2;
    if (lowerContent.contains('methodology') ||
        lowerContent.contains('method') ||
        content.contains('方法')) paperScore += 1;
    if (lowerContent.contains('experiment') ||
        lowerContent.contains('experiments') ||
        content.contains('实验')) paperScore += 1;
    if (lowerContent.contains('conclusion') ||
        lowerContent.contains('conclusions') ||
        content.contains('结论')) paperScore += 2;
    if (lowerContent.contains('references') ||
        lowerContent.contains('bibliography') ||
        content.contains('参考文献')) paperScore += 2;
    if (lowerContent.contains('acknowledg') || content.contains('致谢')) paperScore += 1;
    // 章节编号模式
    if (RegExp(r'\d+\.\s*(Introduction|Method|Experiment|Conclusion|Related Work|Background)',
            caseSensitive: false).hasMatch(content)) {
      paperScore += 3;
    }
    // 学术引用标记
    if (RegExp(r'\[\d+\]').hasMatch(content) &&
        RegExp(r'\(.*\d{4}.*\)').hasMatch(content)) {
      paperScore += 2;
    }
    scores['paper'] = paperScore;

    // ── 代码检测 ──
    int codeScore = 0;
    final ext = lowerName.contains('.')
        ? lowerName.split('.').last
        : '';
    const codeExts = {
      'dart', 'py', 'js', 'ts', 'java', 'cpp', 'c', 'h',
      'go', 'rs', 'rb', 'php', 'swift', 'kt', 'scala',
      'html', 'css', 'sh', 'bash', 'sql',
    };
    if (codeExts.contains(ext)) codeScore += 5;
    // 代码特征
    if (RegExp(r'(function|def|class|interface|struct)\s+\w+').hasMatch(content)) codeScore += 2;
    if (RegExp(r'[{};]').hasMatch(content) && content.contains('(')) codeScore += 1;
    if (content.contains('import ') || content.contains('from ')) codeScore += 1;
    if (RegExp(r'//.*$|/\*[\s\S]*?\*/|#.*$', multiLine: true).hasMatch(content)) codeScore += 1;
    scores['code'] = codeScore;

    // ── 教材检测 ──
    int textbookScore = 0;
    if (lowerName.contains('textbook') ||
        lowerName.contains('教材') ||
        lowerName.contains('教程') ||
        lowerName.contains('chapter') ||
        lowerName.contains('章节')) {
      textbookScore += 3;
    }
    // 教材特征：章节 + 小节 + 例题 + 习题
    if (content.contains('第') && content.contains('章')) textbookScore += 2;
    if (content.contains('例题') || content.contains('例 ') || content.contains('Example')) textbookScore += 2;
    if (content.contains('习题') || content.contains('练习') || content.contains('Exercises')) textbookScore += 2;
    if (content.contains('小结') || content.contains('总结') || content.contains('Summary')) textbookScore += 1;
    if (RegExp(r'^\d+\.\d+[\s、.]', multiLine: true).hasMatch(content) &&
        content.length > 5000) {
      textbookScore += 2;
    }
    scores['textbook'] = textbookScore;

    // ── 技术文档检测 ──
    int docScore = 0;
    if (lowerName.contains('doc') ||
        lowerName.contains('readme') ||
        lowerName.contains('api') ||
        lowerName.contains('文档') ||
        lowerName.contains('说明')) {
      docScore += 2;
    }
    // API 文档特征
    if (RegExp(r'##\s*(API|Usage|Example|Parameters|Returns|Description)',
            caseSensitive: false).hasMatch(content)) {
      docScore += 2;
    }
    if (content.contains('```')) {
      // markdown 代码块，文档常见
      docScore += 1;
    }
    if (RegExp(r'-\s+`\w+`').hasMatch(content)) docScore += 1; // 参数列表
    if (lowerContent.contains('@param') || lowerContent.contains('@return')) docScore += 2;
    if (content.contains('用法') || content.contains('示例') || content.contains('参数')) docScore += 1;
    scores['doc'] = docScore;

    // ── 普通文章检测 ──
    int articleScore = 0;
    if (lowerName.contains('article') ||
        lowerName.contains('文章') ||
        lowerName.contains('blog') ||
        lowerName.contains('post') ||
        lowerName.contains('笔记')) {
      articleScore += 2;
    }
    // 文章特征：段落多、有标题列表
    final paragraphs = content.split(RegExp(r'\n\s*\n')).where((p) => p.trim().length > 50).length;
    if (paragraphs >= 3) articleScore += 1;
    if (paragraphs >= 6) articleScore += 1;
    // 文章一般代码少
    if (codeScore <= 2 && paperScore <= 3) articleScore += 1;
    scores['article'] = articleScore;

    // ── 确定类型 ──
    final entries = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topScore = entries.first.value;
    final secondScore = entries.length > 1 ? entries[1].value : 0;

    ContentType type;
    double confidence;

    if (topScore < 2) {
      type = ContentType.unknown;
      confidence = 0.3;
    } else {
      switch (entries.first.key) {
        case 'paper':
          type = ContentType.academicPaper;
          break;
        case 'code':
          type = ContentType.codeFile;
          break;
        case 'textbook':
          type = ContentType.textbookChapter;
          break;
        case 'doc':
          type = ContentType.techDoc;
          break;
        case 'article':
          type = ContentType.article;
          break;
        default:
          type = ContentType.unknown;
      }
      // 置信度 = 最高分 / (最高分 + 次高分)，差距越大置信度越高
      final total = topScore + secondScore;
      confidence = total > 0 ? topScore / total : 0.5;
    }

    final config = LearningModeLibrary.get(type);

    return ContentTypeDetection(
      type: type,
      confidence: confidence,
      featureScores: scores,
      suggestedMode: config.modeName,
    );
  }

  /// 获取类型对应的中文名
  static String typeName(ContentType type) {
    switch (type) {
      case ContentType.academicPaper: return '学术论文';
      case ContentType.codeFile: return '代码文件';
      case ContentType.textbookChapter: return '教材章节';
      case ContentType.techDoc: return '技术文档';
      case ContentType.article: return '普通文章';
      case ContentType.unknown: return '未知类型';
    }
  }
}

/// ────────────────────────────────────────────
/// 智能分段服务 - 根据内容类型选择分段策略
/// ────────────────────────────────────────────
class SmartSegmentationService {
  /// 根据内容类型智能分段
  static List<ContentSegment> segment(String content, String fileName, ContentType type) {
    switch (type) {
      case ContentType.academicPaper:
        return _segmentPaper(content);
      case ContentType.codeFile:
        return _segmentCode(content, fileName);
      case ContentType.textbookChapter:
        return _segmentTextbook(content);
      case ContentType.techDoc:
        return _segmentTechDoc(content);
      case ContentType.article:
        return _segmentArticle(content);
      case ContentType.unknown:
        return _segmentGeneric(content);
    }
  }

  /// 论文分段（用章节结构）
  static List<ContentSegment> _segmentPaper(String content) {
    // 复用论文学习服务的章节解析
    final sections = PaperLearningService.parseSections(content);
    return sections.asMap().entries.map((e) {
      final idx = e.key;
      final s = e.value;
      return ContentSegment(
        id: 'seg_$idx',
        title: s.title,
        content: s.content,
        order: idx,
        sectionPath: s.parentId,
        segmentType: s.level == 0 ? 'section' : 'subsection',
      );
    }).toList();
  }

  /// 代码分段（按函数/类）
  static List<ContentSegment> _segmentCode(String content, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final lines = content.split('\n');
    final segments = <ContentSegment>[];
    final currentChunk = <String>[];
    int braceDepth = 0;
    int idx = 0;
    String currentTitle = '文件开头';

    for (final line in lines) {
      final trimmed = line.trim();

      // 检测顶层定义
      final isTopDef = _isTopLevelDefinition(trimmed, ext) && braceDepth == 0;

      if (isTopDef && currentChunk.isNotEmpty) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.isNotEmpty) {
          segments.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle,
            content: chunk,
            order: idx,
            segmentType: _codeSegmentType(currentTitle),
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = _extractDefName(trimmed, ext);
        braceDepth = 0;
      }

      currentChunk.add(line);
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;

      // 段太大强制分割
      if (currentChunk.length > 60 && braceDepth == 0) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.isNotEmpty) {
          segments.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle,
            content: chunk,
            order: idx,
            segmentType: _codeSegmentType(currentTitle),
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = '继续...';
      }
    }

    // 最后一段
    final lastChunk = currentChunk.join('\n').trim();
    if (lastChunk.isNotEmpty) {
      segments.add(ContentSegment(
        id: 'seg_$idx',
        title: currentTitle,
        content: lastChunk,
        order: idx,
        segmentType: _codeSegmentType(currentTitle),
      ));
    }

    // 段太少就强制按行拆
    if (segments.length < 2 && lines.length > 30) {
      return _segmentByLines(content, 40);
    }

    return segments;
  }

  static bool _isTopLevelDefinition(String line, String ext) {
    final patterns = [
      r'^class\s+\w+',
      r'^(def|func|function|fn|defun)\s+\w+',
      r'^(void|int|string|bool|float|double|char|public|private|protected)\s+\w+\s*\(',
      r'^async\s+def\s+\w+',
      r'^func\s+\w+',
      r'^impl\s+\w+',
      r'^pub\s+fn\s+\w+',
      r'^(interface|struct|enum|typedef)\s+\w+',
    ];
    for (final p in patterns) {
      if (RegExp(p).hasMatch(line)) return true;
    }
    return false;
  }

  static String _extractDefName(String line, String ext) {
    // 提取定义的名称
    final match = RegExp(r'(class|def|func|function|fn|interface|struct|enum)\s+(\w+)').firstMatch(line);
    if (match != null) {
      final keyword = match.group(1);
      final name = match.group(2);
      return '$keyword $name';
    }
    return line.length > 30 ? line.substring(0, 30) : line;
  }

  static String _codeSegmentType(String title) {
    if (title.contains('class')) return 'class';
    if (title.contains('def ') || title.contains('function') || title.contains('func')) return 'function';
    if (title.contains('interface')) return 'interface';
    if (title.contains('struct')) return 'struct';
    return 'code';
  }

  /// 教材分段（按章节 + 小节 + 例题/习题标记）
  static List<ContentSegment> _segmentTextbook(String content) {
    final sections = <ContentSegment>[];
    final lines = content.split('\n');
    final currentChunk = <String>[];
    String currentTitle = '开头';
    String currentType = 'content';
    int idx = 0;
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        currentChunk.add(line);
        continue;
      }

      // 检测章节标题
      final isChapterHeading = RegExp(r'^第[一二三四五六七八九十\d]+章').hasMatch(trimmed) ||
          RegExp(r'^#{1,2}\s+').hasMatch(trimmed) ||
          RegExp(r'^\d+\s+[A-Z\u4e00-\u9fa5]').hasMatch(trimmed);

      // 检测小节标题
      final isSectionHeading = RegExp(r'^\d+\.\d+[\s、.]').hasMatch(trimmed) ||
          RegExp(r'^#{3}\s+').hasMatch(trimmed);

      // 检测例题/习题标记
      final isExample = trimmed.contains('例') ||
          RegExp(r'^Example', caseSensitive: false).hasMatch(trimmed);
      final isExercise = trimmed.contains('习题') ||
          trimmed.contains('练习') ||
          RegExp(r'^Exercises?', caseSensitive: false).hasMatch(trimmed);

      if ((isChapterHeading || isSectionHeading) && currentChunk.isNotEmpty) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.length > 50) {
          sections.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle,
            content: chunk,
            order: idx,
            sectionPath: currentSection,
            segmentType: currentType,
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = trimmed;
        currentType = isChapterHeading ? 'chapter' : 'section';
        if (isChapterHeading) currentSection = trimmed;
      } else if (isExample && currentChunk.isNotEmpty) {
        // 保存前面的内容
        final chunk = currentChunk.join('\n').trim();
        if (chunk.length > 50) {
          sections.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle,
            content: chunk,
            order: idx,
            sectionPath: currentSection,
            segmentType: currentType,
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
        currentType = 'example';
      } else if (isExercise && currentChunk.isNotEmpty) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.length > 50) {
          sections.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle,
            content: chunk,
            order: idx,
            sectionPath: currentSection,
            segmentType: currentType,
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = trimmed.length > 30 ? trimmed.substring(0, 30) : trimmed;
        currentType = 'exercise';
      } else {
        currentChunk.add(line);
      }
    }

    // 最后一段
    final lastChunk = currentChunk.join('\n').trim();
    if (lastChunk.length > 50) {
      sections.add(ContentSegment(
        id: 'seg_$idx',
        title: currentTitle,
        content: lastChunk,
        order: idx,
        sectionPath: currentSection,
        segmentType: currentType,
      ));
    }

    if (sections.isEmpty) {
      return _segmentGeneric(content);
    }

    return sections;
  }

  /// 技术文档分段（按 API/章节）
  static List<ContentSegment> _segmentTechDoc(String content) {
    final lines = content.split('\n');
    final segments = <ContentSegment>[];
    final currentChunk = <String>[];
    String currentTitle = '概述';
    int idx = 0;
    String currentType = 'overview';

    for (final line in lines) {
      final trimmed = line.trim();

      // 检测标题
      final isHeading = trimmed.startsWith('#') ||
          RegExp(r'^[A-Z][a-zA-Z\s]+$').hasMatch(trimmed) && trimmed.length < 40;

      if (isHeading && currentChunk.isNotEmpty) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.length > 30) {
          segments.add(ContentSegment(
            id: 'seg_$idx',
            title: currentTitle.replaceAll('#', '').trim(),
            content: chunk,
            order: idx,
            segmentType: currentType,
          ));
          idx++;
        }
        currentChunk.clear();
        currentTitle = trimmed;
        // 猜测段类型
        if (trimmed.toLowerCase().contains('api') ||
            trimmed.toLowerCase().contains('interface')) {
          currentType = 'api';
        } else if (trimmed.toLowerCase().contains('example') ||
                   trimmed.toLowerCase().contains('usage')) {
          currentType = 'example';
        } else if (trimmed.toLowerCase().contains('param')) {
          currentType = 'params';
        } else {
          currentType = 'doc';
        }
      } else {
        currentChunk.add(line);
      }
    }

    final lastChunk = currentChunk.join('\n').trim();
    if (lastChunk.length > 30) {
      segments.add(ContentSegment(
        id: 'seg_$idx',
        title: currentTitle.replaceAll('#', '').trim(),
        content: lastChunk,
        order: idx,
        segmentType: currentType,
      ));
    }

    if (segments.length < 2) {
      return _segmentGeneric(content);
    }

    return segments;
  }

  /// 普通文章分段（按段落）
  static List<ContentSegment> _segmentArticle(String content) {
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final segments = <ContentSegment>[];
    final buffer = StringBuffer();
    int idx = 0;

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      buffer.writeln(trimmed);

      if (buffer.length > 800) {
        segments.add(ContentSegment(
          id: 'seg_$idx',
          title: '第 ${idx + 1} 部分',
          content: buffer.toString().trim(),
          order: idx,
          segmentType: 'paragraph',
        ));
        idx++;
        buffer.clear();
      }
    }

    if (buffer.isNotEmpty) {
      segments.add(ContentSegment(
        id: 'seg_$idx',
        title: '第 ${idx + 1} 部分',
        content: buffer.toString().trim(),
        order: idx,
        segmentType: 'paragraph',
      ));
    }

    return segments;
  }

  /// 通用分段
  static List<ContentSegment> _segmentGeneric(String content) {
    return _segmentByLines(content, 50);
  }

  static List<ContentSegment> _segmentByLines(String content, int linesPerChunk) {
    final lines = content.split('\n');
    final segments = <ContentSegment>[];
    for (int i = 0; i < lines.length; i += linesPerChunk) {
      final end = (i + linesPerChunk < lines.length) ? i + linesPerChunk : lines.length;
      final chunk = lines.sublist(i, end).join('\n');
      if (chunk.trim().isNotEmpty) {
        final startLine = i + 1;
        segments.add(ContentSegment(
          id: 'seg_${i ~/ linesPerChunk}',
          title: '第 $startLine - $end 行',
          content: chunk,
          order: i ~/ linesPerChunk,
          segmentType: 'generic',
        ));
      }
    }
    return segments;
  }
}

/// ────────────────────────────────────────────
/// 学习 Prompt 生成器 - 根据内容类型生成不同的 Prompt
/// ────────────────────────────────────────────
class SmartPromptGenerator {
  /// 生成概览/结构讲解 Prompt
  static String buildOverviewPrompt({
    required ContentType type,
    required String content,
    required String fileName,
    required List<ContentSegment> segments,
  }) {
    switch (type) {
      case ContentType.academicPaper:
        return PaperLearningService.buildStructureAnalysisPrompt(content, fileName);
      case ContentType.codeFile:
        return _codeOverviewPrompt(content, fileName, segments);
      case ContentType.textbookChapter:
        return _textbookOverviewPrompt(content, fileName, segments);
      case ContentType.techDoc:
        return _techDocOverviewPrompt(content, fileName, segments);
      case ContentType.article:
        return _articleOverviewPrompt(content, fileName, segments);
      case ContentType.unknown:
        return _genericOverviewPrompt(content, fileName, segments);
    }
  }

  /// 生成单段讲解 Prompt
  static String buildExplainPrompt({
    required ContentType type,
    required ContentSegment segment,
    required String fileName,
    required LearningPhase phase,
    required int index,
    required int total,
  }) {
    switch (type) {
      case ContentType.academicPaper:
        if (phase == LearningPhase.overview) {
          return _paperStructureExplainPrompt(segment, index, total);
        }
        return _paperContentExplainPrompt(segment, index, total);
      case ContentType.codeFile:
        return _codeExplainPrompt(segment, fileName, index, total);
      case ContentType.textbookChapter:
        return _textbookExplainPrompt(segment, index, total, phase);
      case ContentType.techDoc:
        return _techDocExplainPrompt(segment, index, total);
      case ContentType.article:
        return _articleExplainPrompt(segment, index, total, phase);
      case ContentType.unknown:
        return _genericExplainPrompt(segment, index, total);
    }
  }

  /// 生成提问 Prompt
  static String buildQuestionPrompt({
    required ContentType type,
    required ContentSegment segment,
    required LearningPhase phase,
  }) {
    switch (type) {
      case ContentType.academicPaper:
        if (phase == LearningPhase.overview) {
          return _paperStructureQuestionPrompt(segment);
        }
        return _paperContentQuestionPrompt(segment);
      case ContentType.codeFile:
        return _codeQuestionPrompt(segment);
      case ContentType.textbookChapter:
        return _textbookQuestionPrompt(segment, phase);
      case ContentType.techDoc:
        return _techDocQuestionPrompt(segment);
      case ContentType.article:
        return _articleQuestionPrompt(segment, phase);
      case ContentType.unknown:
        return _genericQuestionPrompt(segment);
    }
  }

  // ── 代码类 Prompt ──

  static String _codeOverviewPrompt(String content, String fileName, List<ContentSegment> segments) {
    final summary = segments.map((s) => '${s.order + 1}. ${s.title} (${s.segmentType})').join('\n');
    return '''
你是一位资深程序员导师。请给以下代码文件做一个整体概览。

文件名：$fileName

代码结构：
$summary

请回答：
1. 🎯 这个文件整体是做什么的？（一句话概括）
2. 🏗️ 代码结构是怎样的？有哪些主要的类/函数？
3. 🔗 各部分之间是什么关系？
4. 💡 读这份代码的建议：应该按什么顺序读？重点关注什么？

语气要像有经验的学长，通俗有趣，多用比喻。
字数控制在 400 字以内。''';
  }

  static String _codeExplainPrompt(ContentSegment segment, String fileName, int index, int total) {
    final lang = fileName.split('.').last;
    return '''
你正在指导一位学生逐段理解代码。

文件名：$fileName
当前：第 $index / $total 段 - ${segment.title}

代码内容：
\`\`\`$lang
${segment.content}
\`\`\`

请用通俗易懂的方式讲解：
1. 📝 **一句话概括**：这段代码是干嘛的？
2. 🔍 **逐行/逐块解释**：关键逻辑是怎么运作的？
3. 🧠 **设计思路**：为什么要这么写？有什么考虑？
4. ⚠️ **注意事项**：有什么坑？边界条件？
5. 💡 **可以怎么改进**：如果让你重构，你会怎么改？

语气像耐心的学长，结合生活类比，不要太学术。
字数控制在 400 字以内。''';
  }

  static String _codeQuestionPrompt(ContentSegment segment) {
    return '''
针对以下代码，请出一道理解题，考察学生对这段代码的深度理解。

代码段：${segment.title}

\`\`\`
${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}
\`\`\`

要求：
- 开放式问题，需要学生用自己的话回答
- 考察设计思路和逻辑理解，不是语法细节
- 可以让学生预测行为、分析问题、或提出改进方案
- 难度适中

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["考察点1", "考察点2"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  // ── 教材类 Prompt ──

  static String _textbookOverviewPrompt(String content, String fileName, List<ContentSegment> segments) {
    final summary = segments.map((s) => '${s.order + 1}. ${s.title}').join('\n');
    return '''
你是一位大学讲师。请给以下教材内容做一个整体概览。

文件/章节：$fileName

内容结构：
$summary

请回答：
1. 📖 这一章主要讲什么主题？
2. 🎯 学习目标是什么？学完应该掌握什么？
3. 🗺️ 知识结构是怎样的？各部分之间的关系？
4. 💡 学习建议：这一章的重点难点是什么？怎么学最高效？

语气亲切专业，像一位优秀的大学老师。
字数控制在 400 字以内。''';
  }

  static String _textbookExplainPrompt(ContentSegment segment, int index, int total, LearningPhase phase) {
    final typeText = switch (segment.segmentType) {
      'example' => '例题',
      'exercise' => '习题',
      'chapter' => '章节导言',
      'section' => '小节内容',
      _ => '内容',
    };

    return '''
你正在给学生讲解教材内容。

当前内容：第 $index / $total 部分 - ${segment.title}（$typeText）

内容：
${segment.content.length > 2000 ? segment.content.substring(0, 2000) + '\n...（内容较长，已截取）' : segment.content}

请按以下方式讲解：
1. 🎯 **核心知识点**：这部分最关键的概念/方法是什么？
2. 📝 **详细讲解**：用通俗的语言解释清楚，结合生活类比
3. 💡 **为什么这么做**：背后的思想/动机是什么？
4. 🎯 **怎么用**：在什么场景下用？要注意什么？

${segment.segmentType == 'example' ? '5. ✏️ **解题思路**：一步步拆解这道例题的思路' : ''}

语气像耐心的大学老师，条理清晰，鼓励思考。
字数控制在 500 字以内。''';
  }

  static String _textbookQuestionPrompt(ContentSegment segment, LearningPhase phase) {
    final isExercise = segment.segmentType == 'exercise';
    return '''
针对以下教材内容，请出一道理解/应用题。

内容主题：${segment.title}

内容：
${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}

要求：
${isExercise ? '- 这是一道习题，请出一道类似难度的练习题\n- 需要学生动手计算/推导' : '- 开放式问题，考察学生对概念的理解\n- 不要考记忆，考理解和应用'}
- 难度适中，既不太简单也不太偏
- 能有效检验学生是否真的理解了

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["考察的核心知识点1", "知识点2"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  // ── 技术文档类 Prompt ──

  static String _techDocOverviewPrompt(String content, String fileName, List<ContentSegment> segments) {
    final summary = segments.map((s) => '${s.order + 1}. ${s.title}').join('\n');
    return '''
你是一位技术文档专家。请给以下技术文档做一个整体概览。

文档：$fileName

文档结构：
$summary

请回答：
1. 📖 这份文档讲的是什么技术/工具？
2. 🎯 它解决什么问题？核心价值是什么？
3. 🏗️ 文档结构是怎样的？各部分讲什么？
4. 💡 阅读建议：新手应该怎么读？重点在哪？

语气友好实用，像资深开发者分享经验。
字数控制在 300 字以内。''';
  }

  static String _techDocExplainPrompt(ContentSegment segment, int index, int total) {
    return '''
你正在讲解技术文档的内容。

当前：第 $index / $total 部分 - ${segment.title}

内容：
${segment.content.length > 2000 ? segment.content.substring(0, 2000) + '\n...（已截取）' : segment.content}

请讲解：
1. 📝 **核心内容**：这部分主要讲了什么？
2. 💻 **关键用法**：最重要的 API/配置/用法是什么？
3. ✅ **正确用法示例**：给出一个典型使用场景
4. ⚠️ **注意事项**：有什么坑？常见错误？
5. 🔗 **关联知识**：和其他部分有什么关系？

实用导向，少讲废话，多给干货。
字数控制在 400 字以内。''';
  }

  static String _techDocQuestionPrompt(ContentSegment segment) {
    return '''
针对以下技术文档内容，出一道应用题，检验学生是否真的会用。

主题：${segment.title}

内容：
${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}

要求：
- 出一道实际应用题，需要学生动手写代码/配置
- 考察的是"会不会用"，而不是"记不记得"
- 场景要具体、贴近实际开发

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["考察的关键用法1", "用法2"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  // ── 文章类 Prompt ──

  static String _articleOverviewPrompt(String content, String fileName, List<ContentSegment> segments) {
    return '''
你是一位阅读导师。请给以下文章做一个整体概览。

文章：$fileName
段落数：${segments.length}

请回答：
1. 📰 这篇文章的主题是什么？
2. 🎯 作者的核心观点/论点是什么？
3. 🗺️ 文章结构是怎样的？论证思路是什么？
4. 💡 读这篇文章可以获得什么启发？

语气像读书会的领读人，有洞察力。
字数控制在 300 字以内。''';
  }

  static String _articleExplainPrompt(ContentSegment segment, int index, int total, LearningPhase phase) {
    return '''
你正在带学生精读文章。

当前：第 $index / $total 部分 - ${segment.title}

内容：
${segment.content.length > 2000 ? segment.content.substring(0, 2000) + '\n...（已截取）' : segment.content}

请讲解：
1. 📝 **这部分讲了什么**：用自己的话概括
2. 🔍 **关键观点/细节**：有什么重要的内容？
3. 💡 **我的思考**：这部分给了你什么启发？
4. ❓ **值得讨论的问题**：有什么地方值得深入思考？

引导思考，而不只是复述内容。
字数控制在 400 字以内。''';
  }

  static String _articleQuestionPrompt(ContentSegment segment, LearningPhase phase) {
    return '''
针对以下文章内容，出一道思考题。

主题：${segment.title}

内容：
${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}

要求：
- 开放式问题，需要学生深入思考
- 可以是对观点的评价、联系实际、或拓展思考
- 鼓励学生表达自己的见解，而不是找标准答案

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["可以思考的方向1", "方向2", "方向3"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  // ── 论文类 Prompt（复用以简化） ──

  static String _paperStructureExplainPrompt(ContentSegment segment, int index, int total) {
    return '''
你正在指导学生进行论文的「结构学习阶段」。

当前章节（第 $index / $total 节）：${segment.title}

学生现在需要理解的是「这一章在论文中的作用和地位」。

请用通俗易懂的方式讲解：
1. 📍 **定位**：这一章在整篇论文中处于什么位置？
2. 🎯 **目的**：作者为什么要写这一章？
3. 🏗️ **结构**：这一章大概包含什么内容板块？
4. 🔗 **关联**：和前后章节是什么关系？
5. 💡 **读法建议**：读这一章时应该重点关注什么？

用比喻帮助理解，生动有趣。300 字以内。''';
  }

  static String _paperContentExplainPrompt(ContentSegment segment, int index, int total) {
    return '''
你正在指导学生进行论文的「内容深度学习阶段」。

当前章节（第 $index / $total 节）：${segment.title}

章节内容：
${segment.content.length > 2000 ? segment.content.substring(0, 2000) + '\n...（已截取）' : segment.content}

请深入讲解：
1. 🎯 **核心观点**：这一章最主要的发现是什么？
2. 📝 **关键内容**：分点讲解核心内容，用通俗语言解释
3. 🔬 **论证方式**：作者是怎么论证的？
4. 💡 **启发思考**：有什么启发性？
5. ❓ **存疑之处**：有什么值得商榷的地方？

500 字以内。''';
  }

  static String _paperStructureQuestionPrompt(ContentSegment segment) {
    return '''
出一道关于论文结构理解的思考题。

章节：${segment.title}

考察学生是否理解这一章在论文中的作用，而不是具体内容。

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["考察核心点1", "核心点2", "核心点3"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  static String _paperContentQuestionPrompt(ContentSegment segment) {
    return '''
出一道论文内容深度理解题。

章节：${segment.title}

内容：
${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}

要求：
- 开放式问题，考察真正的理解
- 考察"为什么"和"怎么做到的"

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["核心知识点1", "知识点2", "知识点3"],
  "difficulty": "easy/medium/hard",
  "questionType": "concept/application/critical"
}

只输出 JSON。''';
  }

  // ── 通用 Prompt ──

  static String _genericOverviewPrompt(String content, String fileName, List<ContentSegment> segments) {
    return '''
请给以下学习内容做一个整体概览。

文件：$fileName
共 ${segments.length} 个部分

请回答：
1. 这份内容主要讲什么？
2. 整体结构是怎样的？
3. 学习建议是什么？

200 字以内。''';
  }

  static String _genericExplainPrompt(ContentSegment segment, int index, int total) {
    return '''
请讲解以下内容：

第 $index / $total 部分：${segment.title}

内容：
${segment.content.length > 2000 ? segment.content.substring(0, 2000) + '...' : segment.content}

请用通俗易懂的方式讲解核心内容。
300 字以内。''';
  }

  static String _genericQuestionPrompt(ContentSegment segment) {
    return '''
针对以下内容，出一道理解题：

${segment.content.length > 1500 ? segment.content.substring(0, 1500) + '...' : segment.content}

请用 JSON 返回：
{
  "question": "题目",
  "keyPoints": ["考察点1", "考察点2"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }
}
