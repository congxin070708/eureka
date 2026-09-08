import 'dart:math';

/// ────────────────────────────────────────────
/// 任务系统 + 抽奖系统 + 道具背包
///
/// 核心循环:
/// 完成任务 → 获得奖励(经验/积分/抽奖券) → 抽奖 → 获得道具 → 更好地完成任务
/// ────────────────────────────────────────────

// ==================== 道具系统 ====================

/// 道具稀有度
enum ItemRarity {
  common,    // 普通 - 灰色
  rare,      // 稀有 - 蓝色
  epic,      // 史诗 - 紫色
  legendary, // 传说 - 金色
}

/// 道具类型
enum ItemType {
  expCard,       // 经验卡（双倍经验）
  hintCard,      // 提示卡（答题时多给一个提示）
  skipCard,      // 跳过卡（直接跳过当前题）
  gachaTicket,   // 抽奖券
  title,         // 称号
  unlockKey,     // 解锁钥匙（解锁隐藏技能）
  consumable,    // 消耗品
}

/// 道具定义
class ItemDef {
  final String id;
  final String name;
  final String description;
  final ItemType type;
  final ItemRarity rarity;
  final String icon; // emoji 图标
  final int value;   // 效果数值（如经验卡倍数）

  const ItemDef({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.rarity,
    required this.icon,
    this.value = 1,
  });
}

/// 道具定义库
class ItemLibrary {
  static const Map<String, ItemDef> all = {
    'exp_card_s': ItemDef(
      id: 'exp_card_s',
      name: '初级经验卡',
      description: '下一次答题获得双倍经验，持续1题',
      type: ItemType.expCard,
      rarity: ItemRarity.common,
      icon: '📗',
      value: 2,
    ),
    'exp_card_m': ItemDef(
      id: 'exp_card_m',
      name: '中级经验卡',
      description: '接下来5道题经验翻倍',
      type: ItemType.expCard,
      rarity: ItemRarity.rare,
      icon: '📘',
      value: 2,
    ),
    'hint_card': ItemDef(
      id: 'hint_card',
      name: '提示卡',
      description: '使用后获得额外提示',
      type: ItemType.hintCard,
      rarity: ItemRarity.common,
      icon: '💡',
    ),
    'skip_card': ItemDef(
      id: 'skip_card',
      name: '跳过卡',
      description: '直接跳过当前题目，不算失败',
      type: ItemType.skipCard,
      rarity: ItemRarity.rare,
      icon: '⏭️',
    ),
    'gacha_ticket': ItemDef(
      id: 'gacha_ticket',
      name: '抽奖券',
      description: '可以进行一次抽奖',
      type: ItemType.gachaTicket,
      rarity: ItemRarity.rare,
      icon: '🎫',
    ),
    'unlock_key': ItemDef(
      id: 'unlock_key',
      name: '解锁钥匙',
      description: '解锁一个隐藏技能节点',
      type: ItemType.unlockKey,
      rarity: ItemRarity.epic,
      icon: '🔑',
    ),
    'title_newbie': ItemDef(
      id: 'title_newbie',
      name: '称号：初级学者',
      description: '完成第一个任务解锁',
      type: ItemType.title,
      rarity: ItemRarity.common,
      icon: '🎓',
    ),
    'title_scholar': ItemDef(
      id: 'title_scholar',
      name: '称号：求知者',
      description: '掌握10个技能解锁',
      type: ItemType.title,
      rarity: ItemRarity.rare,
      icon: '📚',
    ),
    'title_master': ItemDef(
      id: 'title_master',
      name: '称号：学霸',
      description: '通关一整棵技能树解锁',
      type: ItemType.title,
      rarity: ItemRarity.legendary,
      icon: '👑',
    ),
  };

  static ItemDef? get(String id) => all[id];
}

/// 背包中的道具（带数量）
class InventoryItem {
  final String itemId;
  int count;

  InventoryItem({required this.itemId, this.count = 1});

  ItemDef get def => ItemLibrary.get(itemId)!;

