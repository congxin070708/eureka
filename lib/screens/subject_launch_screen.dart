import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../api_service.dart';
import 'learn_screen.dart';

/// 学科启动页 - 系统发布任务式的开局引导
///
/// 流程:
/// 1. 系统"扫描"你的基础
/// 2. 发布主线任务 + 推荐书单
/// 3. 展示技能树概览
/// 4. 点击「接受任务」开始学习
class SubjectLaunchScreen extends ConsumerStatefulWidget {
  final String subject;
  const SubjectLaunchScreen({super.key, required this.subject});

  @override
  ConsumerState<SubjectLaunchScreen> createState() =>
      _SubjectLaunchScreenState();
}

class _SubjectLaunchScreenState extends ConsumerState<SubjectLaunchScreen>
    with TickerProviderStateMixin {
  int _step = 0;
  String? _taskTitle;
  String? _taskDescription;
  List<String>? _recommendedBooks;
  List<String>? _keyPoints;
  String? _estimatedTime;

  late AnimationController _scanCtrl;
  late AnimationController _fadeCtrl;

  @override
  void initState() {
    super.initState();
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startSystemScan();
  }

  @override
  void dispose() {
    _scanCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _startSystemScan() async {
    // 第一步：扫描动画
    await Future.delayed(const Duration(milliseconds: 1800));
    setState(() => _step = 1);
    _fadeCtrl.forward(from: 0);

    // 第二步：AI 生成任务和书单
    await _generateMission();
  }

  Future<void> _generateMission() async {
    final prompt = '''
你是"Eureka 系统"的 AI 助手。用户想要学习「${widget.subject}」。
请你以系统发布任务的口吻，生成一份学习计划。

要求：
1. 任务标题要像系统任务，例如「主线任务：微积分入门」
2. 任务描述要有代入感，像系统在发布任务
3. 推荐 2-3 本最合适的书（具体到书名+作者），说明为什么推荐
4. 列出 3-5 个核心学习要点
5. 预估学习时长（小时或天数）
6. 语气：冷静、正式、有科技感，像系统界面的提示

请用 JSON 格式返回：
{
  "taskTitle": "任务标题",
  "taskDescription": "任务描述（2-3句话，有系统感）",
  "books": [
    {"name": "书名", "author": "作者", "reason": "推荐理由"}
  ],
  "keyPoints": ["要点1", "要点2", "要点3"],
  "estimatedTime": "预估时长，如 约30小时 / 2周"
}

只输出 JSON。''';

    final result = await ApiService.chat(
      prompt,
      systemPrompt: '你是"Eureka 系统"的内置 AI，语气冷静正式，有科技感。',
      subject: widget.subject,
    );

    if (!result.success) {
      setState(() {
        _taskTitle = '主线任务：${widget.subject}入门';
        _taskDescription = '任务加载异常，但学习仍可继续。';
        _recommendedBooks = [];
        _keyPoints = [];
        _estimatedTime = '未知';
        _step = 4;
      });
      return;
    }

    final data = ApiService.parseJson(result);
    if (data != null) {
      _taskTitle = data['taskTitle']?.toString() ?? '主线任务：${widget.subject}';
      _taskDescription = data['taskDescription']?.toString() ?? '';
      _recommendedBooks = (data['books'] as List?)
              ?.map((b) =>
                  '《${b['name']}》${b['author'] != null ? ' - ${b['author']}' : ''}\n${b['reason'] ?? ''}')
              .toList() ??
          [];
      _keyPoints = (data['keyPoints'] as List?)?.cast<String>() ?? [];
      _estimatedTime = data['estimatedTime']?.toString() ?? '未知';
    } else {
      _taskTitle = '主线任务：${widget.subject}入门';
      _taskDescription = result.content;
      _recommendedBooks = [];
      _keyPoints = [];
      _estimatedTime = '未知';
    }

    setState(() {
      _step = 4;
    });
    _fadeCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部：系统标题
            _buildHeader(),
            // 主体内容
            Expanded(
              child: _step < 4
                  ? _buildScanningView()
                  : _buildMissionView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            '⚡ Eureka 系统',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent,
                letterSpacing: 1),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildScanningView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 扫描光圈
          AnimatedBuilder(
            animation: _scanCtrl,
            builder: (_, __) {
              return Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accent
                        .withValues(alpha: 0.3 + 0.3 * _scanCtrl.value),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.1),
                      blurRadius: 40 * _scanCtrl.value,
                      spreadRadius: 20 * _scanCtrl.value,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accent.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '📡',
                        style: TextStyle(
                          fontSize: 48,
                          color: AppTheme.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            '正在扫描学科数据...',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _step == 0 ? '分析「${widget.subject}」知识体系' : '生成学习路线中...',
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            width: 200,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (_, constraints) => Stack(
                children: [
                  AnimatedBuilder(
                    animation: _scanCtrl,
                    builder: (_, __) {
                      final width = constraints.maxWidth * 0.3;
                      final left =
                          (constraints.maxWidth - width) * _scanCtrl.value;
                      return Positioned(
                        left: left,
                        child: Container(
                          width: width,
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppTheme.accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: FadeTransition(
        opacity: _fadeCtrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任务卡片
            _buildTaskCard(),
            const SizedBox(height: 20),
            // 推荐书单
            if ((_recommendedBooks ?? []).isNotEmpty) _buildBooksCard(),
            const SizedBox(height: 20),
            // 核心要点
            if ((_keyPoints ?? []).isNotEmpty) _buildKeyPointsCard(),
            const SizedBox(height: 20),
            // 预估时间
            _buildEstimateCard(),
            const SizedBox(height: 28),
            // 开始按钮
            _buildStartButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.accent.withValues(alpha: 0.15),
            const Color(0xFFa855f7).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFef4444),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '主线任务',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1),
                ),
              ),
              const Spacer(),
              Text(
                '难度：⭐⭐⭐',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            _taskTitle ?? '加载中...',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            _taskDescription ?? '',
            style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book, size: 18, color: Color(0xFFf59e0b)),
              const SizedBox(width: 8),
              Text('📚 推荐书单',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...(_recommendedBooks ?? []).asMap().entries.map((e) {
            final idx = e.key;
            final book = e.value;
            final lines = book.split('\n');
            final title = lines.isNotEmpty ? lines[0] : '';
            final reason = lines.length > 1 ? lines.sublist(1).join('\n') : '';
            return Padding(
              padding: EdgeInsets.only(bottom: idx == _recommendedBooks!.length - 1 ? 0 : 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text('${idx + 1}',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary)),
                        if (reason.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(reason,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                  height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildKeyPointsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.flag, size: 18, color: Color(0xFF22c55e)),
              const SizedBox(width: 8),
              Text('🎯 核心目标',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
            ],
          ),
          const SizedBox(height: 12),
          ...(_keyPoints ?? []).map((kp) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle,
                      size: 14, color: AppTheme.taskDone),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(kp,
                        style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textPrimary,
                            height: 1.5)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEstimateCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.timer, size: 22, color: AppTheme.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('预估学习时间',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(_estimatedTime ?? '未知',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _startLearning,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
          shadowColor: AppTheme.accent.withValues(alpha: 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.play_arrow, size: 22),
            SizedBox(width: 8),
            Text(
              '接受任务，开始学习',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  void _startLearning() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LearnScreen(subject: widget.subject),
      ),
    );
  }
}
