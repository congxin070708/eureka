import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../task_system.dart';
import '../providers/app_providers.dart';

/// 抽奖 + 背包 页面
class GachaScreen extends ConsumerStatefulWidget {
  const GachaScreen({super.key});

  @override
  ConsumerState<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends ConsumerState<GachaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _drawing = false;
  List<GachaResult>? _lastResults;

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
    final tickets = engine.getItemCount('gacha_ticket');

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('系统商店',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
        actions: [
          Row(
            children: [
              const Text('🎫 ', style: TextStyle(fontSize: 18)),
              Text('$tickets',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const SizedBox(width: 16),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.accent,
          labelStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: '🎰 抽奖'),
            Tab(text: '🎒 背包'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildGachaPage(engine, tickets),
          _buildInventoryPage(engine),
        ],
      ),
    );
  }

  // ==================== 抽奖页 ====================

  Widget _buildGachaPage(dynamic engine, int tickets) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // 抽奖大转盘/箱子
          _buildGachaBox(),
          const SizedBox(height: 24),
          // 抽奖按钮
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: tickets < 1 || _drawing
                        ? null
                        : () => _doDraw(1, engine),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '单抽',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: tickets < 10 || _drawing
                        ? null
                        : () => _doDraw(10, engine),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFa855f7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '十连抽',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '🎫 抽奖券: $tickets 张（完成任务获取）',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          // 奖池预览
          _buildPoolPreview(),
        ],
      ),
    );
  }

  Widget _buildGachaBox() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFfef3c7),
            const Color(0xFFfbbf24).withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFf59e0b), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFf59e0b).withValues(alpha: 0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: _drawing
          ? _buildDrawingAnimation()
          : _lastResults != null
              ? _buildResults()
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('📦', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 12),
                    Text(
                      '神秘宝箱',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '传说品质道具等你抽取',
                      style: TextStyle(
                          fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
    );
  }

  Widget _buildDrawingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(Color(0xFFf59e0b)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '✨ 系统正在抽取奖励...',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final results = _lastResults!;
    // 找出最高稀有度
    final highest = results
        .map((r) => r.item.rarity)
        .reduce((a, b) => a.index > b.index ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            highest == ItemRarity.legendary
                ? '🌟 传说！运气爆棚！'
                : highest == ItemRarity.epic
                    ? '💜 史诗！不错哦！'
                    : highest == ItemRarity.rare
                        ? '💙 稀有！还可以~'
                        : '🎁 获得道具',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _rarityColor(highest)),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: results.map((r) {
              return _buildResultItem(r);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(GachaResult r) {
    final color = _rarityColor(r.item.rarity);
    return Container(
      width: 80,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Text(r.item.icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 4),
          Text(
            r.item.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary),
          ),
          if (r.count > 1)
            Text('x${r.count}',
                style: TextStyle(fontSize: 11, color: color)),
          if (r.isNew)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFef4444),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('NEW',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }

  Widget _buildPoolPreview() {
    final rarities = [
      ItemRarity.legendary,
      ItemRarity.epic,
      ItemRarity.rare,
      ItemRarity.common,
    ];

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
          Text('🎁 奖池预览',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          ...rarities.map((r) {
            final items = ItemLibrary.all.values
                .where((i) => i.rarity == r)
                .toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    decoration: BoxDecoration(
                      color: _rarityColor(r).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _rarityName(r),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _rarityColor(r)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: items
                          .map((i) => Text('${i.icon}${i.name}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary)))
                          .toList(),
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

  Future<void> _doDraw(int count, dynamic engine) async {
    if (_drawing) return;
    setState(() {
      _drawing = true;
      _lastResults = null;
    });

    // 模拟抽奖动画延迟
    await Future.delayed(const Duration(milliseconds: 1200));

    setState(() {
      _lastResults = engine.drawGachaMany(count);
      _drawing = false;
      engine.save();
    });
  }

  // ==================== 背包页 ====================

  Widget _buildInventoryPage(dynamic engine) {
    final items = engine.inventory;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎒', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('背包空空如也',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            Text('完成任务获取道具吧！',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }

    // 按类型分组
    final consumables = items.where((i) =>
        i.def.type == ItemType.expCard ||
        i.def.type == ItemType.hintCard ||
        i.def.type == ItemType.skipCard).toList();
    final tickets = items.where((i) => i.def.type == ItemType.gachaTicket).toList();
    final keys = items.where((i) => i.def.type == ItemType.unlockKey).toList();
    final titles = items.where((i) => i.def.type == ItemType.title).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (tickets.isNotEmpty)
          _buildInvSection('🎫 抽奖券', tickets, engine),
        if (consumables.isNotEmpty)
          _buildInvSection('⚡ 消耗品', consumables, engine),
        if (keys.isNotEmpty)
          _buildInvSection('🔑 钥匙', keys, engine),
        if (titles.isNotEmpty)
          _buildInvSection('🎓 称号', titles, engine),
      ],
    );
  }

  Widget _buildInvSection(
      String title, List<InventoryItem> items, dynamic engine) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
          child: Text(title,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.8,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            return _buildInvItem(item, engine);
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildInvItem(InventoryItem item, dynamic engine) {
    final color = _rarityColor(item.def.rarity);
    final canUse = item.def.type != ItemType.title;

    return GestureDetector(
      onTap: canUse
          ? () => _showItemDetail(item, engine)
          : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(item.def.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              item.def.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('x${item.count}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemDetail(InventoryItem item, dynamic engine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(item.def.icon, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 8),
            Text(item.def.name,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: _rarityColor(item.def.rarity).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_rarityName(item.def.rarity),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _rarityColor(item.def.rarity))),
            ),
            const SizedBox(height: 16),
            Text(item.def.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.6)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: item.def.type == ItemType.title || item.count <= 0
                    ? null
                    : () {
                        Navigator.pop(context);
                        _useItem(item, engine);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  item.def.type == ItemType.title ? '已收藏' : '使用',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _useItem(InventoryItem item, dynamic engine) {
    // 简单提示，具体使用逻辑在学习页面接入
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('使用了 ${item.def.name}（在学习页面生效）'),
        backgroundColor: AppTheme.taskDone,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color _rarityColor(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common: return const Color(0xFF9ca3af);
      case ItemRarity.rare: return const Color(0xFF3b82f6);
      case ItemRarity.epic: return const Color(0xFFa855f7);
      case ItemRarity.legendary: return const Color(0xFFf59e0b);
    }
  }

  String _rarityName(ItemRarity rarity) {
    switch (rarity) {
      case ItemRarity.common: return '普通';
      case ItemRarity.rare: return '稀有';
      case ItemRarity.epic: return '史诗';
      case ItemRarity.legendary: return '传说';
    }
  }
}
