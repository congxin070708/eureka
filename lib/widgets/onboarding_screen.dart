import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import 'api_key_guide_sheet.dart';
import '../api_service.dart';
import '../secure_storage_service.dart';
import '../preset_courses.dart';

/// 首次启动引导页
///
/// 三个页面:
/// 1. 欢迎页 - 介绍尤里卡是什么
/// 2. 核心功能 - 三大核心特性
/// 3. 选择学习路线 - 零配置预置课程，没有 API Key 也能体验完整流程
class OnboardingScreen extends ConsumerStatefulWidget {
  /// 完成引导回调。
  /// - [presetSubject] 为 null：用户跳过 / 先逛逛 / 仅配置了 API Key
  /// - [presetSubject] 非 null：用户选择了某条预置学习路线
  final void Function(String? presetSubject) onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  // 保留：底部 "已有 API Key？去设置" 链接弹出 ApiKeyGuideSheet 时复用
  final _apiKeyController = TextEditingController();

  /// 预置课程的一句话描述（按科目名匹配）
  static const Map<String, String> _presetDescriptions = {
    '高等数学': '从 ε-δ 语言到经典极限 sin(x)/x',
    '线性代数': '行乘以列，理解为什么不满足交换律',
    '大学物理': 'F=ma，从无摩擦到有摩擦的实际计算',
  };

  @override
  void dispose() {
    _pageCtrl.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 保存 API Key 后完成引导（不选择预置课程）
  void _finishSetup() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      ApiService.apiKey = key;
      await SecureStorageService.saveApiKey(key);
    }
    widget.onCompleted(null);
  }

  /// 弹出 API Key 配置引导页（底部 "已有 API Key？去设置" 入口）
  void _showApiKeyGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApiKeyGuideSheet(
        controller: _apiKeyController,
        onSaved: (baseUrl) {
          ApiService.customBaseUrl = baseUrl;
          SecureStorageService.saveBaseUrl(baseUrl);
          Navigator.pop(context);
          _finishSetup();
        },
        onClosed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            // 跳过按钮
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => widget.onCompleted(null),
                child: Text('跳过', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            ),
            // 页面内容
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildWelcomePage(),
                  _buildFeaturesPage(),
                  _buildPresetPage(),
                ],
              ),
            ),
            // 底部指示器 + 按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // 指示点
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (i) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppTheme.accent : AppTheme.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _currentPage < 2
                          ? _nextPage
                          : () => widget.onCompleted(null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < 2 ? '下一步' : '先逛逛看',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_currentPage < 2) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => widget.onCompleted(null),
                      child: Text('先随便看看',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 第1页: 欢迎 ──
  Widget _buildWelcomePage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentLight],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.auto_stories, size: 56, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            '欢迎来到尤里卡',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '理工科大学生的 AI 学伴',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildHighlightItem(
            icon: '🧠',
            title: '掌握度门控',
            desc: '概念没吃透？不让走。真正理解了再进下一个',
          ),
          const SizedBox(height: 14),
          _buildHighlightItem(
            icon: '🔄',
            title: '遗忘曲线复习',
            desc: 'SM-2 算法安排复习，考前不遗忘',
          ),
          const SizedBox(height: 14),
          _buildHighlightItem(
            icon: '🎯',
            title: '个性化出题',
            desc: 'AI 根据你的薄弱点出题，告别盲目刷题',
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightItem({required String icon, required String title, required String desc}) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }

  // ── 第2页: 学习流程 ──
  Widget _buildFeaturesPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '学习四步法',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '从「上课听过」到「考试会做」的科学闭环',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildStepTile(
            step: '01',
            title: 'AI 讲解',
            desc: '输入知识点，AI 系统化讲解，配生活化类比帮助理解',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '02',
            title: '主动思考',
            desc: 'AI 出思考题，用自己的话回答，不是选择题蒙答案',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '03',
            title: '掌握度评估',
            desc: 'AI 评分反馈，掌握度不达标继续练，直到真懂',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '04',
            title: '间隔复习',
            desc: 'SM-2 算法智能安排复习，在遗忘临界点及时巩固',
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile({required String step, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(step,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.accent.withValues(alpha: 0.3))),
        const SizedBox(width: 16),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text(desc,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 22, top: 4, bottom: 4),
      child: Container(
        width: 2,
        height: 16,
        color: AppTheme.border,
      ),
    );
  }

  // ── 第3页: 选择学习路线（零配置预置课程） ──
  Widget _buildPresetPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            '选择学习路线',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '先体验完整学习闭环，无需注册',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          // 3 条预置课程卡片
          ...PresetCourses.courses.map((c) => _buildPresetCard(c)),
          const SizedBox(height: 8),
          // 已有 API Key 引导
          Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _showApiKeyGuide,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.key, size: 14, color: AppTheme.accent),
                  const SizedBox(width: 6),
                  Text('已有 API Key？去设置',
                      style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.accent,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// 单个预置课程卡片：emoji + 科目 + 知识点 + 一句话描述
  Widget _buildPresetCard(PresetCourse course) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => widget.onCompleted(course.subject),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // emoji 圆角方块
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(course.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 14),
                // 科目 + 知识点 + 描述
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(course.subject,
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary)),
                          const SizedBox(width: 8),
                          Text('· ${course.topic}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _presetDescriptions[course.subject] ?? '体验完整学习闭环',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
