import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'api_service.dart';
import 'smart_content_detector.dart';

/// 知识库文档
class KbDocument {
  final int? id;
  final String title;
  final String fileName;
  final String fileType; // pdf/txt/md/code
  final int totalChunks;
  final int embeddedChunks; // 已向量化的切片数
  final int totalChars;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isIndexed; // 是否已完成向量化

  KbDocument({
    this.id,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.totalChunks,
    this.embeddedChunks = 0,
    required this.totalChars,
    this.tags = const [],
    required this.createdAt,
    required this.updatedAt,
    this.isIndexed = false,
  });

  double get indexProgress =>
      totalChunks == 0 ? 0 : embeddedChunks / totalChunks;

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'fileName': fileName,
    'fileType': fileType,
    'totalChunks': totalChunks,
    'embeddedChunks': embeddedChunks,
    'totalChars': totalChars,
    'tags': jsonEncode(tags),
    'createdAt': createdAt.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'isIndexed': isIndexed ? 1 : 0,
  };

  factory KbDocument.fromMap(Map<String, dynamic> map) => KbDocument(
    id: map['id'] as int?,
    title: map['title'] as String,
    fileName: map['fileName'] as String,
    fileType: map['fileType'] as String,
    totalChunks: map['totalChunks'] as int,
    embeddedChunks: map['embeddedChunks'] as int? ?? 0,
    totalChars: map['totalChars'] as int,
    tags: (jsonDecode(map['tags'] as String? ?? '[]') as List).cast<String>(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int),
    isIndexed: (map['isIndexed'] as int? ?? 0) == 1,
  );
}

/// 知识切片（带向量）
class KbChunk {
  final int? id;
  final int docId;
  final int index; // 在文档中的序号
  final String content;
  final List<double> embedding; // 向量
  final int charStart;
  final int charEnd;

  KbChunk({
    this.id,
    required this.docId,
    required this.index,
    required this.content,
    required this.embedding,
    required this.charStart,
    required this.charEnd,
  });
}

/// 检索结果
class KbSearchResult {
  final KbChunk chunk;
  final double score; // 余弦相似度 0~1
  final String docTitle;
  final String fileName;

  KbSearchResult({
    required this.chunk,
    required this.score,
    required this.docTitle,
    required this.fileName,
  });
}

/// 知识库服务
///
/// 功能:
/// - 文档管理（增删改查）
/// - 文本切片（复用 SmartContentDetector）
/// - 向量化存储（SQLite + 余弦相似度检索）
/// - 混合检索（关键词 + 向量）
class KnowledgeBaseService {
  static Database? _db;
  static const _dbName = 'eureka_kb.db';
  static const _dbVersion = 1;

  // 切片参数
  static const int _chunkSize = 500; // 每段约 500 字
  static const int _chunkOverlap = 100; // 重叠 100 字

