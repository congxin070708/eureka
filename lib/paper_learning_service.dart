/// 论文学习服务 - 两阶段学习模式
///
/// 论文和普通教材不同，需要特殊的学习策略：
///
/// **阶段一：格式学习（Structure）**
/// - 学习论文的结构（标题、摘要、引言、方法、结果、讨论、结论）
/// - 理解各部分的作用和写作规范
/// - 目标：能看懂论文"怎么写的"
///
/// **阶段二：内容学习（Content）**
/// - 逐节深入理解论文核心内容
/// - 方法论、实验设计、数据结果
/// - 目标：能看懂论文"写了什么"
///
/// 两阶段都需要 AI 判断，因为不同论文的内容结构不同，
/// 不能用固定模板，需要 AI 根据具体论文动态出题。
class PaperLearningService {
  /// 判断内容是否为论文
  static bool isPaperContent(String content, String fileName) {
    final lower = content.toLowerCase();

    // 文件名特征
    if (fileName.contains('paper') || fileName.contains('论文')) return true;

    // 内容特征：论文常见关键词
    final paperKeywords = [
      'abstract', '摘要', 'introduction', '引言',
      'methodology', '方法', 'results', '结果',
      'discussion', '讨论', 'conclusion', '结论',
      'references', '参考文献', 'bibliography',
    ];

    int matchCount = 0;
    for (final kw in paperKeywords) {
      if (lower.contains(kw)) matchCount++;
    }

    // 命中 3 个以上论文结构关键词，判定为论文
    return matchCount >= 3;
  }

  /// 检测论文结构，返回各章节文本
  static List<PaperSection> extractSections(String content) {
    final sections = <PaperSection>[];
    final lines = content.split('\n');

    // 论文常见章节标题模式
    final sectionPatterns = <String, PaperSectionType>{
      r'^(abstract|摘要)': PaperSectionType.abstract_,
      r'^(introduction|引言|前言|background|背景)': PaperSectionType.introduction,
      r'^(related\s+work|相关工作|文献综述|literature\s+review)': PaperSectionType.relatedWork,
      r'^(method|methodology|方法|实验方法|approach)': PaperSectionType.methodology,
      r'^(experiment|实验|实验设计|experimental\s+setup)': PaperSectionType.experiments,
      r'^(result|results|结果|实验结果|findings|发现)': PaperSectionType.results,
      r'^(discussion|讨论|分析与讨论)': PaperSectionType.discussion,
      r'^(conclusion|结论|总结|conclusions)': PaperSectionType.conclusion,
      r'^(reference|references|参考文献|bibliography)': PaperSectionType.references,
      r'^(acknowledgment|致谢)': PaperSectionType.acknowledgments,
    };

    PaperSectionType? currentType;
    String currentTitle = '';
    final currentLines = <String>[];

    void flushSection() {
      if (currentType != null && currentLines.isNotEmpty) {
        sections.add(PaperSection(
          type: currentType!,
          title: currentTitle,
          content: currentLines.join('\n').trim(),
        ));
      }
      currentLines.clear();
    }

    for (final line in lines) {
      final trimmed = line.trim();
      bool matched = false;

      for (final entry in sectionPatterns.entries) {
        final regex = RegExp(entry.key, caseSensitive: false);
        if (regex.hasMatch(trimmed)) {
          flushSection();
          currentType = entry.value;
          currentTitle = trimmed;
          matched = true;
          break;
        }
      }

      if (!matched) {
        currentLines.add(line);
      }
    }

    flushSection();

    // 如果没有检测到标准论文结构，按段落分割
    if (sections.isEmpty) {
      final paragraphs = content.split(RegExp(r'\n\s*\n'));
      for (int i = 0; i < paragraphs.length; i++) {
        final p = paragraphs[i].trim();
        if (p.isNotEmpty) {
          sections.add(PaperSection(
            type: PaperSectionType.unknown,
            title: '段落 ${i + 1}',
            content: p,
          ));
        }
      }
    }

    return sections;
  }

  /// 生成格式学习阶段的 AI 提示词
  ///
  /// 让 AI 出关于论文结构的问题，而非内容
  static String formatLearningPrompt(String paperTitle, String sectionContent) {
    return '''
你正在帮助学生进行论文的【格式学习】阶段。

论文标题/片段：$paperTitle
当前章节内容：
$sectionContent

请围绕这个章节的**写作格式和结构**出题，不要考具体内容。

考察方向（随机选一个）：
- 这个章节在论文中的作用是什么？
- 这个章节应该包含哪些要素？
- 这个章节的写作规范是什么？
- 作者为什么用这种结构组织内容？
- 这部分和论文其他部分的关系是什么？

请用 JSON 格式返回：
{
  "q": "关于格式的思考题",
  "hint": "格式相关的提示",
  "answer_points": ["要点1", "要点2", "要点3"]
}

只输出 JSON。''';
  }

