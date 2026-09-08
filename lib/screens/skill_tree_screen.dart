import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../skill_tree.dart';
import '../task_system.dart';
import '../providers/app_providers.dart';
import 'learn_screen.dart';

/// 技能树页面 - 天赋树风格可视化
///
/// 展示某学科的完整技能树，节点按行列布局，用连线表示依赖关系
class SkillTreeScreen extends ConsumerStatefulWidget {
  final String subject;
  const SkillTreeScreen({super.key, required this.subject});

  @override
  ConsumerState<SkillTreeScreen> createState() => _SkillTreeScreenState();
}

class _SkillTreeScreenState extends ConsumerState<SkillTreeScreen> {
  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(studyEngineProvider);
    final tree = engine.getSkillTree(widget.subject);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tree.title,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            Text(
              '${tree.masteredCount}/${tree.totalCount} 已掌握 · ${(tree.progress * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          // 任务入口
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(Icons.assignment, color: AppTheme.textPrimary),
                if (engine.taskManager.claimableCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFef4444),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${engine.taskManager.claimableCount}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TaskCenterScreen()),
              );
            },
          ),
        ],
      ),
      body: tree.nodes.isEmpty
          ? _buildEmptyState()
          : _buildSkillTree(tree),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.psychology_alt, size: 64, color: Color(0xFFf97316)),
          const SizedBox(height: 16),
          Text('技能树生成中...',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text('完成第一个知识点后解锁技能树',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSkillTree(SkillTree tree) {
    // 计算行列
    final nodes = tree.nodes.values.toList();
    final maxRow = nodes.map((n) => n.row).reduce((a, b) => a > b ? a : b);
    final maxCol = nodes.map((n) => n.col).reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // 进度条
          _buildProgressBar(tree),
          const SizedBox(height: 24),
          // 技能树图
          SizedBox(
            width: double.infinity,
            child: CustomPaint(
              painter: _SkillTreePainter(
                nodes: nodes,
                tree: tree,
              ),
              child: _buildNodesGrid(nodes, maxRow, maxCol, tree),
            ),
          ),
          const SizedBox(height: 24),
          // 图例
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildProgressBar(SkillTree tree) {
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
              const Icon(Icons.emoji_events, size: 20, color: Color(0xFFf59e0b)),
              const SizedBox(width: 8),
              Text('学习进度',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Text('${tree.masteredCount}/${tree.totalCount}',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: tree.progress,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tree.isFullyCleared
                ? '🎉 恭喜！已通关全部技能！'
                : '推荐下一个：${tree.nextRecommended?.name ?? "暂无"}',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNodesGrid(
      List<SkillNode> nodes, int maxRow, int maxCol, SkillTree tree) {
    // 用 Column + Row 构建网格
    return Column(
      children: List.generate(maxRow + 1, (row) {
        final rowNodes = nodes.where((n) => n.row == row).toList()
          ..sort((a, b) => a.col.compareTo(b.col));

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(maxCol + 1, (col) {
              final node = rowNodes.firstWhere(
                (n) => n.col == col,
                orElse: () => _dummyNode(),
              );
              if (node.id.isEmpty) {
                return const SizedBox(width: 80, height: 80);
              }
              return _buildSkillNode(node, tree);
            }),
          ),
        );
      }),
    );
  }

  SkillNode _dummyNode() => SkillNode(
        id: '',
        name: '',
        description: '',
        type: SkillType.concept,
        prerequisites: [],
        row: 0,
        col: 0,
      );

  Widget _buildSkillNode(SkillNode node, SkillTree tree) {
    final isLocked = node.status == SkillStatus.locked;
    final isMastered = node.status.index >= SkillStatus.mastered.index;
    final isExpert = node.status == SkillStatus.expert;
    final isAvailable = node.status == SkillStatus.available;
    final isLearning = node.status == SkillStatus.learning;
    final isBoss = node.type == SkillType.boss;
    final isHidden = node.type == SkillType.hidden;

    // 隐藏技能未解锁时不显示
    if (isHidden && isLocked) {
      return const SizedBox(width: 80, height: 80);
    }

    Color bgColor;
    Color borderColor;
    IconData icon;

    if (isExpert) {
      bgColor = const Color(0xFFf59e0b).withValues(alpha: 0.15);
      borderColor = const Color(0xFFf59e0b);
      icon = Icons.star;
    } else if (isMastered) {
      bgColor = AppTheme.taskDone.withValues(alpha: 0.15);
      borderColor = AppTheme.taskDone;
      icon = Icons.check_circle;
    } else if (isLearning) {
      bgColor = AppTheme.accent.withValues(alpha: 0.15);
      borderColor = AppTheme.accent;
      icon = Icons.autorenew;
    } else if (isAvailable) {
      bgColor = AppTheme.surfaceLight;
      borderColor = AppTheme.accent.withValues(alpha: 0.5);
      icon = Icons.play_circle_outline;
    } else {
      bgColor = AppTheme.border.withValues(alpha: 0.3);
      borderColor = AppTheme.border;
      icon = Icons.lock;
    }

    return GestureDetector(
      onTap: isLocked
          ? null
          : () => _onNodeTap(node),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                shape: isBoss ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isBoss ? BorderRadius.circular(12) : null,
                border: Border.all(color: borderColor, width: 2),
                boxShadow: isAvailable || isLearning
                    ? [
                        BoxShadow(
                          color: borderColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isLocked ? AppTheme.textSecondary : borderColor,
                size: isBoss ? 28 : 26,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isLocked ? AppTheme.textSecondary.withValues(alpha: 0.5) : AppTheme.textPrimary,
              ),
            ),
            if (isLearning)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${(node.mastery * 100).toStringAsFixed(0)}%',
                  style: TextStyle(fontSize: 10, color: AppTheme.accent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _onNodeTap(SkillNode node) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillNodeDetailSheet(
        node: node,
        subject: widget.subject,
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _legendItem(Icons.lock, '未解锁', AppTheme.textSecondary),
          _legendItem(Icons.play_circle_outline, '可学习', AppTheme.accent),
          _legendItem(Icons.check_circle, '已掌握', AppTheme.taskDone),
          _legendItem(Icons.star, '精通', const Color(0xFFf59e0b)),
        ],
      ),
    );
  }

  Widget _legendItem(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }
}

/// 技能树连线绘制
class _SkillTreePainter extends CustomPainter {
  final List<SkillNode> nodes;
  final SkillTree tree;

  _SkillTreePainter({required this.nodes, required this.tree});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // 计算每个节点的中心位置
    final nodeMap = <String, Offset>{};

    // 计算布局尺寸
    const nodeSize = 64.0;
    const rowHeight = 112.0; // 节点 + 间距
    const colWidth = 80.0;

    for (final node in nodes) {
      final x = node.col * colWidth + colWidth / 2;
      final y = node.row * rowHeight + nodeSize / 2 + 16;
      nodeMap[node.id] = Offset(x, y);
    }

    // 画连线
    for (final node in nodes) {
      for (final preId in node.prerequisites) {
        final from = nodeMap[preId];
        final to = nodeMap[node.id];
        if (from == null || to == null) continue;

        final preNode = tree.nodes[preId];
        final isActive = preNode != null &&
            preNode.status.index >= SkillStatus.mastered.index;

        paint.color = isActive
            ? AppTheme.taskDone.withValues(alpha: 0.6)
            : AppTheme.border.withValues(alpha: 0.4);

        // 贝塞尔曲线连接
        final midY = (from.dy + to.dy) / 2;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..cubicTo(from.dx, midY, to.dx, midY, to.dx, to.dy);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 技能节点详情弹窗
class _SkillNodeDetailSheet extends StatelessWidget {
  final SkillNode node;
  final String subject;

  const _SkillNodeDetailSheet({required this.node, required this.subject});

  @override
  Widget build(BuildContext context) {
    final isLocked = node.status == SkillStatus.locked;
    final isMastered = node.status.index >= SkillStatus.mastered.index;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.7,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: isMastered
                              ? AppTheme.taskDone.withValues(alpha: 0.15)
                              : AppTheme.accent.withValues(alpha: 0.1),
                          shape: node.type == SkillType.boss
                              ? BoxShape.rectangle
                              : BoxShape.circle,
                          borderRadius: node.type == SkillType.boss
                              ? BorderRadius.circular(10)
                              : null,
                          border: Border.all(
                            color: isMastered
                                ? AppTheme.taskDone
                                : AppTheme.accent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          isMastered ? Icons.check_circle : Icons.play_circle_outline,
                          color: isMastered ? AppTheme.taskDone : AppTheme.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(node.name,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text(_statusText(),
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isMastered
                                        ? AppTheme.taskDone
                                        : AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('技能描述',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Text(node.description,
                            style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                                height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _statItem('尝试次数', '${node.attempts}'),
                      _statItem('最高分', node.bestScore > 0 ? '${node.bestScore}分' : '-'),
                      _statItem('奖励经验', '+${node.xpReward}'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: isLocked
                          ? null
                          : () {
                              Navigator.pop(context);
                              // 跳转到学习页
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => LearnScreen(
                                    subject: subject,
                                    skillNodeId: node.id,
                                    isBossMode: node.type == SkillType.boss,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isLocked ? AppTheme.border : AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLocked
                            ? '🔒 未解锁'
                            : isMastered
                                ? '复习巩固'
                                : '开始学习',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText() {
    switch (node.status) {
      case SkillStatus.locked:
        return '🔒 未解锁';
      case SkillStatus.available:
        return '✨ 可学习';
      case SkillStatus.learning:
        return '📖 学习中 ${(node.mastery * 100).toStringAsFixed(0)}%';
      case SkillStatus.mastered:
        return '✅ 已掌握';
      case SkillStatus.expert:
        return '🌟 精通';
    }
  }

  Widget _statItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

/// 任务中心页面
class TaskCenterScreen extends ConsumerStatefulWidget {
  const TaskCenterScreen({super.key});

  @override
  ConsumerState<TaskCenterScreen> createState() => _TaskCenterScreenState();
}

class _TaskCenterScreenState extends ConsumerState<TaskCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.watch(studyEngineProvider);
    final dailyTasks = engine.taskManager.dailyTasks;
    final mainTasks = engine.taskManager.mainTasks;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('任务中心',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '日常任务'),
            Tab(text: '主线任务'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildTaskList(dailyTasks, engine),
          _buildTaskList(mainTasks, engine),
        ],
      ),
    );
  }

  Widget _buildTaskList(List tasks, dynamic engine) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (_, i) {
        final task = tasks[i];
        final def = TaskLibrary.get(task.taskId);
        return _buildTaskCard(task, def, engine);
      },
    );
  }

  Widget _buildTaskCard(dynamic progress, TaskDef def, dynamic engine) {
    final isCompleted = progress.status == TaskStatus.completed;
    final isClaimed = progress.status == TaskStatus.claimed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted ? AppTheme.accent.withValues(alpha: 0.3) : AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _taskIconColor(def.type).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_taskIcon(def.type),
                    size: 20, color: _taskIconColor(def.type)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(def.title,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary)),
                    const SizedBox(height: 2),
                    Text(def.description,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (isCompleted)
                GestureDetector(
                  onTap: isClaimed
                      ? null
                      : () => _claimTask(progress.taskId, engine),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isClaimed
                          ? AppTheme.border
                          : AppTheme.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isClaimed ? '已领取' : '领取',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isClaimed
                              ? AppTheme.textSecondary
                              : Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.percent,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isCompleted ? AppTheme.taskDone : AppTheme.accent,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${progress.progress}/${def.target}${def.unit}',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.card_giftcard, size: 14, color: const Color(0xFFf59e0b)),
              const SizedBox(width: 4),
              Text('奖励: ',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ...def.rewards.entries.map((e) {
                final item = ItemLibrary.get(e.key);
                if (item == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('${item.icon} ${item.name} x${e.value}',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary)),
                );
              }).toList(),
              if (def.xpReward > 0)
                Text('+${def.xpReward} XP',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFf97316),
                        fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  IconData _taskIcon(TaskType type) {
    switch (type) {
      case TaskType.daily: return Icons.wb_sunny;
      case TaskType.weekly: return Icons.date_range;
      case TaskType.main: return Icons.flag;
      case TaskType.side: return Icons.star_border;
      case TaskType.achievement: return Icons.emoji_events;
    }
  }

  Color _taskIconColor(TaskType type) {
    switch (type) {
      case TaskType.daily: return const Color(0xFFf59e0b);
      case TaskType.weekly: return const Color(0xFF3b82f6);
      case TaskType.main: return const Color(0xFFef4444);
      case TaskType.side: return const Color(0xFF22c55e);
      case TaskType.achievement: return const Color(0xFFa855f7);
    }
  }

  void _claimTask(String taskId, dynamic engine) {
    setState(() {
      final rewards = engine.taskManager.claimTask(taskId);
      for (final item in rewards) {
        engine.addItem(item.itemId, count: item.count);
      }
      final def = TaskLibrary.get(taskId);
      if (def.xpReward > 0) {
        engine.xp += def.xpReward;
        engine.totalXp += def.xpReward;
      }
      engine.save();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('🎁 奖励已发放到背包！'),
        backgroundColor: AppTheme.taskDone,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