  Map<String, dynamic> toJson() => {'itemId': itemId, 'count': count};

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    itemId: json['itemId'] as String,
    count: json['count'] as int? ?? 1,
  );
}

// ==================== 抽奖系统 ====================

/// 奖池条目
class GachaEntry {
  final String itemId;
  final double weight; // 权重
  final int minCount;  // 最少获得数量
  final int maxCount;  // 最多获得数量

  const GachaEntry({
    required this.itemId,
    required this.weight,
    this.minCount = 1,
    this.maxCount = 1,
  });
}

/// 抽奖结果
class GachaResult {
  final String itemId;
  final int count;
  final ItemDef item;
  final bool isNew; // 是否是新获得的（之前没有）
  final bool isPityHit; // 是否触发了保底

  GachaResult({
    required this.itemId,
    required this.count,
    required this.item,
    required this.isNew,
    this.isPityHit = false,
  });
}

/// 抽奖系统
class GachaSystem {
  static const List<GachaEntry> _pool = [
    GachaEntry(itemId: 'exp_card_s', weight: 30, minCount: 1, maxCount: 2),
    GachaEntry(itemId: 'hint_card', weight: 25, minCount: 1, maxCount: 3),
    GachaEntry(itemId: 'skip_card', weight: 15, minCount: 1, maxCount: 1),
    GachaEntry(itemId: 'exp_card_m', weight: 12, minCount: 1, maxCount: 1),
    GachaEntry(itemId: 'gacha_ticket', weight: 10, minCount: 1, maxCount: 1),
    GachaEntry(itemId: 'unlock_key', weight: 5, minCount: 1, maxCount: 1),
    GachaEntry(itemId: 'title_scholar', weight: 2, minCount: 1, maxCount: 1),
    GachaEntry(itemId: 'title_master', weight: 1, minCount: 1, maxCount: 1),
  ];

  /// 保底阈值
  static const int softPityEpic = 50;    // 50 抽没出史诗+，开始提升概率
  static const int hardPityEpic = 70;    // 70 抽没出史诗+，硬保底必出
  static const int softPityLegend = 70;  // 70 抽没出传说，开始提升概率
  static const int hardPityLegend = 100; // 100 抽没出传说，硬保底必出

  /// 计算带保底加成后的权重表
  ///
  /// [pityEpic] 距离上次出史诗+的抽数
  /// [pityLegend] 距离上次出传说的抽数
  static List<GachaEntry> _poolWithPity(int pityEpic, int pityLegend) {
    final pool = _pool.map((e) => GachaEntry(
      itemId: e.itemId,
      weight: e.weight,
      minCount: e.minCount,
      maxCount: e.maxCount,
    )).toList();

    // 硬保底：必出传说
    if (pityLegend >= hardPityLegend) {
      // 只留传说
      return pool.where((e) =>
        ItemLibrary.get(e.itemId)!.rarity == ItemRarity.legendary
      ).toList();
    }

    // 硬保底：必出史诗+
    if (pityEpic >= hardPityEpic) {
      // 只留史诗和传说
      return pool.where((e) {
        final r = ItemLibrary.get(e.itemId)!.rarity;
        return r == ItemRarity.epic || r == ItemRarity.legendary;
      }).toList();
    }

    // 软保底：提升史诗+概率
    if (pityEpic >= softPityEpic) {
      final boost = 1.0 + (pityEpic - softPityEpic) * 0.15; // 每抽 +15%
      for (int i = 0; i < pool.length; i++) {
        final e = pool[i];
        final r = ItemLibrary.get(e.itemId)!.rarity;
        if (r == ItemRarity.epic || r == ItemRarity.legendary) {
          pool[i] = GachaEntry(
            itemId: e.itemId,
            weight: e.weight * boost,
            minCount: e.minCount,
            maxCount: e.maxCount,
          );
        }
      }
    }

    // 软保底：提升传说概率
    if (pityLegend >= softPityLegend) {
      final boost = 1.0 + (pityLegend - softPityLegend) * 0.1; // 每抽 +10%
      for (int i = 0; i < pool.length; i++) {
        final e = pool[i];
        final r = ItemLibrary.get(e.itemId)!.rarity;
        if (r == ItemRarity.legendary) {
          pool[i] = GachaEntry(
            itemId: e.itemId,
            weight: e.weight * boost,
            minCount: e.minCount,
            maxCount: e.maxCount,
          );
        }
      }
    }

    return pool;
  }