  /// 生成内容学习阶段的 AI 提示词
  ///
  /// 让 AI 出关于论文核心内容的问题
  static String contentLearningPrompt(String paperTitle, String sectionContent, PaperSectionType sectionType) {
    final typeDesc = _sectionTypeDescription(sectionType);
    return '''
你正在帮助学生进行论文的【内容学习】阶段。

论文片段：$paperTitle
章节类型：$typeDesc
章节内容：
$sectionContent

请围绕这个章节的**核心内容**出题，考察学生是否真正理解了论文内容。

出题策略（根据章节类型调整）：
- 方法论章节：考察方法的原理、步骤、适用条件
- 结果章节：考察数据的含义、趋势、因果关系
- 讨论章节：考察作者的推理逻辑、结论的可靠性
- 引言章节：考察研究动机、问题定义、研究意义

请用 JSON 格式返回：
{
  "q": "关于内容的思考题",
  "hint": "内容相关的提示",
  "answer_points": ["核心要点1", "核心要点2", "核心要点3"]
}

只输出 JSON。''';
  }

  /// 生成全文总结阶段的提示词
  static String paperSummaryPrompt(String paperTitle, List<PaperSection> sections) {
    final sectionSummary = sections
        .where((s) => s.type != PaperSectionType.references &&
                      s.type != PaperSectionType.acknowledgments)
        .map((s) => '【${s.title}】${s.content.substring(0, s.content.length > 200 ? 200 : s.content.length)}...')
        .join('\n\n');

    return '''
你正在帮学生对一篇论文做整体总结。

论文标题：$paperTitle
各章节摘要：
$sectionSummary

请生成一份论文学习总结，包含：
1. 核心贡献（这篇论文解决了什么问题）
2. 方法论要点（用了什么方法）
3. 主要结果（关键发现）
4. 局限性（作者提到的或你能看出的）
5. 与其他工作的联系

请用 JSON 格式返回：
{
  "contributions": "核心贡献",
  "methods": "方法论要点",
  "results": "主要结果",
  "limitations": "局限性",
  "connections": "与其他工作的联系",
  "overall_score": 0-100（学生如果全看懂了应该能拿到的理解分数）
}

只输出 JSON。''';
  }

  static String _sectionTypeDescription(PaperSectionType type) {
    switch (type) {
      case PaperSectionType.abstract_:
        return '摘要（论文的浓缩，包含研究问题、方法、结果、结论）';
      case PaperSectionType.introduction:
        return '引言（研究背景、动机、问题定义）';
      case PaperSectionType.relatedWork:
        return '相关工作（前人研究的回顾）';
      case PaperSectionType.methodology:
        return '方法论（研究方法和设计）';
      case PaperSectionType.experiments:
        return '实验设计（实验设置和流程）';
      case PaperSectionType.results:
        return '结果（实验数据和分析）';
      case PaperSectionType.discussion:
        return '讨论（结果的解读和推理）';
      case PaperSectionType.conclusion:
        return '结论（总结和未来工作）';
      case PaperSectionType.references:
        return '参考文献';
      case PaperSectionType.acknowledgments:
        return '致谢';
      default:
        return '未知章节';
    }
  }
}

/// 论文章节类型
enum PaperSectionType {
  abstract_,
  introduction,
  relatedWork,
  methodology,
  experiments,
  results,
  discussion,
  conclusion,
  references,
  acknowledgments,
  unknown,
}

/// 论文章节
class PaperSection {
  final PaperSectionType type;
  final String title;
  final String content;

  PaperSection({
    required this.type,
    required this.title,
    required this.content,
  });

  /// 是否为核心章节（需要重点学习）
  bool get isCore =>
      type == PaperSectionType.methodology ||
      type == PaperSectionType.results ||
      type == PaperSectionType.discussion ||
      type == PaperSectionType.conclusion;

  /// 是否需要跳过（参考文献、致谢）
  bool get isSkippable =>
      type == PaperSectionType.references ||
      type == PaperSectionType.acknowledgments;
}

/// 论文学习进度
class PaperLearningProgress {
  final String paperTitle;
  final List<PaperSection> sections;
  final Set<int> completedFormatSections;  // 已完成格式学习的章节索引
  final Set<int> completedContentSections; // 已完成内容学习的章节索引
  final String? overallSummary; // 全文总结
  final int overallScore; // 总体理解分

  PaperLearningProgress({
    required this.paperTitle,
    required this.sections,
    Set<int>? completedFormatSections,
    Set<int>? completedContentSections,
    this.overallSummary,
    this.overallScore = 0,
  })  : completedFormatSections = completedFormatSections ?? {},
        completedContentSections = completedContentSections ?? {};

  /// 格式学习进度
  double get formatProgress =>
      sections.isEmpty ? 0 : completedFormatSections.length / sections.length;

  /// 内容学习进度
  double get contentProgress =>
      sections.isEmpty ? 0 : completedContentSections.length / sections.length;

  /// 总进度
  double get totalProgress => (formatProgress + contentProgress) / 2;

  /// 是否全部完成
  bool get isComplete =>
      completedFormatSections.length == sections.length &&
      completedContentSections.length == sections.length;

  /// 下一个需要格式学习的章节
  int? get nextFormatSection {
    for (int i = 0; i < sections.length; i++) {
      if (!completedFormatSections.contains(i) && !sections[i].isSkippable) {
        return i;
      }
    }
    return null;
  }

  /// 下一个需要内容学习的章节
  int? get nextContentSection {
    for (int i = 0; i < sections.length; i++) {
      if (!completedContentSections.contains(i) && !sections[i].isSkippable) {
        return i;
      }
    }
    return null;
  }
}
