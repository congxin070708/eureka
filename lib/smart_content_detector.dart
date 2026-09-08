/// 智能内容检测器
///
/// 自动检测文件类型，选择最优的分段策略：
/// - 代码文件：按函数/类/块分段
/// - 论文：按章节（摘要/引言/方法/结果/...）分段
/// - 普通文档：按段落/标题分段
/// - 数学公式密集：按公式块分段
/// - 混合内容：智能切换策略
///
/// 与 file_learning_service.dart 配合使用，
/// 在分段前先检测内容类型，选择对应的分段器。
class SmartContentDetector {
  /// 检测内容类型
  static ContentType detect(String content, String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    final lower = content.toLowerCase();

    // 1. 优先检测代码
    if (_isCodeContent(content, ext)) {
      return ContentType.code;
    }

    // 2. 检测论文
    if (_isPaperContent(lower)) {
      return ContentType.paper;
    }

    // 3. 检测 Markdown/结构化文档
    if (_isMarkdown(content)) {
      return ContentType.markdown;
    }

    // 4. 检测数学内容
    if (_isMathHeavy(content)) {
      return ContentType.math;
    }

    // 5. 检测 JSON/YAML
    if (_isData(content, ext)) {
      return ContentType.data;
    }

    // 6. 默认纯文本
    return ContentType.text;
  }

  /// 根据内容类型选择分段策略
  static List<String> segment(String content, String fileName) {
    final type = detect(content, fileName);

    switch (type) {
      case ContentType.code:
        return _segmentCode(content, fileName);
      case ContentType.paper:
        return _segmentPaper(content);
      case ContentType.markdown:
        return _segmentMarkdown(content);
      case ContentType.math:
        return _segmentMath(content);
      case ContentType.data:
        return _segmentData(content);
      case ContentType.text:
        return _segmentText(content);
    }
  }

  // ── 检测逻辑 ──

  static bool _isCodeContent(String content, String ext) {
    const codeExts = {
      'dart', 'py', 'js', 'ts', 'jsx', 'tsx', 'java', 'cpp', 'c', 'h',
      'go', 'rs', 'rb', 'php', 'swift', 'kt', 'scala', 'sh', 'bash', 'sql',
    };
    if (codeExts.contains(ext)) return true;

    // 内容检测：大量代码特征
    int codeSignals = 0;
    if (RegExp(r'^\s*(def|class|func|function|void|int|public|private|import|package|require)\s', multiLine: true).hasMatch(content)) codeSignals++;
    if (RegExp(r'[{};]\s*$', multiLine: true).hasMatch(content)) codeSignals++;
    if (RegExp(r'^\s*(if|else|for|while|switch|case|return)\s*\(', multiLine: true).hasMatch(content)) codeSignals++;
    return codeSignals >= 2;
  }

  static bool _isPaperContent(String lower) {
    final keywords = [
      'abstract', '摘要', 'introduction', '引言',
      'methodology', '方法', 'results', '结果',
      'discussion', '讨论', 'conclusion', '结论',
      'references', '参考文献',
    ];
    int count = 0;
    for (final kw in keywords) {
      if (lower.contains(kw)) count++;
    }
    return count >= 3;
  }

  static bool _isMarkdown(String content) {
    int mdSignals = 0;
    if (RegExp(r'^#{1,6}\s', multiLine: true).hasMatch(content)) mdSignals++;
    if (RegExp(r'\*\*[^*]+\*\*').hasMatch(content)) mdSignals++;
    if (RegExp(r'^\s*[-*]\s', multiLine: true).hasMatch(content)) mdSignals++;
    if (RegExp(r'^\|.*\|', multiLine: true).hasMatch(content)) mdSignals++;
    if (RegExp(r'```').hasMatch(content)) mdSignals++;
    return mdSignals >= 2;
  }

  static bool _isMathHeavy(String content) {
    // LaTeX 公式标记
    final latexBlocks = RegExp(r'\$\$[\s\S]*?\$\$').allMatches(content);
    final inlineLatex = RegExp(r'(?<!\\)\$[^\n$]+\$').allMatches(content);
    final eqEnvs = RegExp(r'\\begin\{(equation|align|gather|multline)\}').allMatches(content);

    final mathCount = latexBlocks.length + inlineLatex.length + eqEnvs.length;
    final lines = content.split('\n').where((l) => l.trim().isNotEmpty).length;

    // 数学公式占比超过 15%
    return lines > 0 && (mathCount / lines) > 0.15;
  }