  static Future<Database> get _database async {
    if (_db != null) return _db!;
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);
    _db = await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
    return _db!;
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        fileName TEXT NOT NULL,
        fileType TEXT NOT NULL,
        totalChunks INTEGER NOT NULL DEFAULT 0,
        embeddedChunks INTEGER NOT NULL DEFAULT 0,
        totalChars INTEGER NOT NULL DEFAULT 0,
        tags TEXT NOT NULL DEFAULT '[]',
        createdAt INTEGER NOT NULL,
        updatedAt INTEGER NOT NULL,
        isIndexed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE chunks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        docId INTEGER NOT NULL,
        chunkIndex INTEGER NOT NULL,
        content TEXT NOT NULL,
        embedding BLOB NOT NULL,
        charStart INTEGER NOT NULL,
        charEnd INTEGER NOT NULL,
        FOREIGN KEY (docId) REFERENCES documents (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_chunks_docId ON chunks(docId)',
    );
  }

  // ── 文档管理 ──

  /// 获取所有文档
  static Future<List<KbDocument>> listDocuments() async {
    final db = await _database;
    final rows = await db.query(
      'documents',
      orderBy: 'updatedAt DESC',
    );
    return rows.map((r) => KbDocument.fromMap(r)).toList();
  }

  /// 获取单个文档
  static Future<KbDocument?> getDocument(int id) async {
    final db = await _database;
    final rows = await db.query(
      'documents',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return KbDocument.fromMap(rows.first);
  }

  /// 添加文档并开始索引（返回文档 ID + 进度回调）
  ///
  /// - [content]: 文档纯文本内容
  /// - [fileName]: 文件名
  /// - [onProgress]: 索引进度回调 (已处理切片数, 总数)
  static Future<KbDocument> addDocument({
    required String content,
    required String fileName,
    String? title,
    List<String> tags = const [],
    void Function(int embedded, int total)? onProgress,
  }) async {
    final db = await _database;
    final now = DateTime.now();
    final ext = fileName.split('.').last.toLowerCase();
    final fileType = _detectFileType(ext);

    // 切片
    final chunks = _splitText(content, fileName);
    final docTitle = title ?? _extractTitle(content, fileName);

    // 先插入文档记录
    final docId = await db.insert('documents', {
      'title': docTitle,
      'fileName': fileName,
      'fileType': fileType,
      'totalChunks': chunks.length,
      'embeddedChunks': 0,
      'totalChars': content.length,
      'tags': jsonEncode(tags),
      'createdAt': now.millisecondsSinceEpoch,
      'updatedAt': now.millisecondsSinceEpoch,
      'isIndexed': 0,
    });

    // 批量向量化并存储
    final batchSize = 10; // 每批 10 条，避免请求太大
    int embedded = 0;

    for (int i = 0; i < chunks.length; i += batchSize) {
      final batch = chunks.sublist(
        i,
        (i + batchSize).clamp(0, chunks.length),
      );
      final batchTexts = batch.map((c) => c.$1).toList();

      try {
        final embeddings = await ApiService.getEmbeddings(batchTexts);

        final batch = db.batch();
        for (int j = 0; j < batchTexts.length; j++) {
          final chunkInfo = chunks[i + j];
          final embeddingBytes = _doublesToBytes(embeddings[j]);
          batch.insert('chunks', {
            'docId': docId,
            'chunkIndex': i + j,
            'content': chunkInfo.$1,
            'embedding': embeddingBytes,
            'charStart': chunkInfo.$2,
            'charEnd': chunkInfo.$3,
          });
        }
        await batch.commit(noResult: true);

        embedded += batch.length;
        await db.update(
          'documents',
          {'embeddedChunks': embedded},
          where: 'id = ?',
          whereArgs: [docId],
        );

        onProgress?.call(embedded, chunks.length);
      } catch (e) {
        // 向量化失败，文档保持未完成状态
        rethrow;
      }
    }

    // 标记索引完成
    await db.update(
      'documents',
      {
        'embeddedChunks': embedded,
        'isIndexed': 1,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [docId],
    );

    final doc = await getDocument(docId);
    return doc!;
  }

  /// 删除文档
  static Future<void> deleteDocument(int docId) async {
    final db = await _database;
    await db.delete('chunks', where: 'docId = ?', whereArgs: [docId]);
    await db.delete('documents', where: 'id = ?', whereArgs: [docId]);
  }

  /// 更新文档标题/标签
  static Future<void> updateDocument(int docId, {
    String? title,
    List<String>? tags,
  }) async {
    final db = await _database;
    final map = <String, dynamic>{
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    };
    if (title != null) map['title'] = title;
    if (tags != null) map['tags'] = jsonEncode(tags);
    await db.update('documents', map, where: 'id = ?', whereArgs: [docId]);
  }

  // ── 检索 ──

  /// 混合检索：关键词 + 向量相似度
  ///
  /// - [query]: 查询文本
  /// - [docIds]: 限定文档范围（null = 全部）
  /// - [topK]: 返回结果数量
  static Future<List<KbSearchResult>> search(
    String query, {
    List<int>? docIds,
    int topK = 5,
  }) async {
    final db = await _database;

    // 1) 先从数据库取出所有相关切片
    final where = docIds != null && docIds.isNotEmpty
        ? 'docId IN (${List.filled(docIds.length, '?').join(',')})'
        : null;
    final whereArgs = docIds;

    final chunkRows = await db.query(
      'chunks',
      columns: ['id', 'docId', 'chunkIndex', 'content', 'embedding', 'charStart', 'charEnd'],
      where: where,
      whereArgs: whereArgs,
    );

    if (chunkRows.isEmpty) return [];

    // 2) 生成查询向量
    List<double> queryEmbedding;
    try {
      final embeddings = await ApiService.getEmbeddings([query]);
      queryEmbedding = embeddings.first;
    } catch (e) {
      // 向量生成失败，降级为纯关键词检索
      return _keywordSearch(query, chunkRows, topK);
    }

    // 3) 计算余弦相似度 + 关键词匹配分
    final results = <KbSearchResult>[];
    final queryLower = query.toLowerCase();

    // 文档 id -> title 映射
    final docMap = <int, Map<String, String>>{};
    final docRows = await db.query('documents', columns: ['id', 'title', 'fileName']);
    for (final row in docRows) {
      docMap[row['id'] as int] = {
        'title': row['title'] as String,
        'fileName': row['fileName'] as String,
      };
    }

    for (final row in chunkRows) {
      final content = row['content'] as String;
      final embedding = _bytesToDoubles(row['embedding'] as List<int>);
      final docId = row['docId'] as int;

      // 余弦相似度
      final cosSim = _cosineSimilarity(queryEmbedding, embedding);

      // 关键词匹配加分
      double keywordScore = 0;
      final contentLower = content.toLowerCase();
      final queryWords = queryLower
          .split(RegExp(r'\s+|，|。|、|：|；'))
          .where((w) => w.length >= 2)
          .toList();
      if (queryWords.isNotEmpty) {
        int matchCount = 0;
        for (final word in queryWords) {
          if (contentLower.contains(word)) matchCount++;
        }
        keywordScore = matchCount / queryWords.length * 0.3; // 关键词最高 0.3 分
      }

      final totalScore = (cosSim * 0.7 + keywordScore).clamp(0.0, 1.0);

      final docInfo = docMap[docId] ?? {'title': '未知文档', 'fileName': ''};

      results.add(KbSearchResult(
        chunk: KbChunk(
          id: row['id'] as int,
          docId: docId,
          index: row['chunkIndex'] as int,
          content: content,
          embedding: embedding,
          charStart: row['charStart'] as int,
          charEnd: row['charEnd'] as int,
        ),
        score: totalScore,
        docTitle: docInfo['title']!,
        fileName: docInfo['fileName']!,
      ));
    }

    // 按分数排序，取 topK
    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).toList();
  }

  /// 纯关键词检索降级方案
  static List<KbSearchResult> _keywordSearch(
    String query,
    List<Map<String, dynamic>> chunkRows,
    int topK,
  ) {
    final queryLower = query.toLowerCase();
    final queryWords = queryLower
        .split(RegExp(r'\s+|，|。|、|：|；'))
        .where((w) => w.length >= 2)
        .toList();

    final results = chunkRows.map((row) {
      final content = row['content'] as String;
      final contentLower = content.toLowerCase();
      int matchCount = 0;
      for (final word in queryWords) {
        if (contentLower.contains(word)) matchCount++;
      }
      final score = queryWords.isEmpty
          ? 0.0
          : matchCount / queryWords.length;

      return _MapEntryScore(row, score);
    }).toList();

    results.sort((a, b) => b.score.compareTo(a.score));
    return results.take(topK).map((e) {
      final row = e.row;
      return KbSearchResult(
        chunk: KbChunk(
          id: row['id'] as int,
          docId: row['docId'] as int,
          index: row['chunkIndex'] as int,
          content: row['content'] as String,
          embedding: [],
          charStart: row['charStart'] as int,
          charEnd: row['charEnd'] as int,
        ),
        score: e.score,
        docTitle: '未知文档',
        fileName: '',
      );
    }).toList();
  }

  // ── 辅助方法 ──

  /// 智能切片：按段落+字数切片，保留重叠
  static List<(String, int, int)> _splitText(String content, String fileName) {
    // 先让 SmartContentDetector 按语义分段
    final semanticChunks = SmartContentDetector.segment(content, fileName);

    // 如果语义段太长，再按字数切分
    final result = <(String, int, int)>[];
    int charOffset = 0;

    for (final chunk in semanticChunks) {
      if (chunk.length <= _chunkSize) {
        // 段内字数合适，直接用
        result.add((chunk, charOffset, charOffset + chunk.length));
        charOffset += chunk.length + 1; // +1 算上分隔符
      } else {
        // 段太长，按字数+重叠切
        int pos = 0;
        while (pos < chunk.length) {
          final end = (pos + _chunkSize).clamp(pos, chunk.length);
          final sub = chunk.substring(pos, end);
          result.add((sub, charOffset + pos, charOffset + end));
          if (end >= chunk.length) break;
          pos += _chunkSize - _chunkOverlap;
        }
        charOffset += chunk.length + 1;
      }
    }

    return result;
  }

  static String _detectFileType(String ext) {
    if (ext == 'pdf') return 'pdf';
    if (ext == 'md' || ext == 'txt') return 'text';
    const codeExts = {
      'dart', 'py', 'js', 'ts', 'java', 'cpp', 'c', 'h',
      'go', 'rs', 'rb', 'php', 'swift', 'kt', 'html', 'css',
      'json', 'yaml', 'yml', 'sh', 'sql',
    };
    if (codeExts.contains(ext)) return 'code';
    return 'text';
  }

  static String _extractTitle(String content, String fileName) {
    // 取第一行作为标题
    final firstLine = content
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => fileName);
    // Markdown 标题处理
    if (firstLine.startsWith('# ')) {
      return firstLine.substring(2).trim();
    }
    if (firstLine.length > 50) {
      return '${firstLine.substring(0, 50)}...';
    }
    return firstLine.isEmpty ? fileName : firstLine;
  }

  /// 余弦相似度计算
  static double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// double 列表转 bytes（SQLite BLOB 存储）
  static List<int> _doublesToBytes(List<double> values) {
    // 用 Float32List 存储，省一半空间
    final float32 = Float32List.fromList(values);
    return float32.buffer.asUint8List();
  }

  /// bytes 转 double 列表
  static List<double> _bytesToDoubles(List<int> bytes) {
    final uint8 = Uint8List.fromList(bytes);
    final float32 = Float32List.view(uint8.buffer);
    return float32.toList();
  }
}

// 辅助类：关键词检索用
class _MapEntryScore {
  final Map<String, dynamic> row;
  final double score;
  _MapEntryScore(this.row, this.score);
}
