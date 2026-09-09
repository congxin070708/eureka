import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf_text/pdf_text.dart';
import '../app_theme.dart';
import '../knowledge_base_service.dart';
import '../api_service.dart';
import 'kb_document_screen.dart';

/// 知识库首页
///
/// 功能:
/// - 文档列表展示
/// - 上传文档（PDF/TXT/MD/代码）
/// - 索引进度显示
/// - 进入文档详情
class KnowledgeBaseScreen extends ConsumerStatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  ConsumerState<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends ConsumerState<KnowledgeBaseScreen> {
  List<KbDocument> _docs = [];
  bool _loading = true;
  String? _error;
  String? _indexingDocTitle;
  double _indexProgress = 0;
  bool _indexing = false;

  // 搜索状态
  final _searchCtrl = TextEditingController();
  bool _isSearching = false;
  bool _searchLoading = false;
  List<KbSearchResult> _searchResults = [];
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchLoading = true;
      _searchError = null;
    });

    try {
      final results = await KnowledgeBaseService.search(q, topK: 10);
      setState(() {
        _searchResults = results;
        _searchLoading = false;
      });
    } catch (e) {
      setState(() {
        _searchError = e.toString();
        _searchLoading = false;
      });
    }
  }

  void _closeSearch() {
    _searchCtrl.clear();
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchError = null;
    });
  }

  Future<void> _loadDocs() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final docs = await KnowledgeBaseService.listDocuments();
      setState(() {
        _docs = docs;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // 文件大小限制：10MB
  static const int _maxFileSize = 10 * 1024 * 1024;

  Future<void> _uploadFile() async {
    if (ApiService.apiKey.isEmpty) {
      _showNoApiKeyDialog();
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'txt', 'md',
        'dart', 'py', 'js', 'ts', 'java', 'cpp', 'c', 'h',
        'go', 'rs', 'rb', 'php', 'swift', 'kt',
        'html', 'css', 'json', 'yaml', 'yml',
        'sh', 'sql',
      ],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;
    final fileSize = file.size;
    final ext = fileName.split('.').last.toLowerCase();

    // 文件大小检查
    if (fileSize > _maxFileSize) {
      final sizeMb = (fileSize / 1024 / 1024).toStringAsFixed(1);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件过大（${sizeMb}MB），目前支持最大 10MB'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _indexing = true;
      _indexingDocTitle = fileName;
      _indexProgress = 0;
    });

    try {
      String content;
      if (ext == 'pdf') {
        if (file.bytes == null || file.bytes!.isEmpty) {
          throw Exception('PDF 文件读取失败，文件可能已损坏');
        }
        try {
          final pdfDoc = await PDFText.fromBytes(file.bytes!);
          content = pdfDoc.text;
          if (content.trim().isEmpty) {
            throw Exception('PDF 中没有可提取的文本（可能是扫描件或图片型 PDF）');
          }
        } catch (e) {
          if (e.toString().contains('可提取')) rethrow;
          throw Exception('PDF 解析失败：$e');
        }
      } else {
        try {
          content = utf8.decode(file.bytes ?? []);
        } catch (e) {
          throw Exception('文件编码不支持（仅支持 UTF-8 编码的文本文件）');
        }
      }

      if (content.trim().isEmpty) {
        throw Exception('文件内容为空');
      }

      // 内容过长提示（超过 5 万字可能索引很慢）
      if (content.length > 50000) {
        final estimateMin = (content.length / 500 * 1.5 / 60).ceil();
        _showLargeFileWarning(content.length, estimateMin);
        // 等待用户确认
        final confirmed = await _waitForLargeFileConfirm();
        if (!confirmed) {
          setState(() {
            _indexing = false;
            _indexingDocTitle = null;
          });
          return;
        }
      }

      await KnowledgeBaseService.addDocument(
        content: content,
        fileName: fileName,
        onProgress: (embedded, total) {
          setState(() {
            _indexProgress = total == 0 ? 0 : embedded / total;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$fileName 索引完成'),
              backgroundColor: AppTheme.accent, duration: const Duration(seconds: 2)),
        );
      }
      _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e'),
              backgroundColor: Colors.red, duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      setState(() {
        _indexing = false;
        _indexingDocTitle = null;
        _indexProgress = 0;
      });
    }
  }

  void _showNoApiKeyDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('需要 API Key', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('知识库的向量化和检索需要调用 AI 接口。\n请先在设置中配置 API Key。',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('知道了', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  bool _largeFileConfirmed = false;

  void _showLargeFileWarning(int charCount, int estimateMin) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text('文件较大', style: TextStyle(color: AppTheme.textPrimary)),
          ],
        ),
        content: Text(
          '文档约 ${(charCount / 10000).toStringAsFixed(1)} 万字，'
          '预计需要 $estimateMin 分钟完成索引。\n\n'
          '索引过程中请保持 App 在前台，'
          '期间可以切换到其他页面，但不要关闭 App。',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _largeFileConfirmed = false;
              Navigator.pop(context);
            },
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _largeFileConfirmed = true;
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.accent.withValues(alpha: 0.1),
            ),
            child: Text('继续索引', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  Future<bool> _waitForLargeFileConfirm() async {
    _largeFileConfirmed = false;
    // 等待对话框关闭
    await Future.delayed(const Duration(milliseconds: 300));
    int maxWait = 600; // 最多等 60 秒
    while (maxWait > 0) {
      await Future.delayed(const Duration(milliseconds: 100));
      maxWait--;
      // 检查对话框是否已关闭（通过 mounted 和变量）
      if (!mounted) return false;
      if (_largeFileConfirmed) return true;
      // 如果对话框已经被取消（进度重置了），返回 false
      if (!_indexing) return false;
    }
    return false;
  }

  // ── 导入示例文档 ──

  Future<void> _importSample() async {
    if (ApiService.apiKey.isEmpty) {
      _showNoApiKeyDialog();
      return;
    }

    // 检查是否已导入
    final hasSample = await KnowledgeBaseService.hasSampleDocument();
    if (hasSample) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('示例文档已导入过了'),
          backgroundColor: AppTheme.textSecondary,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() {
      _indexing = true;
      _indexingDocTitle = '网络著作权法概论';
      _indexProgress = 0;
    });

    try {
      await KnowledgeBaseService.importSampleDocument(
        onProgress: (embedded, total) {
          setState(() {
            _indexProgress = total == 0 ? 0 : embedded / total;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('示例文档导入成功！'),
            backgroundColor: AppTheme.accent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _loadDocs();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('导入失败：$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _indexing = false;
        _indexingDocTitle = null;
        _indexProgress = 0;
      });
    }
  }

  Future<void> _deleteDoc(KbDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('删除文档', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('确定要删除「${doc.title}」吗？\n索引数据也会一并删除，无法恢复。',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await KnowledgeBaseService.deleteDocument(doc.id!);
      _loadDocs();
    }
  }

  void _openDoc(KbDocument doc) {
    if (!doc.isIndexed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文档还在索引中，当前进度 ${(doc.indexProgress * 100).round()}%'),
          backgroundColor: AppTheme.textSecondary,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KbDocumentScreen(docId: doc.id!, docTitle: doc.title),
      ),
    ).then((_) => _loadDocs());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _doSearch,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '搜索知识库...',
                  hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6)),
                  border: InputBorder.none,
                ),
                textInputAction: TextInputAction.search,
              )
            : Text('知识库', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          if (!_isSearching)
            IconButton(
              icon: Icon(Icons.search, color: AppTheme.textPrimary),
              onPressed: () {
                setState(() => _isSearching = true);
              },
              tooltip: '搜索',
            ),
          if (_isSearching)
            IconButton(
              icon: Icon(Icons.close, color: AppTheme.textPrimary),
              onPressed: _closeSearch,
              tooltip: '关闭',
            ),
          IconButton(
            icon: Icon(Icons.add, color: AppTheme.accent),
            onPressed: _indexing ? null : _uploadFile,
            tooltip: '上传文档',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _indexing ? _buildIndexingFab() : FloatingActionButton(
        onPressed: _uploadFile,
        backgroundColor: AppTheme.accent,
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    // 搜索模式
    if (_isSearching) {
      return _buildSearchResults();
    }

    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text('加载失败', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _loadDocs,
              child: Text('重试', style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      );
    }

    if (_docs.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppTheme.accent,
      onRefresh: _loadDocs,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _docs.length,
        itemBuilder: (_, i) => _buildDocCard(_docs[i]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.library_books_outlined, size: 64, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text('还没有文档', style: TextStyle(fontSize: 18, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '上传论文、笔记、代码或书籍，\n建立你的专属知识库',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _uploadFile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.upload_file),
              label: const Text('上传文档'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _importSample,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('导入示例文档'),
            ),
            const SizedBox(height: 16),
            Text(
              '支持 PDF、TXT、Markdown、代码文件',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppTheme.accent),
            const SizedBox(height: 12),
            Text('正在检索...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      );
    }

    if (_searchError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppTheme.textSecondary),
              const SizedBox(height: 12),
              Text('检索失败', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              Text(_searchError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 48, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text('没有找到相关内容', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
              const SizedBox(height: 8),
              Text('试试其他关键词，或上传更多文档',
                  style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.7), fontSize: 12)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _searchResults.length,
      itemBuilder: (_, i) => _buildSearchResultCard(_searchResults[i]),
    );
  }

  Widget _buildSearchResultCard(KbSearchResult result) {
    final scorePct = (result.score * 100).round();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KbDocumentScreen(
                  docId: result.chunk.docId,
                  docTitle: result.docTitle,
                ),
              ),
            ).then((_) => _loadDocs());
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 文档名 + 相关度
                Row(
                  children: [
                    Icon(Icons.description, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        result.docTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppTheme.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$scorePct% 相关',
                        style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 内容摘要
                Text(
                  result.chunk.content.length > 120
                      ? '${result.chunk.content.substring(0, 120)}...'
                      : result.chunk.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5),
                ),
                const SizedBox(height: 6),
                Text(
                  '第 ${result.chunk.index + 1} 段',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocCard(KbDocument doc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _openDoc(doc),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 文件类型图标
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _docColor(doc.fileType).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(_docIcon(doc.fileType), color: _docColor(doc.fileType), size: 24),
                  ),
                ),
                const SizedBox(width: 14),
                // 文档信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            _formatFileSize(doc.totalChars),
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          Text('  ·  ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
                          Text(
                            '${doc.totalChunks} 段',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                          Text('  ·  ', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary.withValues(alpha: 0.5))),
                          Text(
                            _formatDate(doc.updatedAt),
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // 索引状态
                      if (!doc.isIndexed)
                        Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                value: doc.indexProgress,
                                color: AppTheme.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '索引中 ${(doc.indexProgress * 100).round()}%',
                              style: TextStyle(fontSize: 11, color: AppTheme.accent),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              '已索引',
                              style: TextStyle(fontSize: 11, color: Colors.green),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                // 操作按钮
                PopupMenuButton<String>(
                  color: AppTheme.surface,
                  icon: Icon(Icons.more_vert, color: AppTheme.textSecondary),
                  onSelected: (value) {
                    if (value == 'delete') _deleteDoc(doc);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('删除', style: TextStyle(color: Colors.red, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndexingFab() {
    return Container(
      width: 160,
      height: 56,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                value: _indexProgress,
                color: AppTheme.accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '索引中 ${(_indexProgress * 100).round()}%',
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _docIcon(String fileType) {
    switch (fileType) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'code': return Icons.code;
      default: return Icons.description;
    }
  }

  Color _docColor(String fileType) {
    switch (fileType) {
      case 'pdf': return Colors.red;
      case 'code': return Colors.blue;
      default: return AppTheme.accent;
    }
  }

  String _formatFileSize(int chars) {
    if (chars < 1000) return '$chars 字';
    if (chars < 10000) return '${(chars / 1000).toStringAsFixed(1)}k 字';
    return '${(chars / 10000).toStringAsFixed(1)} 万字';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) return '${diff.inMinutes} 分钟前';
      return '${diff.inHours} 小时前';
    }
    if (diff.inDays == 1) return '昨天';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${date.month}/${date.day}';
  }
}
