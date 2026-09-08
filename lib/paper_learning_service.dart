import 'dart:convert';

/// ────────────────────────────────────────────
/// 论文深度学习服务 - 两阶段学习模式
///
/// 阶段一：格式学习 - 理解论文结构框架
/// 阶段二：内容学习 - 逐节精读深入理解
/// ────────────────────────────────────────────

/// 论文学习阶段
enum PaperStudyPhase {
  structure,  // 结构/格式学习阶段
  content,    // 内容深度学习阶段
  review,     // 总结回顾阶段
}

/// 论文章节
class PaperSection {
  final String id;          // 唯一标识
  final String title;       // 章节标题
  final String content;     // 章节内容
  final int level;          // 层级（0=一级标题，1=二级标题...）
  final String? parentId;   // 父章节 ID
  double mastery;           // 掌握度 0.0 ~ 1.0
  bool structureLearned;    // 是否完成了结构学习
  bool contentLearned;      // 是否完成了内容学习

  PaperSection({
    required this.id,
    required this.title,
    required this.content,
    this.level = 0,
    this.parentId,
    this.mastery = 0.0,
    this.structureLearned = false,
    this.contentLearned = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'level': level,
    'parentId': parentId,
    'mastery': mastery,
    'structureLearned': structureLearned,
    'contentLearned': contentLearned,
  };

  factory PaperSection.fromJson(Map<String, dynamic> json) => PaperSection(
    id: json['id'] as String,
    title: json['title'] as String,
    content: json['content'] as String? ?? '',
    level: json['level'] as int? ?? 0,
    parentId: json['parentId'] as String?,
    mastery: (json['mastery'] as num?)?.toDouble() ?? 0.0,
    structureLearned: json['structureLearned'] as bool? ?? false,
    contentLearned: json['contentLearned'] as bool? ?? false,
  );
}

/// 论文结构分析结果
class PaperStructure {
  final String paperTitle;       // 论文标题
  final String paperType;        // 论文类型（研究论文/综述/技术报告等）
  final String abstract;         // 摘要
  final List<String> keywords;   // 关键词
  final List<PaperSection> sections; // 章节列表
  final String overallContribution; // 论文核心贡献

  PaperStructure({
    required this.paperTitle,
    required this.paperType,
    required this.abstract,
    required this.keywords,
    required this.sections,
    required this.overallContribution,
  });

  /// 获取一级章节
  List<PaperSection> get topLevelSections =>
      sections.where((s) => s.level == 0).toList();

  /// 获取某章节的子章节
  List<PaperSection> childrenOf(String parentId) =>
      sections.where((s) => s.parentId == parentId).toList();

  /// 结构学习进度
  double get structureProgress {
    if (sections.isEmpty) return 0.0;
    final learned = sections.where((s) => s.structureLearned).length;
    return learned / sections.length;
  }

  /// 内容学习进度
  double get contentProgress {
    if (sections.isEmpty) return 0.0;
    final learned = sections.where((s) => s.contentLearned).length;
    return learned / sections.length;
  }

  /// 整体掌握度
  double get overallMastery {
    if (sections.isEmpty) return 0.0;
    return sections.map((s) => s.mastery).reduce((a, b) => a + b) / sections.length;
  }

  /// 下一个推荐学习的章节（结构阶段）
  PaperSection? nextStructureSection {
    for (final s in sections) {
      if (!s.structureLearned) return s;
    }
    return null;
  }

