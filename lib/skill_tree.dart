/// ────────────────────────────────────────────
/// 技能树系统 - 模拟"学霸的黑科技系统"式学习体验
///
/// 核心概念:
/// - SkillNode: 一个知识点 = 一个技能节点
/// - SkillTree: 某学科的完整技能树（网状结构，有前置依赖）
/// - 节点状态: 锁定 → 可学习 → 学习中 → 已掌握 → 精通
/// ────────────────────────────────────────────

/// 技能节点状态
enum SkillStatus {
  locked,      // 锁定（前置未完成）
  available,   // 可学习（前置完成，未开始）
  learning,    // 学习中（已开始，未通过）
  mastered,    // 已掌握（通关基础关）
  expert,      // 精通（挑战关也过了）
}

/// 技能节点类型
enum SkillType {
  concept,     // 概念关（基础定义、理解）
  application, // 应用关（计算、解题）
  boss,        // Boss 关（综合题、难题）
  hidden,      // 隐藏技能（特殊技巧、彩蛋）
}

/// 技能节点
class SkillNode {
  final String id;          // 唯一标识
  final String name;        // 显示名称，如 "极限的定义"
  final String description; // 简短描述
  final SkillType type;     // 节点类型
  final List<String> prerequisites; // 前置节点 ID 列表

  // 状态数据
  SkillStatus status;
  double mastery;           // 掌握度 0.0 ~ 1.0
  int xpReward;             // 通关奖励经验
  int attempts;             // 尝试次数
  int bestScore;            // 最高分
  DateTime? unlockedAt;     // 解锁时间
  DateTime? masteredAt;     // 掌握时间

  // 位置（用于技能树可视化布局）
  final int row;            // 行（纵向层级）
  final int col;            // 列（横向位置）

  SkillNode({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.prerequisites,
    required this.row,
    required this.col,
    this.status = SkillStatus.locked,
    this.mastery = 0.0,
    this.xpReward = 20,
    this.attempts = 0,
    this.bestScore = 0,
    this.unlockedAt,
    this.masteredAt,
  });

  /// 是否可以学习（前置都完成了）
  bool canStart(Map<String, SkillNode> allNodes) {
    if (status != SkillStatus.locked && status != SkillStatus.available) {
      return true;
    }
    for (final preId in prerequisites) {
      final pre = allNodes[preId];
      if (pre == null) continue;
      // 前置节点至少要 mastered 以上
      if (pre.status.index < SkillStatus.mastered.index) {
        return false;
      }
    }
    return true;
  }

  /// 更新掌握度，自动升级状态
  void updateMastery(double score, {bool isBoss = false}) {
    attempts++;
    if (score > bestScore) bestScore = (score * 100).round();

    mastery = score;
    if (score >= 0.8) {
      if (isBoss || type == SkillType.boss) {
        status = SkillStatus.expert;
      } else {
        status = SkillStatus.mastered;
      }
      masteredAt ??= DateTime.now();
    } else if (score >= 0.4) {
      status = SkillStatus.learning;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'type': type.index,
    'prerequisites': prerequisites,
    'status': status.index,
    'mastery': mastery,
    'xpReward': xpReward,
    'attempts': attempts,
    'bestScore': bestScore,
    'unlockedAt': unlockedAt?.toIso8601String(),
    'masteredAt': masteredAt?.toIso8601String(),
    'row': row,
    'col': col,
  };

  factory SkillNode.fromJson(Map<String, dynamic> json) => SkillNode(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    type: SkillType.values[json['type'] as int? ?? 0],
    prerequisites: (json['prerequisites'] as List).cast<String>(),
    status: SkillStatus.values[json['status'] as int? ?? 0],
    mastery: (json['mastery'] as num?)?.toDouble() ?? 0.0,
    xpReward: json['xpReward'] as int? ?? 20,
    attempts: json['attempts'] as int? ?? 0,
    bestScore: json['bestScore'] as int? ?? 0,
    unlockedAt: json['unlockedAt'] != null
        ? DateTime.tryParse(json['unlockedAt'] as String)
        : null,
    masteredAt: json['masteredAt'] != null
        ? DateTime.tryParse(json['masteredAt'] as String)
        : null,
    row: json['row'] as int? ?? 0,
    col: json['col'] as int? ?? 0,
  );
}

/// 技能树
class SkillTree {
  final String subject;          // 所属学科
  final String title;            // 树的标题，如 "微积分技能树"
  final String description;      // 简介
  final Map<String, SkillNode> nodes;

  SkillTree({
    required this.subject,
    required this.title,
    required this.description,
    required this.nodes,
  });

  /// 获取所有根节点（没有前置的节点）
  List<SkillNode> get rootNodes {
    return nodes.values.where((n) => n.prerequisites.isEmpty).toList();
  }