  static bool _isData(String content, String ext) {
    if (ext == 'json' || ext == 'yaml' || ext == 'yml' || ext == 'xml' || ext == 'csv') {
      return true;
    }
    final trimmed = content.trim();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) return true;
    if (trimmed.startsWith('<?xml')) return true;
    return false;
  }

  // ── 分段策略 ──

  static List<String> _segmentCode(String content, String fileName) {
    final lines = content.split('\n');
    final chunks = <String>[];
    final currentChunk = <String>[];
    int braceDepth = 0;
    final ext = fileName.split('.').last.toLowerCase();

    for (final line in lines) {
      final trimmed = line.trim();
      final isTopLevelDef = _isTopLevelDefinition(trimmed, ext) && braceDepth == 0;

      if (isTopLevelDef && currentChunk.isNotEmpty) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        currentChunk.clear();
        braceDepth = 0;
      }

      currentChunk.add(line);
      braceDepth += '{'.allMatches(line).length;
      braceDepth -= '}'.allMatches(line).length;

      if (currentChunk.length > 50 && braceDepth == 0) {
        final chunk = currentChunk.join('\n').trim();
        if (chunk.isNotEmpty) chunks.add(chunk);
        currentChunk.clear();
      }
    }

    final lastChunk = currentChunk.join('\n').trim();
    if (lastChunk.isNotEmpty) chunks.add(lastChunk);

    if (chunks.length < 2 && lines.length > 30) {
      return _splitByLines(lines, 30);
    }

    return _addLineNumbers(chunks);
  }

  static List<String> _segmentPaper(String content) {
    // 使用 PaperLearningService 的章节提取
    final sections = <String>[];
    final sectionPatterns = <String>[
      r'^(abstract|摘要)',
      r'^(introduction|引言|前言)',
      r'^(related\s+work|相关工作|文献综述)',
      r'^(method|methodology|方法|实验方法)',
      r'^(experiment|实验|实验设计)',
      r'^(result|results|结果|实验结果)',
      r'^(discussion|讨论)',
      r'^(conclusion|结论|总结)',
      r'^(reference|references|参考文献)',
    ];

    final lines = content.split('\n');
    final currentLines = <String>[];
    String? currentSection;

    for (final line in lines) {
      final trimmed = line.trim();
      bool matched = false;

      for (final pattern in sectionPatterns) {
        if (RegExp(pattern, caseSensitive: false).hasMatch(trimmed)) {
          if (currentSection != null && currentLines.isNotEmpty) {
            final chunk = currentLines.join('\n').trim();
            if (chunk.isNotEmpty) sections.add(chunk);
          }
          currentSection = trimmed;
          currentLines.clear();
          currentLines.add(line);
          matched = true;
          break;
        }
      }

      if (!matched) {
        currentLines.add(line);
      }
    }

    if (currentLines.isNotEmpty) {
      final chunk = currentLines.join('\n').trim();
      if (chunk.isNotEmpty) sections.add(chunk);
    }

    // 如果没有检测到章节结构，按段落分
    if (sections.isEmpty) {
      return _segmentText(content);
    }

    // 长章节再分段
    final result = <String>[];
    for (final section in sections) {
      final sectionLines = section.split('\n');
      if (sectionLines.length > 80) {
        result.addAll(_splitByLines(sectionLines, 80));
      } else {
        result.add(section);
      }
    }

    return result;
  }

  static List<String> _segmentMarkdown(String content) {
    // 按标题分段
    final sections = content.split(RegExp(r'\n(?=#{1,6}\s)'));
    final result = <String>[];

    for (final section in sections) {
      final trimmed = section.trim();
      if (trimmed.isEmpty) continue;

      // 超长段落再按空行分段
      final lines = trimmed.split('\n');
      if (lines.length > 100) {
        result.addAll(_splitByLines(lines, 100));
      } else {
        result.add(trimmed);
      }
    }

    return result.isEmpty ? _segmentText(content) : result;
  }

  static List<String> _segmentMath(String content) {
    // 按公式块和文本段落分段
    final parts = <String>[];
    final parts0 = content.split(RegExp(r'(?=\$\$)'));
    for (final p in parts0) {
      if (p.trim().isEmpty) continue;
      final lines = p.split('\n');
      if (lines.length > 60) {
        parts.addAll(_splitByLines(lines, 60));
      } else {
        parts.add(p.trim());
      }
    }
    return parts.isEmpty ? _segmentText(content) : parts;
  }

  static List<String> _segmentData(String content) {
    // JSON/YAML: 按顶层键分段
    final lines = content.split('\n');
    final chunks = <String>[];
    final currentChunk = <String>[];
    int indentLevel = 0;

    for (final line in lines) {
      final leadingSpaces = line.length - line.trimLeft().length;

      // 顶层键（缩进最小）
      if (leadingSpaces <= indentLevel &&
          line.trim().isNotEmpty &&
          !line.trim().startsWith(RegExp(r'[\]}]'))) {
        if (currentChunk.isNotEmpty && currentChunk.length > 10) {
          final chunk = currentChunk.join('\n').trim();
          if (chunk.isNotEmpty) chunks.add(chunk);
          currentChunk.clear();
        }
      }

      currentChunk.add(line);
    }

    if (currentChunk.isNotEmpty) {
      final chunk = currentChunk.join('\n').trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
    }

    if (chunks.isEmpty) {
      return _splitByLines(lines, 50);
    }

    return chunks;
  }

  static List<String> _segmentText(String content) {
    // 按空行分段
    final paragraphs = content.split(RegExp(r'\n\s*\n'));
    final chunks = <String>[];

    for (final para in paragraphs) {
      final trimmed = para.trim();
      if (trimmed.isEmpty) continue;

      final lines = trimmed.split('\n');
      if (lines.length > 80) {
        chunks.addAll(_splitByLines(lines, 80));
      } else {
        chunks.add(trimmed);
      }
    }

    return chunks;
  }

  // ── 工具方法 ──

  static bool _isTopLevelDefinition(String line, String ext) {
    final patterns = <String, RegExp>{
      'dart': RegExp(r'^(class|enum|void|int|double|String|bool|static|final|const|Future)\s'),
      'py': RegExp(r'^(def|class)\s'),
      'js': RegExp(r'^(function|class|const|let|var|export)\s'),
      'ts': RegExp(r'^(function|class|const|let|var|export|interface|type|enum)\s'),
      'java': RegExp(r'^(public|private|protected|class|interface|enum|static|final|void)\s'),
      'cpp': RegExp(r'^(class|struct|void|int|double|float|bool|template|namespace)\s'),
      'c': RegExp(r'^(void|int|double|float|char|struct|typedef|enum)\s'),
      'go': RegExp(r'^(func|type|struct|interface|package|import)\s'),
      'rs': RegExp(r'^(fn|struct|enum|impl|trait|mod|pub|use)\s'),
      'rb': RegExp(r'^(def|class|module)\s'),
      'php': RegExp(r'^(\s*)?(public|private|protected|function|class)\s'),
      'swift': RegExp(r'^(func|class|struct|enum|protocol|extension)\s'),
      'kt': RegExp(r'^(fun|class|object|interface|enum|data)\s'),
    };

    final regex = patterns[ext];
    if (regex != null && regex.hasMatch(line)) return true;

    // 通用检测：任何语言的顶级定义
    if (RegExp(r'^(def |function |class |func |fn |sub |proc )', caseSensitive: false).hasMatch(line)) {
      return true;
    }

    return false;
  }

  static List<String> _splitByLines(List<String> lines, int maxLines) {
    final chunks = <String>[];
    for (int i = 0; i < lines.length; i += maxLines) {
      final end = (i + maxLines < lines.length) ? i + maxLines : lines.length;
      final chunk = lines.sublist(i, end).join('\n').trim();
      if (chunk.isNotEmpty) chunks.add(chunk);
    }
    return chunks;
  }

  static List<String> _addLineNumbers(List<String> chunks) {
    int lineNum = 1;
    return chunks.map((chunk) {
      final lines = chunk.split('\n');
      final numbered = lines.asMap().entries.map((e) {
        return '${(lineNum + e.key).toString().padLeft(4, ' ')} | ${e.value}';
      }).join('\n');
      lineNum += lines.length;
      return numbered;
    }).toList();
  }
}

/// 内容类型
enum ContentType {
  code,     // 代码
  paper,    // 论文
  markdown, // Markdown 文档
  math,     // 数学公式密集
  data,     // JSON/YAML/XML 等数据
  text,     // 纯文本
}