  /// 下一个推荐学习的章节（内容阶段）
  PaperSection? nextContentSection {
    for (final s in sections) {
      if (s.structureLearned && !s.contentLearned) return s;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'paperTitle': paperTitle,
    'paperType': paperType,
    'abstract': abstract,
    'keywords': keywords,
    'sections': sections.map((s) => s.toJson()).toList(),
    'overallContribution': overallContribution,
  };

  factory PaperStructure.fromJson(Map<String, dynamic> json) => PaperStructure(
    paperTitle: json['paperTitle'] as String? ?? '未命名论文',
    paperType: json['paperType'] as String? ?? '学术论文',
    abstract: json['abstract'] as String? ?? '',
    keywords: (json['keywords'] as List?)?.cast<String>() ?? [],
    sections: (json['sections'] as List?)
            ?.map((e) => PaperSection.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
    overallContribution: json['overallContribution'] as String? ?? '',
  );
}

/// 论文学习服务
class PaperLearningService {
  /// 判断是否为论文/学术文本
  static bool isPaperContent(String content, String fileName) {
    final lowerName = fileName.toLowerCase();
    final lowerContent = content.toLowerCase();

    // 文件名特征
    if (lowerName.contains('paper') ||
        lowerName.contains('thesis') ||
        lowerName.contains('dissertation') ||
        lowerName.contains('论文') ||
        lowerName.contains('综述') ||
        lowerName.contains('survey') ||
        lowerName.contains('research')) {
      return true;
    }

    // 内容特征：学术论文常见结构
    int score = 0;
    if (lowerContent.contains('abstract') || content.contains('摘要')) score += 2;
    if (lowerContent.contains('introduction') || content.contains('引言')) score += 2;
    if (lowerContent.contains('method') || content.contains('方法')) score += 1;
    if (lowerContent.contains('experiment') || content.contains('实验')) score += 1;
    if (lowerContent.contains('conclusion') || content.contains('结论')) score += 2;
    if (lowerContent.contains('references') || content.contains('参考文献')) score += 2;
    if (lowerContent.contains('acknowledgment') || content.contains('致谢')) score += 1;
    if (RegExp(r'\d+\.\s*(Introduction|Method|Experiment|Conclusion|Related Work)',
            caseSensitive: false).hasMatch(content)) {
      score += 3;
    }

    return score >= 5;
  }

  /// 从论文内容中解析章节结构
  static List<PaperSection> parseSections(String content) {
    final sections = <PaperSection>[];
    final lines = content.split('\n');
    final currentContent = StringBuffer();
    String? currentTitle;
    int currentLevel = 0;
    String? currentParent;
    int sectionIndex = 0;

    // 章节标题检测模式
    final headingPatterns = [
      // 1. Introduction / 1. 引言
      RegExp(r'^(\d+)\.\s+([A-Z][a-zA-Z\s]+|[\u4e00-\u9fa5]+)$'),
      // 1.1 Background / 1.1 研究背景
      RegExp(r'^(\d+\.\d+)\s+([A-Z][a-zA-Z\s]+|[\u4e00-\u9fa5]+)$'),
      // # Heading (markdown)
      RegExp(r'^(#{1,4})\s+(.+)$'),
      // Abstract / 摘要
      RegExp(r'^(Abstract|摘要)\s*$', caseSensitive: false),
      // Introduction / 引言
      RegExp(r'^(Introduction|引言|前言)\s*$', caseSensitive: false),
      // Conclusion / 结论
      RegExp(r'^(Conclusion|Conclusions|结论|总结)\s*$', caseSensitive: false),
      // References / 参考文献
      RegExp(r'^(References|Bibliography|参考文献)\s*$', caseSensitive: false),
    ];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        currentContent.writeln();
        continue;
      }

      // 检测是否为章节标题
      String? title;
      int level = 0;

      for (final pattern in headingPatterns) {
        final match = pattern.firstMatch(trimmed);
        if (match != null) {
          if (pattern.pattern.contains('#')) {
            // Markdown 标题
            level = (match.group(1)?.length ?? 1) - 1;
            title = match.group(2)?.trim();
          } else if (pattern.pattern.contains('Abstract') ||
                     pattern.pattern.contains('Introduction') ||
                     pattern.pattern.contains('Conclusion') ||
                     pattern.pattern.contains('References')) {
            // 特殊章节
            title = match.group(0)?.trim();
            level = 0;
          } else {
            // 数字编号章节
            final numStr = match.group(1) ?? '';
            title = match.group(2)?.trim();
            level = numStr.contains('.') ? 1 : 0;
          }
          break;
        }
      }

      if (title != null && title!.length < 100) {
        // 保存上一章节
        if (currentTitle != null) {
          sections.add(PaperSection(
            id: 'section_$sectionIndex',
            title: currentTitle!,
            content: currentContent.toString().trim(),
            level: currentLevel,
            parentId: currentParent,
          ));
          sectionIndex++;
        }

        // 确定父章节
        if (level == 0) {
          currentParent = null;
        } else if (sections.isNotEmpty) {
          // 找上一个 level 比当前小的作为父
          for (int i = sections.length - 1; i >= 0; i--) {
            if (sections[i].level < level) {
              currentParent = sections[i].id;
              break;
            }
          }
        }

        currentTitle = title;
        currentLevel = level;
        currentContent.clear();
      } else {
        currentContent.writeln(trimmed);
      }
    }

    // 保存最后一章节
    if (currentTitle != null && currentContent.isNotEmpty) {
      sections.add(PaperSection(
        id: 'section_$sectionIndex',
        title: currentTitle!,
        content: currentContent.toString().trim(),
        level: currentLevel,
        parentId: currentParent,
      ));
    }

    // 如果没识别出章节，就把全文当一个章节
    if (sections.isEmpty) {
      sections.add(PaperSection(
        id: 'section_0',
        title: '全文',
        content: content.trim(),
        level: 0,
      ));
    }

    return sections;
  }

