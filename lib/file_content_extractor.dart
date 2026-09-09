import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pdfx/pdfx.dart';

/// 统一文件内容提取：把各种格式的文件转成纯文本。
///
/// 支持：
/// - PDF（pdfx 全平台解析）
/// - Word .docx / Excel .xlsx / PPT .pptx（本质是 zip+xml，用 archive 解包抽文字）
/// - 纯文本（txt/md/代码等，UTF-8）
class FileContentExtractor {
  /// 根据扩展名提取文件文本；不支持的扩展名直接抛异常。
  static Future<String> extractFromBytes(String fileName, Uint8List bytes) async {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return _extractPdf(bytes);
      case 'docx':
        return _extractDocx(bytes);
      case 'xlsx':
        return _extractXlsx(bytes);
      case 'pptx':
        return _extractPptx(bytes);
      default:
        // 纯文本
        try {
          return utf8.decode(bytes);
        } catch (e) {
          throw Exception('文件编码不支持（仅支持 UTF-8 编码的文本或 PDF/Word/Excel/PPT）');
        }
    }
  }

  static Future<String> _extractPdf(Uint8List bytes) async {
    final doc = await PdfDocument.openData(bytes);
    try {
      final buf = StringBuffer();
      for (var i = 1; i <= doc.pagesCount; i++) {
        final page = await doc.getPage(i);
        try {
          buf.writeln(await page.loadText());
        } finally {
          page.dispose();
        }
      }
      final text = buf.toString().trim();
      if (text.isEmpty) {
        throw Exception('PDF 未提取到文字（可能是扫描件/图片型 PDF）');
      }
      return text;
    } finally {
      doc.dispose();
    }
  }

  static String _extractDocx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) {
      throw Exception('docx 内缺少 word/document.xml，文件可能损坏');
    }
    final xml = utf8.decode(entry.content as List<int>);
    return _xmlToText(xml, blockTags: ['</w:p>', '</w:tr>']);
  }

  static String _extractXlsx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final buf = StringBuffer();
    // 共享字符串表
    final shared = archive.findFile('xl/sharedStrings.xml');
    if (shared != null) {
      final xml = utf8.decode(shared.content as List<int>);
      for (final m in RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(xml)) {
        buf.writeln(_unescapeXml(m.group(1)!));
      }
    }
    // 各工作表的内联文本
    for (final f in archive.files) {
      if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
        final xml = utf8.decode(f.content as List<int>);
        for (final m in RegExp(r'<t[^>]*>(.*?)</t>', dotAll: true).allMatches(xml)) {
          buf.writeln(_unescapeXml(m.group(1)!));
        }
      }
    }
    final text = buf.toString().trim();
    if (text.isEmpty) {
      throw Exception('xlsx 未提取到文字');
    }
    return text;
  }

  static String _extractPptx(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final buf = StringBuffer();
    for (final f in archive.files) {
      if (f.name.startsWith('ppt/slides/slide') && f.name.endsWith('.xml')) {
        final xml = utf8.decode(f.content as List<int>);
        buf.writeln(_xmlToText(xml, blockTags: ['</a:p>']));
      }
    }
    final text = buf.toString().trim();
    if (text.isEmpty) {
      throw Exception('pptx 未提取到文字');
    }
    return text;
  }

  static String _xmlToText(String xml, {List<String> blockTags = const []}) {
    var s = xml;
    for (final t in blockTags) {
      s = s.replaceAll(t, '\n');
    }
    s = s.replaceAll(RegExp(r'<[^>]+>'), ' ');
    s = s.replaceAll('\\n', '\n');
    s = _unescapeXml(s);
    // 压缩空白
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n\s*\n+'), '\n');
    return s.trim();
  }

  static String _unescapeXml(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
  }
}