  /// 抽一次
  ///
  /// [pityEpic] 距离上次出史诗+的抽数（由调用方维护）
  /// [pityLegend] 距离上次出传说的抽数
  static GachaResult drawOne(
    Random rng,
    Set<String> ownedItems, {
    int pityEpic = 0,
    int pityLegend = 0,
  }) {
    final pool = _poolWithPity(pityEpic, pityLegend);
    final totalWeight = pool.fold(0.0, (sum, e) => sum + e.weight);
    final roll = rng.nextDouble() * totalWeight;
    double cumulative = 0;

    for (final entry in pool) {
      cumulative += entry.weight;
      if (roll <= cumulative) {
        final count = entry.minCount +
            rng.nextInt(entry.maxCount - entry.minCount + 1);
        final item = ItemLibrary.get(entry.itemId)!;
        final isNew = !ownedItems.contains(entry.itemId);
        final isPityHit = (item.rarity == ItemRarity.epic ||
            item.rarity == ItemRarity.legendary) &&
            (pityEpic >= softPityEpic || pityLegend >= softPityLegend);
        return GachaResult(
          itemId: entry.itemId,
          count: count,
          item: item,
          isNew: isNew,
          isPityHit: isPityHit,
        );
      }
    }

    // 默认返回提示卡
    final item = ItemLibrary.get('hint_card')!;
    return GachaResult(
      itemId: 'hint_card',
      count: 1,
      item: item,
      isNew: !ownedItems.contains('hint_card'),
    );
  }

  /// 连抽 N 次
  ///
  /// [pityEpic] 和 [pityLegend] 会随抽取结果动态更新并返回
  static List<GachaResult> drawMany(
    int n,
    Set<String> ownedItems, {
    int pityEpic = 0,
    int pityLegend = 0,
  }) {
    final rng = Random();
    final results = <GachaResult>[];
    final currentOwned = Set<String>.from(ownedItems);
    int curPityEpic = pityEpic;
    int curPityLegend = pityLegend;

    for (int i = 0; i < n; i++) {
      final result = drawOne(
        rng, currentOwned,
        pityEpic: curPityEpic,
        pityLegend: curPityLegend,
      );
      results.add(result);
      currentOwned.add(result.itemId);

      // 更新保底计数
      if (result.item.rarity == ItemRarity.legendary) {
        curPityEpic = 0;
        curPityLegend = 0;
      } else if (result.item.rarity == ItemRarity.epic) {
        curPityEpic = 0;
        curPityLegend++;
      } else {
        curPityEpic++;
        curPityLegend++;
      }
    }

    return results;
  }

  /// 稀有度对应的颜色
  static String rarityColor(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common: return '#9ca3af';
      case ItemRarity.rare: return '#3b82f6';
      case ItemRarity.epic: return '#a855f7';
      case ItemRarity.legendary: return '#f59e0b';
    }
  }

  /// 稀有度名称
  static String rarityName(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common: return '普通';
      case ItemRarity.rare: return '稀有';
      case ItemRarity.epic: return '史诗';
      case ItemRarity.legendary: return '传说';
    }
  }
}

// ==================== 任务系统 ====================

/// 任务类型
enum TaskType {
  daily,    // 日常任务（每日刷新）
  weekly,   // 周常任务
  main,     // 主线任务（一次性）
  side,     // 支线任务
  achievement, // 成就
}

/// 任务状态
enum TaskStatus {
  locked,    // 未解锁
  active,    // 进行中
  completed, // 已完成（未领奖）
  claimed,   // 已领奖
}