  /// ── 阶段一：结构学习相关 Prompt ──

  /// 生成论文整体结构分析 Prompt
  static String buildStructureAnalysisPrompt(String content, String fileName) {
    final sample = content.length > 3000 ? content.substring(0, 3000) + '\n...（内容较长，已截取前3000字）' : content;

    return '''
你是一位经验丰富的学术导师。请分析以下论文/文献的整体结构。

文件名：$fileName

论文内容（截取）：
$sample

请分析并回答以下问题：
1. 这篇论文的标题是什么？（从内容推断或根据文件名）
2. 这是什么类型的论文？（研究论文/综述/技术报告/学位论文等）
3. 论文的核心贡献/研究目标是什么？
4. 论文的整体结构是怎样的？列出主要章节及其作用

请用 JSON 格式返回：
{
  "paperTitle": "论文标题",
  "paperType": "论文类型",
  "overallContribution": "核心贡献（100字以内）",
  "structureOverview": "整体结构概述（200字以内）",
  "keyInsights": [
    "这篇论文最重要的3个洞察点"
  ],
  "readingTips": [
    "阅读这篇论文的3条建议"
  ]
}

只输出 JSON。''';
  }

  /// 生成章节结构讲解 Prompt（格式学习阶段）
  static String buildSectionStructurePrompt(
    PaperSection section,
    PaperStructure structure,
    int sectionIndex,
    int totalSections,
  ) {
    return '''
你正在指导一位学生进行论文的「结构学习阶段」。

论文：${structure.paperTitle}
当前章节（第 $sectionIndex / $totalSections 节）：${section.title}
章节层级：${section.level == 0 ? '一级章节' : '二级章节'}

学生现在需要理解的是「这一章在论文中的作用和地位」，而不是具体内容。

请用通俗易懂的方式讲解：
1. 📍 **定位**：这一章在整篇论文中处于什么位置？承上启下的作用是什么？
2. 🎯 **目的**：作者为什么要写这一章？它要解决什么问题？
3. 🏗️ **结构**：这一章大概包含哪些内容板块？（不用具体讲内容，讲框架）
4. 🔗 **关联**：这一章和前后章节是什么关系？
5. 💡 **读法建议**：读这一章时应该重点关注什么？怎么读最高效？

语气要像一位有经验的学长，生动有趣，不要太学术。
可以用「地图」「建筑」「旅行」等比喻来帮助理解。
字数控制在 300 字以内。''';
  }

  /// 生成结构学习测试题（考察对论文框架的理解）
  static String buildStructureQuestionPrompt(
    PaperSection section,
    PaperStructure structure,
  ) {
    return '''
你正在测试学生对论文结构的理解程度。

论文：${structure.paperTitle}
章节：${section.title}

请出一道关于「论文结构理解」的思考题，考察学生是否理解这一章在整篇论文中的作用。

要求：
- 题目是开放式的，需要学生用自己的话回答
- 考察的是"为什么要有这一章"而不是"这一章写了什么"
- 引导学生从整体视角思考论文的叙事逻辑

请用 JSON 格式返回：
{
  "question": "题目内容",
  "keyPoints": ["考察的核心点1", "核心点2", "核心点3"],
  "difficulty": "easy/medium/hard"
}

只输出 JSON。''';
  }

