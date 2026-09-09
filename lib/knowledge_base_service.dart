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
/// - 示例文档导入
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

  // ── 示例文档 ──

  /// 网络著作权法概论 - 示例文档内容
  static const String sampleNetworkCopyright = '''
# 网络著作权法概论

## 第一章 著作权概述

### 1.1 著作权的概念与特征

著作权，又称版权，是指作者及其他著作权人对文学、艺术和科学作品依法享有的各项专有权利。著作权是知识产权的重要组成部分，与专利权、商标权共同构成了知识产权的三大支柱。

著作权具有以下特征：

（1）**自动产生**：作品一经创作完成，作者即自动享有著作权，无需履行任何登记或注册手续。这是著作权与专利权、商标权的重要区别——后两者需要经过申请、审查、授权等程序才能获得。

（2）**权利内容的双重性**：著作权既包含人身权（精神权利），也包含财产权（经济权利）。人身权如署名权、保护作品完整权等，与作者的身份密切相关，不可转让、不可继承；财产权如复制权、发行权等，可以转让、许可他人使用并获得报酬。

（3）**地域性**：著作权的效力原则上限于授予权利的国家或地区境内。但随着国际版权条约的发展（如《伯尔尼公约》），著作权的地域性已被大大削弱，成员国之间相互给予国民待遇。

（4）**时间性**：著作权中的财产权有保护期限限制，保护期届满后，作品进入公有领域，任何人都可以自由使用。人身权中的署名权、修改权、保护作品完整权则没有期限限制，永远受法律保护。

### 1.2 著作权法的基本原则

我国著作权法遵循以下基本原则：

（1）**保护作者权益原则**：以维护作者的权益为核心，规定了作者享有的各项人身权利和财产权利。

（2）**鼓励作品传播原则**：在保护作者权益的同时，鼓励作品的广泛传播，促进文化和科学事业的发展与繁荣。

（3）**作者利益与公众利益协调一致原则**：通过合理使用、法定许可等制度，对著作权进行必要限制，平衡作者的私人利益与社会公共利益。

（4）**与国际著作权制度发展趋势保持一致原则**：积极参与国际著作权保护体系，履行国际条约规定的义务。

### 1.3 作品的概念与构成要件

作品是指文学、艺术和科学领域内具有独创性并能以一定形式表现的智力成果。

作品的构成要件包括：

（1）**属于文学、艺术和科学领域**：著作权保护的是人类精神生产领域的智力成果，工业生产领域的发明创造由专利法保护。

（2）**具有独创性**：独创性是作品的核心要件，要求作品是作者独立创作完成的，体现了作者的选择、安排、判断和个性。独创性不要求"首创"或"前所未有"，只要是作者独立完成的，即使与他人作品"撞车"，也各自享有著作权。

（3）**能以一定形式表现**：作品必须能以某种有形形式复制、传播，如文字作品可以印刷、录音作品可以播放。纯粹存在于作者头脑中的思想、构思，不受著作权法保护。

## 第二章 著作权的内容

### 2.1 人身权（精神权利）

著作人身权是指作者基于作品的创作依法享有的以人格利益为内容的权利。

**（1）发表权**

发表权是决定作品是否公之于众的权利。"公之于众"是指著作权人自行或者经著作权人许可将作品向不特定的人公开，但不以公众知晓为构成条件。发表权具有以下特点：
- 只能行使一次（"一次用尽"原则）
- 通常与财产权的行使一同实现
- 作者生前未发表的作品，作者死亡后发表权的行使有特殊规定

**（2）署名权**

署名权是表明作者身份，在作品上署名的权利。署名权的内容包括：
- 决定是否在作品上署名
- 决定署真名还是假名、笔名
- 禁止他人在自己的作品上署名
- 禁止他人将自己的名字署在他人作品上

**（3）修改权**

修改权是修改或者授权他人修改作品的权利。修改是对作品内容的改动，包括增加、删除、调整等。修改权的行使受到一定限制，如报社、期刊社可以对作品作文字性修改、删节，但对内容的修改应当经作者许可。

**（4）保护作品完整权**

保护作品完整权是保护作品不受歪曲、篡改的权利。保护作品完整权的设立目的在于维护作品的纯正性，保护作者的人格利益不受侵害。

### 2.2 财产权（经济权利）

著作财产权是指著作权人依法享有的控制作品的使用并获得财产利益的权利。

**（1）复制权**

复制权是以印刷、复印、拓印、录音、录像、翻录、翻拍、数字化等方式将作品制作一份或者多份的权利。复制权是著作财产权中最基本、最重要的权利。

**（2）发行权**

发行权是以出售或者赠与方式向公众提供作品的原件或者复制件的权利。发行权的行使方式包括出售、出租、赠与等。

**（3）出租权**

出租权是有偿许可他人临时使用视听作品、计算机软件的原件或者复制件的权利，计算机软件不是出租的主要标的的除外。

**（4）展览权**

展览权是公开陈列美术作品、摄影作品的原件或者复制件的权利。展览权的行使涉及美术作品、摄影作品等视觉艺术作品。

**（5）表演权**

表演权是公开表演作品，以及用各种手段公开播送作品的表演的权利。表演包括现场表演和机械表演两种形式。

**（6）放映权**

放映权是通过放映机、幻灯机等技术设备公开再现美术、摄影、视听作品等的权利。

**（7）广播权**

广播权是以有线或者无线方式公开传播或者转播作品，以及通过扩音器或者其他传送符号、声音、图像的类似工具向公众传播广播的作品的权利。

**（8）信息网络传播权**

信息网络传播权是以有线或者无线方式向公众提供作品，使公众可以在其个人选定的时间和地点获得作品的权利。这是网络环境下最重要的著作财产权之一，也是网络著作权保护的核心。

信息网络传播权的核心特征是"交互式"传播，即公众可以自主选择时间和地点获取作品。这与传统的广播式传播（公众只能在广播机构安排的时间接收）形成鲜明对比。

**（9）摄制权**

摄制权是以摄制视听作品的方法将作品固定在载体上的权利。

**（10）改编权**

改编权是改变作品，创作出具有独创性的新作品的权利。改编是在原有作品的基础上进行再创作，产生新的作品。

**（11）翻译权**

翻译权是将作品从一种语言文字转换成另一种语言文字的权利。

**（12）汇编权**

汇编权是将作品或者作品的片段通过选择或者编排，汇集成新作品的权利。

## 第三章 网络著作权

### 3.1 网络著作权的概念

网络著作权是指著作权人对受著作权法保护的作品在网络环境下所享有的著作权权利。它不是一种新的、独立的著作权类型，而是传统著作权在网络环境下的延伸和体现。

网络著作权的核心是**信息网络传播权**，但不限于这一项权利。网络环境涉及的著作权权利还包括复制权、发行权、改编权、翻译权等多种权利类型。

### 3.2 网络环境下著作权保护的特殊性

与传统环境相比，网络环境下的著作权保护具有以下特殊性：

**（1）传播的便捷性与侵权的易发性**

网络使得作品的传播变得极其便捷，复制成本几乎为零，传播速度极快，传播范围极广。这也导致网络侵权行为极易发生，侵权成本低、损害后果扩散快。

**（2）侵权主体的复杂性**

网络环境下的侵权行为往往涉及多方主体：内容上传者、网络服务提供者、网络接入服务提供者等。不同主体的责任认定规则不同。

**（3）技术措施的重要性**

在网络环境下，技术措施成为著作权人保护自己权利的重要手段。我国著作权法规定，未经许可故意避开或者破坏技术措施的行为构成侵权。

**（4）权利管理信息的保护**

权利管理信息（如版权声明、作者信息、使用条件等）在网络环境下容易被删除、篡改，因此法律对权利管理信息提供专门保护。

### 3.3 信息网络传播权详解

信息网络传播权是网络著作权保护的核心权利。根据《著作权法》的规定，信息网络传播权是指以有线或者无线方式向公众提供作品，使公众可以在其个人选定的时间和地点获得作品的权利。

**构成要件：**

（1）**提供行为**：将作品置于网络服务器等设备中，使公众可以通过网络访问。"提供"不以公众实际获得为条件，只要作品处于公众可以获得的状态即构成提供。

（2）**有线或无线方式**：包括互联网、移动通信网、有线电视网等各种网络形式。

（3）**交互式传播**：公众可以在个人选定的时间和地点获得作品。这是信息网络传播权与广播权的核心区别。

**常见的信息网络传播权侵权行为：**

- 未经授权将他人作品上传至网站、APP、小程序
- 未经授权在微信公众号、微博等社交媒体平台发布他人作品
- 未经授权提供影视、音乐、图书的在线播放或下载服务
- 建立盗版资源分享网站、论坛
- 通过网盘分享侵权作品
- 深度链接、盗链他人作品

### 3.4 避风港原则

"避风港原则"是网络著作权保护中的一项重要制度，它规定了网络服务提供者在何种情况下可以免除侵权责任。

**制度来源：**

避风港原则最早源于美国1998年《数字千年版权法》（DMCA），后被世界各国广泛借鉴。我国《信息网络传播权保护条例》和《民法典》中都有类似规定。

**基本内容：**

网络服务提供者在满足以下条件时，不承担赔偿责任：

（1）**不知道也不应当知道侵权行为**：网络服务提供者没有明知或应知侵权内容存在的主观过错。

（2）**接到通知后及时采取措施**：接到权利人的合格通知后，及时删除侵权内容或者断开侵权链接。

（3）**未从侵权行为中直接获得经济利益**：如果网络服务提供者从侵权行为中直接获得经济利益，则负有更高的注意义务。

**"通知-删除"规则的运作流程：**

1. 权利人发现侵权内容后，向网络服务提供者发出合格通知
2. 网络服务提供者接到通知后，及时删除侵权内容或断开链接
3. 网络服务提供者将通知转送被控侵权人
4. 被控侵权人可以提交反通知，说明不构成侵权
5. 网络服务提供者接到反通知后，可以恢复被删除的内容
6. 双方争议通过诉讼或其他途径解决

**合格通知的构成要件：**

- 权利人的身份证明（姓名、联系方式、地址等）
- 权属证明（证明权利人享有相关著作权）
- 侵权内容的准确位置（URL链接等）
- 侵权情况的说明

### 3.5 红旗标准

"红旗标准"是避风港原则的例外和限制。如果侵权行为的事实是显而易见的，就像一面鲜艳的红旗在网络服务提供者面前飘扬，那么即使权利人没有发出通知，网络服务提供者也应当知道侵权行为的存在，不能主张避风港原则免责。

红旗标准的意义在于防止网络服务提供者滥用避风港原则，对明显的侵权行为视而不见、消极不作为。

## 第四章 网络著作权侵权

### 4.1 侵权行为的类型

网络环境下的著作权侵权行为种类繁多，常见的有以下几类：

**（1）上传型侵权**

未经著作权人许可，将他人作品上传至网络服务器，使公众可以通过网络获得。这是最典型、最常见的网络著作权侵权行为。

**（2）链接型侵权**

通过设置链接引导用户访问侵权内容。链接本身是否构成侵权需要具体分析：
- 普通链接（链向他人合法网站首页）：一般不构成侵权
- 深度链接（绕过他人网站首页直接链向具体内容页）：可能构成侵权
- 盗链（直接使用他人服务器上的资源）：构成侵权

**（3）P2P侵权**

通过P2P（点对点）技术分享侵权作品。P2P网络中的每个用户既是下载者也是上传者，都可能构成侵权。提供P2P软件或服务的平台也可能承担帮助侵权责任。

**（4）搜索引擎侵权**

搜索引擎在提供搜索服务时，可能涉及对他人作品的复制、传播。一般情况下，搜索引擎可以主张避风港原则，但对于明知或应知的侵权内容，应当及时处理。

**（5）AI相关侵权**

随着人工智能技术的发展，出现了一些新的侵权形态：
- 未经授权使用他人作品训练AI模型
- AI生成内容侵犯他人著作权
- 深度伪造（Deepfake）涉及的著作权问题

### 4.2 侵权责任的构成

网络著作权侵权责任的构成要件包括：

**（1）加害行为**：行为人实施了侵犯他人著作权的行为，如上传、传播、复制等。

**（2）损害事实**：著作权人的合法权益受到了损害，包括财产损失和精神损害。

**（3）因果关系**：加害行为与损害事实之间存在因果关系。

**（4）主观过错**：行为人主观上具有故意或过失。对于直接侵权行为，有的适用无过错责任原则；对于间接侵权（帮助侵权、教唆侵权），则要求行为人具有主观过错。

### 4.3 间接侵权

**（1）帮助侵权**

帮助侵权是指行为人虽然没有直接实施侵权行为，但为他人的直接侵权行为提供了帮助，从而构成侵权。

帮助侵权的构成要件：
- 存在直接侵权行为
- 行为人知道或有理由知道他人的侵权行为
- 行为人实施了帮助行为
- 帮助行为与损害结果之间存在因果关系

**（2）教唆侵权**

教唆侵权是指行为人通过劝说、利诱、指令等方式，教唆、引诱他人实施侵权行为。

### 4.4 侵权责任的承担方式

侵犯著作权的，应当承担以下责任：

**（1）民事责任**
- 停止侵害
- 消除影响
- 赔礼道歉
- 赔偿损失

赔偿损失的计算方式：
1. 按照权利人的实际损失计算
2. 按照侵权人的违法所得计算
3. 法定赔偿（500元以上500万元以下）

**（2）行政责任**
- 责令停止侵权行为
- 警告
- 没收违法所得
- 罚款
- 没收主要用于制作侵权复制品的材料、工具、设备等

**（3）刑事责任**

对于严重的侵犯著作权行为，构成犯罪的，依法追究刑事责任：
- 侵犯著作权罪
- 销售侵权复制品罪

## 第五章 著作权的限制

### 5.1 合理使用

合理使用是指在法律规定的特定情况下，使用他人作品可以不经著作权人许可，不向其支付报酬，但应当指明作者姓名或者名称、作品名称，并且不得影响该作品的正常使用，也不得不合理地损害著作权人的合法权益。

**合理使用的情形：**

（1）为个人学习、研究或者欣赏，使用他人已经发表的作品
（2）为介绍、评论某一作品或者说明某一问题，在作品中适当引用他人已经发表的作品
（3）为报道新闻，在报纸、期刊、广播电台、电视台等媒体中不可避免地再现或者引用已经发表的作品
（4）报纸、期刊、广播电台、电视台等媒体刊登或者播放其他报纸、期刊、广播电台、电视台等媒体已经发表的关于政治、经济、宗教问题的时事性文章，但著作权人声明不许刊登、播放的除外
（5）报纸、期刊、广播电台、电视台等媒体刊登或者播放在公众集会上发表的讲话，但作者声明不许刊登、播放的除外
（6）为学校课堂教学或者科学研究，翻译、改编、汇编、播放或者少量复制已经发表的作品，供教学或者科研人员使用，但不得出版发行
（7）国家机关为执行公务在合理范围内使用已经发表的作品
（8）图书馆、档案馆、纪念馆、博物馆、美术馆、文化馆等为陈列或者保存版本的需要，复制本馆收藏的作品
（9）免费表演已经发表的作品，该表演未向公众收取费用，也未向表演者支付报酬，且不以营利为目的
（10）对设置或者陈列在公共场所的艺术作品进行临摹、绘画、摄影、录像
（11）将中国公民、法人或者非法人组织已经发表的以国家通用语言文字创作的作品翻译成少数民族语言文字作品在国内出版发行
（12）以阅读障碍者能够感知的无障碍方式向其提供已经发表的作品
（13）法律、行政法规规定的其他情形

**"三步检验标准"：**

合理使用应当符合以下三个条件：
1. 仅限于法律规定的特定情形
2. 不得影响作品的正常使用
3. 不得不合理地损害著作权人的合法权益

### 5.2 法定许可

法定许可是指根据法律的直接规定，以特定的方式使用他人已经发表的作品，可以不经著作权人许可，但应当按照规定向著作权人支付报酬，并指明作者姓名或者名称、作品名称，并且不得侵犯著作权人依法享有的其他权利。

**法定许可的情形：**

（1）为实施义务教育和国家教育规划而编写出版教科书，汇编已经发表的作品片段或者短小的文字作品、音乐作品或者单幅的美术作品、摄影作品、图形作品
（2）报纸、期刊转载或作为文摘、资料刊登其他报刊已经刊登的作品
（3）录音制作者使用他人已经合法录制为录音制品的音乐作品制作录音制品
（4）广播电台、电视台播放他人已发表的作品
（5）广播电台、电视台播放已经出版的录音制品

### 5.3 权利穷竭

权利穷竭原则，又称首次销售原则，是指作品原件或者复制件经著作权人许可首次向公众销售后，著作权人对该特定复制件的发行权即告用尽，该复制件的所有人可以不经著作权人许可，将该复制件再次出售、出租、出借或以其他方式进行处分。

权利穷竭原则的目的在于促进商品的自由流通，防止著作权人对作品复制件的流通进行过度控制。

## 第六章 技术措施与权利管理信息

### 6.1 技术措施的保护

技术措施是指用于防止、限制未经权利人许可浏览、欣赏作品、表演、录音录像制品或者通过信息网络向公众提供作品、表演、录音录像制品的有效技术、装置或者部件。

**技术措施的类型：**

（1）**接触控制措施**：防止未经授权的用户访问作品，如密码保护、付费墙、数字水印等。

（2）**使用控制措施**：限制对作品的使用方式，如禁止复制、禁止打印、播放次数限制等。

**侵犯技术措施的行为：**

（1）故意避开或者破坏技术措施
（2）故意制造、进口或者向公众提供主要用于避开或者破坏技术措施的装置或者部件
（3）故意为他人避开或者破坏技术措施提供技术服务

**技术措施保护的例外：**

技术措施的保护不是绝对的，在以下情形下可以避开技术措施：
- 为学校课堂教学或者科学研究
- 以阅读障碍者能够感知的无障碍方式向其提供作品
- 国家机关依照行政、监察、司法程序执行公务
- 对计算机及其系统或者网络的安全性能进行测试
- 进行加密研究或者计算机软件反向工程研究

### 6.2 权利管理信息的保护

权利管理信息是指说明作品及其作者、表演及其表演者、录音录像制品及其制作者的信息，作品、表演、录音录像制品权利人的信息和使用条件的信息，以及表示上述信息的数字或者代码。

**侵犯权利管理信息的行为：**

（1）故意删除或者改变权利管理信息
（2）未经许可提供或者向公众提供明知或者应知未经许可被删除或者改变权利管理信息的作品

## 第七章 网络服务提供者的法律责任

### 7.1 网络服务提供者的分类

根据提供服务的内容不同，网络服务提供者可以分为以下几类：

**（1）网络接入服务提供者（IAP）**

提供基础的网络接入服务，如电信运营商提供的宽带接入服务。这类服务提供者一般对网络上传输的内容不进行控制，因此其责任受到严格限制。

**（2）网络平台服务提供者（IPP）**

提供信息存储空间、搜索、链接等服务的平台，如微博、微信、百度、淘宝等。这类服务提供者是避风港原则的主要适用对象。

**（3）网络内容服务提供者（ICP）**

自己创作、编辑、提供网络内容的服务提供者。这类服务提供者对其提供的内容承担直接侵权责任，不适用避风港原则。

### 7.2 不同类型服务提供者的责任认定

**（1）网络接入服务提供者**

网络接入服务提供者对网络传输的内容一般不承担侵权责任，因为其只是提供"通道"服务，对传输的内容没有编辑和控制能力。但在接到通知后，应当采取必要措施（如断开链接）。

**（2）信息存储空间服务提供者**

信息存储空间服务提供者（如网盘、博客平台、视频网站等）对用户上传的内容适用避风港原则。但在以下情形下，应当承担侵权责任：
- 明知或应知用户上传的内容侵权
- 从用户的侵权行为中直接获得经济利益
- 接到权利人通知后未及时删除

**（3）搜索、链接服务提供者**

搜索、链接服务提供者一般不直接提供内容，只是提供信息定位服务。对于搜索、链接指向的侵权内容，适用避风港原则。但明知或应知所链接的内容侵权的，应当承担共同侵权责任。

### 7.3 "通知-删除"规则的具体适用

**通知的形式和内容：**

权利人的通知应当采用书面形式，并包含以下内容：
- 权利人的姓名（名称）、联系方式和地址
- 要求删除或者断开链接的侵权作品的名称和网络地址
- 构成侵权的初步证明材料

**反通知：**

网络用户接到转送的通知后，可以向网络服务提供者提交书面通知，说明其行为不构成侵权。反通知应当包含以下内容：
- 网络用户的姓名（名称）、联系方式和地址
- 要求恢复的作品的名称和网络地址
- 不构成侵权的初步证明材料

**错误通知的责任：**

权利人因错误通知造成网络用户或者网络服务提供者损害的，应当承担侵权责任。

## 第八章 人工智能与著作权

### 8.1 AI生成内容的著作权问题

随着人工智能技术的快速发展，AI生成内容（AIGC）的著作权问题成为当前法学界和产业界讨论的热点。

**主要争议：**

（1）**AI生成内容是否构成作品？**

一种观点认为，只要AI生成内容具有独创性，就应当构成作品，受著作权法保护。另一种观点认为，作品必须是人类创作的，AI不是人类主体，其生成的内容不构成作品。

（2）**如果构成作品，著作权归谁？**

可能的归属方案：
- 归AI的设计者/开发者
- 归AI的使用者/投资者
- 归AI本身（法律赋予AI主体资格）
- 进入公有领域

（3）**AI生成内容是否侵犯他人著作权？**

AI模型在训练过程中需要使用大量数据，如果这些数据包含受著作权保护的作品，可能构成对复制权的侵犯。但也有观点认为，这种使用属于合理使用。

### 8.2 AI训练数据的著作权问题

AI模型训练需要使用海量数据，其中很多是受著作权保护的作品。这引发了一系列法律问题：

**（1）训练数据的使用是否构成侵权？**

这是一个存在重大争议的问题。支持构成侵权的理由：
- 未经许可复制了他人作品
- 可能影响作品的正常使用
- 可能损害著作权人的合法权益

支持不构成侵权（合理使用）的理由：
- AI训练是转换性使用，目的不同于原作品
- 不会替代原作品的市场
- 有利于技术创新和社会公共利益

**（2）合理使用的适用边界在哪里？**

判断AI训练是否构成合理使用，需要考虑以下因素：
- 使用的目的和性质（是否具有转换性）
- 被使用作品的性质
- 使用部分的数量和质量
- 使用对作品潜在市场或价值的影响

### 8.3 深度伪造（Deepfake）与著作权

深度伪造技术利用人工智能生成逼真的虚假图像、视频、音频等内容，涉及多个法律领域的问题。

从著作权角度看：
- 深度伪造可能涉及对原作品的改编权
- 深度伪造可能涉及侵犯表演者权
- 深度伪造生成的内容是否享有著作权存在争议
- 深度伪造还可能涉及肖像权、名誉权、隐私权等人格权

## 第九章 网络著作权的国际保护

### 9.1 主要国际公约

**（1）《伯尔尼公约》**

《保护文学和艺术作品伯尔尼公约》是最重要的国际著作权公约，确立了著作权国际保护的基本原则：
- 国民待遇原则
- 自动保护原则
- 独立保护原则
- 最低保护标准原则

**（2）《世界版权公约》**

由联合国教科文组织主持制定，保护水平低于《伯尔尼公约》。

**（3）WIPO因特网条约**

包括《世界知识产权组织版权条约》（WCT）和《世界知识产权组织表演和录音制品条约》（WPPT），专门针对数字环境和网络环境下的著作权保护问题。这两个条约被称为"因特网条约"，规定了：
- 向公众传播权（信息网络传播权）
- 技术措施的保护
- 权利管理信息的保护

### 9.2 跨境侵权的法律适用

网络的无国界性导致网络著作权侵权往往具有跨境性，涉及法律适用和管辖权问题。

**法律适用：**

一般情况下，著作权侵权适用被请求保护地法。即侵权行为在哪个国家造成损害，就适用哪个国家的著作权法。

**管辖权：**

对于网络著作权侵权案件，管辖法院的确定也是一个复杂问题。一般可以考虑以下连接点：
- 被告住所地
- 侵权行为实施地
- 侵权结果发生地
- 服务器所在地

## 第十章 著作权集体管理

### 10.1 集体管理的概念与意义

著作权集体管理是指著作权人授权著作权集体管理组织，以自己的名义为著作权人和与著作权有关的权利人行使权利，包括：
- 与使用者订立著作权或者与著作权有关的权利许可使用合同
- 向使用者收取使用费
- 向权利人转付使用费
- 进行涉及著作权或者与著作权有关的权利的诉讼、仲裁等

**集体管理的意义：**

（1）降低交易成本：使用者只需要与一个集体管理组织打交道，就可以获得大量作品的授权。

（2）提高保护效率：集体管理组织有专业团队和资源，能够更有效地维护权利人的权益。

（3）解决海量授权问题：在网络环境下，作品的使用方式多种多样，使用量巨大，单靠权利人个人无法有效管理。

### 10.2 我国的著作权集体管理组织

我国目前的著作权集体管理组织包括：
- 中国音乐著作权协会
- 中国音像著作权集体管理协会
- 中国文字著作权协会
- 中国摄影著作权协会
- 中国电影著作权协会

这些集体管理组织在各自的领域内代表权利人行使权利，收取使用费，并按照一定的分配规则向权利人分配。

---

**结语**

网络著作权保护是一个不断发展的领域。随着技术的进步，新的作品形式、新的传播方式、新的使用场景不断涌现，给著作权保护带来新的挑战。了解网络著作权的基本概念和法律规则，不仅有助于保护自己的合法权益，也有助于在创新创业过程中规避法律风险，实现权利保护与产业发展的平衡。
''';

  /// 示例文档列表
  static const List<Map<String, String>> sampleDocuments = [
    {
      'title': '网络著作权法概论',
      'fileName': '网络著作权法概论.md',
      'content': sampleNetworkCopyright,
      'tags': '著作权,网络法,知识产权',
    },
  ];

  /// 导入示例文档（网络著作权法概论）
  ///
  /// 返回导入的文档，带进度回调
  static Future<KbDocument> importSampleDocument({
    void Function(int embedded, int total)? onProgress,
  }) async {
    final sample = sampleDocuments.first;
    final doc = await addDocument(
      content: sample['content']!,
      fileName: sample['fileName']!,
      onProgress: onProgress,
    );
    return doc;
  }

  /// 检查示例文档是否已导入
  static Future<bool> hasSampleDocument() async {
    final docs = await listDocuments();
    return docs.any((d) => d.fileName == sampleDocuments.first['fileName']);
  }

  // ── 检索 ──

  /// 按序号获取文档切片内容（引导式阅读用）
  ///
  /// 返回 [index] 位置的切片，如果越界返回 null
  static Future<KbChunk?> getChunkByIndex(int docId, int index) async {
    final db = await _database;
    final rows = await db.query(
      'chunks',
      where: 'docId = ? AND chunkIndex = ?',
      whereArgs: [docId, index],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return KbChunk(
      id: row['id'] as int,
      docId: docId,
      index: row['chunkIndex'] as int,
      content: row['content'] as String,
      embedding: _bytesToDoubles(row['embedding'] as List<int>),
      charStart: row['charStart'] as int,
      charEnd: row['charEnd'] as int,
    );
  }

  /// 批量获取文档切片（按序号范围）
  static Future<List<KbChunk>> getChunksRange(int docId, {int start = 0, int? end}) async {
    final db = await _database;
    final where = StringBuffer('docId = ?');
    final args = <dynamic>[docId];
    if (end != null) {
      where.write(' AND chunkIndex >= ? AND chunkIndex < ?');
      args.addAll([start, end]);
    } else {
      where.write(' AND chunkIndex >= ?');
      args.add(start);
    }
    final rows = await db.query(
      'chunks',
      where: where.toString(),
      whereArgs: args,
      orderBy: 'chunkIndex ASC',
    );
    return rows.map((row) => KbChunk(
      id: row['id'] as int,
      docId: docId,
      index: row['chunkIndex'] as int,
      content: row['content'] as String,
      embedding: _bytesToDoubles(row['embedding'] as List<int>),
      charStart: row['charStart'] as int,
      charEnd: row['charEnd'] as int,
    )).toList();
  }

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