/// 任务定义
class TaskDef {
  final String id;
  final String title;
  final String description;
  final TaskType type;
  final int target;      // 目标值
  final String unit;     // 单位，如 "题"、"分钟"
  final Map<String, int> rewards; // 奖励：itemId -> 数量
  final int xpReward;    // 经验奖励

  const TaskDef({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.target,
    required this.unit,
    required this.rewards,
    this.xpReward = 0,
  });
}

/// 任务进度
class TaskProgress {
  final String taskId;
  int progress;
  TaskStatus status;

  TaskProgress({
    required this.taskId,
    this.progress = 0,
    this.status = TaskStatus.active,
  });

  double get percent =>
      progress >= _def.target ? 1.0 : progress / _def.target;

  TaskDef get _def => TaskLibrary.get(taskId);

  bool get canClaim => status == TaskStatus.completed;

  /// 增加进度，返回是否完成
  bool addProgress(int amount) {
    if (status.index >= TaskStatus.completed.index) return false;
    progress += amount;
    if (progress >= _def.target) {
      progress = _def.target;
      status = TaskStatus.completed;
      return true;
    }
    return false;
  }

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'progress': progress,
    'status': status.index,
  };

  factory TaskProgress.fromJson(Map<String, dynamic> json) => TaskProgress(
    taskId: json['taskId'] as String,
    progress: json['progress'] as int? ?? 0,
    status: TaskStatus.values[json['status'] as int? ?? 0],
  );
}

/// 任务库
class TaskLibrary {
  static final Map<String, TaskDef> all = {
    // ── 日常任务 ──
    'daily_checkin': const TaskDef(
      id: 'daily_checkin',
      title: '每日签到',
      description: '打开 APP 完成签到',
      type: TaskType.daily,
      target: 1,
      unit: '次',
      rewards: {'gacha_ticket': 1},
      xpReward: 10,
    ),
    'daily_answer3': const TaskDef(
      id: 'daily_answer3',
      title: '小试牛刀',
      description: '回答3道题目',
      type: TaskType.daily,
      target: 3,
      unit: '题',
      rewards: {'exp_card_s': 1, 'hint_card': 2},
      xpReward: 20,
    ),
    'daily_study15': const TaskDef(
      id: 'daily_study15',
      title: '专心致志',
      description: '累计学习15分钟',
      type: TaskType.daily,
      target: 15,
      unit: '分钟',
      rewards: {'gacha_ticket': 1, 'hint_card': 3},
      xpReward: 30,
    ),
    'daily_master1': const TaskDef(
      id: 'daily_master1',
      title: '掌握新知',
      description: '掌握1个新的技能节点',
      type: TaskType.daily,
      target: 1,
      unit: '个',
      rewards: {'skip_card': 1},
      xpReward: 25,
    ),

    // ── 主线任务 ──
    'main_first_skill': const TaskDef(
      id: 'main_first_skill',
      title: '初窥门径',
      description: '掌握第一个技能节点',
      type: TaskType.main,
      target: 1,
      unit: '个',
      rewards: {'gacha_ticket': 2, 'exp_card_s': 2},
      xpReward: 50,
    ),
    'main_5_skills': const TaskDef(
      id: 'main_5_skills',
      title: '渐入佳境',
      description: '掌握5个技能节点',
      type: TaskType.main,
      target: 5,
      unit: '个',
      rewards: {'gacha_ticket': 3, 'exp_card_m': 1},
      xpReward: 100,
    ),
    'main_first_boss': const TaskDef(
      id: 'main_first_boss',
      title: '初战告捷',
      description: '通关第一个 Boss 节点',
      type: TaskType.main,
      target: 1,
      unit: '个',
      rewards: {'unlock_key': 1, 'gacha_ticket': 2},
      xpReward: 80,
    ),
    'main_full_tree': const TaskDef(
      id: 'main_full_tree',
      title: '登峰造极',
      description: '通关一整棵技能树',
      type: TaskType.main,
      target: 1,
      unit: '棵',
      rewards: {'gacha_ticket': 10},
      xpReward: 500,
    ),
  };