  /// ── 阶段二：内容学习相关 Prompt ──

  /// 生成章节内容深度讲解 Prompt
  static String buildSectionContentPrompt(
    PaperSection section,
    PaperStructure structure,
    int sectionIndex,
    int totalSections,
  ) {
    final contentPreview = section.content.length > 2000
        ? section.content.substring(0, 2000) + '\n...（内容较长，已截取）'
        : section.content;

    return '''
你正在指导一位学生进行论文的「内容深度学习阶段」。

论文：${structure.paperTitle}
当前章节（第 $sectionIndex / $totalSections 节）：${section.title}

章节内容：
$contentPreview

请用深入浅出的方式讲解这一章节的核心内容：
1. 🎯 **核心观点**：这一章最主要的观点/发现是什么？（一句话概括）
2. 📝 **关键内容**：分点讲解核心内容，用通俗的语言解释专业概念
3. 🔬 **论证方式**：作者是怎么论证的？用了什么方法/证据？
4. 💡 **我的思考**：这一章有什么启发性？可以联系到什么其他知识？
5. ❓ **存疑之处**：这一章有什么地方值得商榷或深入思考？

讲解要求：
- 把复杂概念用生活中的类比解释清楚
- 重点突出，不要面面俱到
- 语气像耐心的学长，鼓励学生思考
- 字数控制在 500 字以内''';
  }

  /// 生成内容学习测试题
  static String buildContentQuestionPrompt(
    PaperSection section,
    PaperStructure structure,
  ) {
    final contentPreview = section.content.length > 1500
        ? section.content.substring(0, 1500) + '\n...（已截取）'
        : section.content;

    return '''
你正在测试学生对论文章节内容的理解深度。

论文：${structure.paperTitle}
章节：${section.title}

章节内容：
$contentPreview

请出一道深度理解题，考察学生对这一章内容的真正理解，而不是记忆。

要求：
- 开放式问题，需要学生用自己的话回答
- 考察"为什么"和"怎么做到的"，而不是"是什么"
- 可以让学生评价、对比、或者设想替代方案
- 难度适中，既有基础理解也有深度思考

请用 JSON 格式返回：
{
  "question": "题目内容",
  "keyPoints": ["考察的核心知识点1", "知识点2", "知识点3"],
  "difficulty": "easy/medium/hard",
  "questionType": "concept/application/critical"
}

只输出 JSON。''';
  }

  /// 生成评分 Prompt（适用于两个阶段）
  static String buildEvaluatePrompt({
    required String question,
    required String answer,
    required String context,
    required PaperStudyPhase phase,
    required String sectionTitle,
  }) {
    final phaseDesc = phase == PaperStudyPhase.structure
        ? '结构理解（对论文框架的把握）'
        : '内容理解（对具体知识的掌握）';

    return '''
你是一位严格但友善的学术导师。以下是一道关于论文章节的理解题，以及学生的回答。

章节：$sectionTitle
学习阶段：$phaseDesc

题目：$question

学生的回答：
$answer

相关上下文：
$context

请评估学生的回答，评分标准：
- 准确性（30分）：核心观点是否正确
- 深度（30分）：是否有深入的思考，而不只是表面理解
- 完整性（20分）：是否覆盖了关键点
- 表达（10分）：是否用自己的话清晰表达
- 批判性思维（10分）：是否有独立思考和见解（加分项）

请用 JSON 返回：
{
  "score": 0-100的整数,
  "feedback": "具体的反馈和修正，先肯定好的地方，再指出不足，最后给出提升建议",
  "correctAnswer": "参考答案要点",
  "breakdown": {
    "accuracy": 得分,
    "depth": 得分,
    "completeness": 得分,
    "expression": 得分,
    "criticalThinking": 得分
  },
  "mastered": true/false（80分以上为true）,
  "nextSuggestion": "下一步学习建议"
}

反馈语气要鼓励，即使答错了也要让学生觉得"学到了"。只输出 JSON。''';
  }