  /// 获取某节点的所有后继节点
  List<SkillNode> successorsOf(String nodeId) {
    return nodes.values.where((n) => n.prerequisites.contains(nodeId)).toList();
  }

  /// 检查并解锁新节点（当某个节点通关后调用）
  List<SkillNode> checkUnlocks() {
    final newlyUnlocked = <SkillNode>[];
    for (final node in nodes.values) {
      if (node.status == SkillStatus.locked && node.canStart(nodes)) {
        node.status = SkillStatus.available;
        node.unlockedAt = DateTime.now();
        newlyUnlocked.add(node);
      }
    }
    return newlyUnlocked;
  }

  /// 总进度（已掌握 / 总数）
  double get progress {
    if (nodes.isEmpty) return 0.0;
    final mastered = nodes.values
        .where((n) => n.status.index >= SkillStatus.mastered.index)
        .length;
    return mastered / nodes.length;
  }

  /// 已掌握节点数
  int get masteredCount =>
      nodes.values.where((n) => n.status.index >= SkillStatus.mastered.index).length;

  /// 总节点数
  int get totalCount => nodes.length;

  /// 是否全部通关
  bool get isFullyCleared =>
      nodes.values.every((n) => n.status == SkillStatus.expert);

  /// 获取下一个推荐学习的节点
  SkillNode? get nextRecommended {
    // 优先找 available 的
    final available = nodes.values.where((n) => n.status == SkillStatus.available);
    if (available.isNotEmpty) {
      // 按 row 排序，推荐最靠上的（最基础的）
      return available.reduce((a, b) => a.row < b.row ? a : b);
    }
    // 再找 learning 的
    final learning = nodes.values.where((n) => n.status == SkillStatus.learning);
    if (learning.isNotEmpty) {
      return learning.reduce((a, b) => a.mastery < b.mastery ? a : b);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'title': title,
    'description': description,
    'nodes': nodes.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory SkillTree.fromJson(Map<String, dynamic> json) => SkillTree(
    subject: json['subject'] as String,
    title: json['title'] as String? ?? '技能树',
    description: json['description'] as String? ?? '',
    nodes: (json['nodes'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, SkillNode.fromJson(Map<String, dynamic>.from(v))),
    ),
  );
}

/// ────────────────────────────────────────────
/// 预设技能树模板
/// ────────────────────────────────────────────
class SkillTreePresets {
  /// 生成微积分基础技能树
  static SkillTree calculusBasic() {
    final nodes = <String, SkillNode>{
      // ── 第 0 层：入门 ──
      'math_intro': SkillNode(
        id: 'math_intro',
        name: '数学思维入门',
        description: '什么是微积分？为什么要学它？',
        type: SkillType.concept,
        prerequisites: [],
        row: 0,
        col: 2,
        xpReward: 15,
      ),

      // ── 第 1 层：极限 ──
      'limit_intro': SkillNode(
        id: 'limit_intro',
        name: '极限的概念',
        description: '无限接近是什么意思？',
        type: SkillType.concept,
        prerequisites: ['math_intro'],
        row: 1,
        col: 1,
        xpReward: 20,
      ),
      'limit_calc': SkillNode(
        id: 'limit_calc',
        name: '极限的计算',
        description: '代入、因式分解、洛必达',
        type: SkillType.application,
        prerequisites: ['limit_intro'],
        row: 2,
        col: 0,
        xpReward: 25,
      ),
      'continuity': SkillNode(
        id: 'continuity',
        name: '连续函数',
        description: '连续的定义与性质',
        type: SkillType.concept,
        prerequisites: ['limit_intro'],
        row: 2,
        col: 2,
        xpReward: 20,
      ),

      // ── 第 2 层：导数 ──
      'deriv_intro': SkillNode(
        id: 'deriv_intro',
        name: '导数的几何意义',
        description: '切线斜率 = 变化率',
        type: SkillType.concept,
        prerequisites: ['limit_calc', 'continuity'],
        row: 3,
        col: 1,
        xpReward: 25,
      ),
      'deriv_rules': SkillNode(
        id: 'deriv_rules',
        name: '求导公式',
        description: '幂指对三角的求导法则',
        type: SkillType.application,
        prerequisites: ['deriv_intro'],
        row: 4,
        col: 0,
        xpReward: 30,
      ),
      'chain_rule': SkillNode(
        id: 'chain_rule',
        name: '链式法则',
        description: '复合函数求导',
        type: SkillType.application,
        prerequisites: ['deriv_rules'],
        row: 5,
        col: 0,
        xpReward: 25,
      ),

      // ── 第 3 层：导数应用 ──
      'deriv_app_mvt': SkillNode(
        id: 'deriv_app_mvt',
        name: '微分中值定理',
        description: '罗尔、拉格朗日、柯西',
        type: SkillType.concept,
        prerequisites: ['deriv_rules'],
        row: 4,
        col: 2,
        xpReward: 30,
      ),
      'deriv_app_opt': SkillNode(
        id: 'deriv_app_opt',
        name: '最优化问题',
        description: '求最大最小值',
        type: SkillType.boss,
        prerequisites: ['chain_rule', 'deriv_app_mvt'],
        row: 5,
        col: 2,
        xpReward: 50,
      ),

      // ── 第 4 层：积分 ──
      'integral_intro': SkillNode(
        id: 'integral_intro',
        name: '积分的概念',
        description: '面积、黎曼和',
        type: SkillType.concept,
        prerequisites: ['deriv_intro'],
        row: 6,
        col: 1,
        xpReward: 25,
      ),
      'integral_basic': SkillNode(
        id: 'integral_basic',
        name: '基本积分公式',
        description: '反导数、基本积分表',
        type: SkillType.application,
        prerequisites: ['integral_intro'],
        row: 7,
        col: 0,
        xpReward: 30,
      ),
      'integral_byparts': SkillNode(
        id: 'integral_byparts',
        name: '分部积分',
        description: '∫u dv = uv - ∫v du',
        type: SkillType.application,
        prerequisites: ['integral_basic'],
        row: 8,
        col: 0,
        xpReward: 30,
      ),

      // ── 第 5 层：微积分基本定理 ──
      'ftc': SkillNode(
        id: 'ftc',
        name: '微积分基本定理',
        description: '微分和积分是互逆的！',
        type: SkillType.boss,
        prerequisites: ['integral_basic', 'deriv_app_mvt'],
        row: 7,
        col: 2,
        xpReward: 60,
      ),

      // ── 隐藏技能 ──
      'l_hospital': SkillNode(
        id: 'l_hospital',
        name: '洛必达法则',
        description: '【隐藏】0/0 和 ∞/∞ 型极限的杀招',
        type: SkillType.hidden,
        prerequisites: ['deriv_rules', 'limit_calc'],
        row: 3,
        col: 3,
        xpReward: 20,
      ),
    };

    // 初始解锁根节点
    nodes['math_intro']!.status = SkillStatus.available;

    return SkillTree(
      subject: '高等数学',
      title: '微积分基础',
      description: '从极限到微积分基本定理，建立完整的微积分直觉',
      nodes: nodes,
    );
  }

  /// 生成 Python 编程技能树
  static SkillTree pythonBasic() {
    final nodes = <String, SkillNode>{
      'py_intro': SkillNode(
        id: 'py_intro',
        name: 'Python 入门',
        description: '什么是 Python？环境配置',
        type: SkillType.concept,
        prerequisites: [],
        row: 0,
        col: 2,
        xpReward: 15,
      ),
      'py_basics': SkillNode(
        id: 'py_basics',
        name: '基础语法',
        description: '变量、数据类型、输入输出',
        type: SkillType.application,
        prerequisites: ['py_intro'],
        row: 1,
        col: 1,
        xpReward: 20,
      ),
      'py_control': SkillNode(
        id: 'py_control',
        name: '流程控制',
        description: 'if/else、for、while',
        type: SkillType.application,
        prerequisites: ['py_basics'],
        row: 2,
        col: 0,
        xpReward: 25,
      ),
      'py_functions': SkillNode(
        id: 'py_functions',
        name: '函数',
        description: '定义、参数、返回值',
        type: SkillType.application,
        prerequisites: ['py_control'],
        row: 2,
        col: 2,
        xpReward: 25,
      ),
      'py_data_struct': SkillNode(
        id: 'py_data_struct',
        name: '数据结构',
        description: '列表、字典、元组、集合',
        type: SkillType.application,
        prerequisites: ['py_basics'],
        row: 3,
        col: 1,
        xpReward: 30,
      ),
      'py_oop': SkillNode(
        id: 'py_oop',
        name: '面向对象',
        description: '类、继承、封装',
        type: SkillType.boss,
        prerequisites: ['py_functions', 'py_data_struct'],
        row: 4,
        col: 1,
        xpReward: 50,
      ),
    };

    nodes['py_intro']!.status = SkillStatus.available;

    return SkillTree(
      subject: 'Python编程',
      title: 'Python 入门到进阶',
      description: '从零开始掌握 Python 编程',
      nodes: nodes,
    );
  }

  /// 根据学科名称匹配预设
  static SkillTree? matchPreset(String subjectName) {
    final name = subjectName.toLowerCase();
    if (name.contains('高数') || name.contains('微积分') || name.contains('高等数学')) {
      return calculusBasic();
    }
    if (name.contains('python') || name.contains('python编程') || name.contains('py')) {
      return pythonBasic();
    }
    return null;
  }
}