  static TaskDef get(String id) => all[id]!;

  /// 获取所有日常任务 ID
  static List<String> get dailyIds =>
      all.values.where((t) => t.type == TaskType.daily).map((t) => t.id).toList();

  /// 获取所有主线任务 ID
  static List<String> get mainIds =>
      all.values.where((t) => t.type == TaskType.main).map((t) => t.id).toList();
}

/// 任务管理器
class TaskManager {
  TaskManager(); // 默认构造函数
  final Map<String, TaskProgress> _progresses = {};
  String lastDailyReset = '';

  /// 获取任务进度
  TaskProgress getProgress(String taskId) {
    _progresses.putIfAbsent(taskId, () => TaskProgress(taskId: taskId));
    return _progresses[taskId]!;
  }

  /// 获取所有进行中的日常任务
  List<TaskProgress> get dailyTasks {
    _checkDailyReset();
    return TaskLibrary.dailyIds
        .map((id) => getProgress(id))
        .toList();
  }

  /// 获取所有主线任务
  List<TaskProgress> get mainTasks {
    return TaskLibrary.mainIds
        .map((id) => getProgress(id))
        .where((p) => p.status != TaskStatus.claimed)
        .toList();
  }

  /// 检查日常任务重置
  void _checkDailyReset() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (lastDailyReset != today) {
      lastDailyReset = today;
      // 重置所有日常任务
      for (final id in TaskLibrary.dailyIds) {
        _progresses[id] = TaskProgress(taskId: id);
      }
    }
  }

  /// 记录答题
  void recordAnswer(bool correct) {
    _checkDailyReset();
    final p = getProgress('daily_answer3');
    p.addProgress(1);
  }

  /// 记录学习时长（分钟）
  void recordStudyMinutes(int minutes) {
    _checkDailyReset();
    getProgress('daily_study15').addProgress(minutes);
  }

  /// 记录签到
  void recordCheckIn() {
    _checkDailyReset();
    getProgress('daily_checkin').addProgress(1);
  }

  /// 记录掌握技能
  void recordMasteredSkill(int count) {
    _checkDailyReset();
    getProgress('daily_master1').addProgress(count);

    // 主线任务
    getProgress('main_first_skill').addProgress(count);
    getProgress('main_5_skills').addProgress(count);
  }

  /// 记录通关 Boss
  void recordBossCleared() {
    getProgress('main_first_boss').addProgress(1);
  }

  /// 记录通关整棵树
  void recordTreeCleared() {
    getProgress('main_full_tree').addProgress(1);
  }

  /// 领取任务奖励，返回奖励的道具列表
  List<InventoryItem> claimTask(String taskId) {
    final p = getProgress(taskId);
    if (p.status != TaskStatus.completed) return [];

    p.status = TaskStatus.claimed;
    final def = TaskLibrary.get(taskId);
    final rewards = <InventoryItem>[];
    def.rewards.forEach((itemId, count) {
      rewards.add(InventoryItem(itemId: itemId, count: count));
    });
    return rewards;
  }

  /// 有多少个可领取的任务
  int get claimableCount {
    _checkDailyReset();
    return _progresses.values
        .where((p) => p.status == TaskStatus.completed)
        .length;
  }

  Map<String, dynamic> toJson() => {
    'lastDailyReset': lastDailyReset,
    'progresses': _progresses.map((k, v) => MapEntry(k, v.toJson())),
  };

  factory TaskManager.fromJson(Map<String, dynamic> json) {
    final mgr = TaskManager();
    mgr.lastDailyReset = json['lastDailyReset'] as String? ?? '';
    if (json['progresses'] != null) {
      final map = json['progresses'] as Map<String, dynamic>;
      mgr._progresses.addAll(map.map(
        (k, v) => MapEntry(k, TaskProgress.fromJson(Map<String, dynamic>.from(v))),
      ));
    }
    return mgr;
  }
}