  /// ── 阶段三：总结回顾相关 Prompt ──

  /// 生成论文整体总结 Prompt
  static String buildReviewPrompt(PaperStructure structure) {
    return '''
你是一位学术导师。学生已经完成了整篇论文的学习（结构 + 内容），现在需要做一个整体回顾。

论文：${structure.paperTitle}
类型：${structure.paperType}
核心贡献：${structure.overallContribution}
章节数：${structure.sections.length}

请生成一份论文学习总结：
1. 📝 **一句话总结**：用最简练的话概括这篇论文
2. 🎯 **核心贡献**：这篇论文最重要的3个贡献/发现
3. 🔗 **知识脉络**：用一条线索把各章节内容串起来，讲述论文的"故事线"
4. 💡 **启发与收获**：这篇论文能给读者带来什么启发？可以迁移到哪些领域？
5. 📚 **延伸阅读**：如果想深入这个方向，还可以读什么？

语气要像学长的经验分享，真诚有料，不要套话。
字数控制在 600 字以内。''';
  }
}

/// 论文学习进度
class PaperLearningProgress {
  final String fileName;
  final String content;
  PaperStructure structure;
  PaperStudyPhase currentPhase;
  int currentSectionIndex;
  final List<double> sectionScores;

  PaperLearningProgress({
    required this.fileName,
    required this.content,
    required this.structure,
    this.currentPhase = PaperStudyPhase.structure,
    this.currentSectionIndex = 0,
    List<double>? sectionScores,
  }) : sectionScores = sectionScores ??
            List.filled(structure.sections.length, 0.0);

  PaperSection get currentSection =>
      structure.sections[currentSectionIndex];

  int get totalSections => structure.sections.length;

  bool get hasNextSection => currentSectionIndex < totalSections - 1;

  void nextSection() {
    if (hasNextSection) currentSectionIndex++;
  }

  void prevSection() {
    if (currentSectionIndex > 0) currentSectionIndex--;
  }

  /// 切换到下一阶段
  bool advancePhase() {
    switch (currentPhase) {
      case PaperStudyPhase.structure:
        if (structure.structureProgress >= 0.8) {
          currentPhase = PaperStudyPhase.content;
          currentSectionIndex = 0;
          return true;
        }
        return false;
      case PaperStudyPhase.content:
        if (structure.contentProgress >= 0.8) {
          currentPhase = PaperStudyPhase.review;
          return true;
        }
        return false;
      case PaperStudyPhase.review:
        return false;
    }
  }

  /// 记录当前章节得分
  void recordScore(double score) {
    if (currentSectionIndex < sectionScores.length) {
      if (score > sectionScores[currentSectionIndex]) {
        sectionScores[currentSectionIndex] = score;
      }
    }

    final section = structure.sections[currentSectionIndex];
    section.mastery = score;

    switch (currentPhase) {
      case PaperStudyPhase.structure:
        if (score >= 0.7) {
          section.structureLearned = true;
        }
        break;
      case PaperStudyPhase.content:
        if (score >= 0.7) {
          section.contentLearned = true;
        }
        break;
      case PaperStudyPhase.review:
        break;
    }
  }

  double get overallMastery => structure.overallMastery;

  Map<String, dynamic> toJson() => {
    'fileName': fileName,
    'content': content,
    'structure': structure.toJson(),
    'currentPhase': currentPhase.index,
    'currentSectionIndex': currentSectionIndex,
    'sectionScores': sectionScores,
  };

  factory PaperLearningProgress.fromJson(Map<String, dynamic> json) =>
      PaperLearningProgress(
        fileName: json['fileName'] as String,
        content: json['content'] as String,
        structure: PaperStructure.fromJson(
            Map<String, dynamic>.from(json['structure'] ?? {})),
        currentPhase: PaperStudyPhase
            .values[json['currentPhase'] as int? ?? 0],
        currentSectionIndex: json['currentSectionIndex'] as int? ?? 0,
        sectionScores: (json['sectionScores'] as List?)
                ?.map((e) => (e as num).toDouble())
                .toList() ??
            [],
      );
}
