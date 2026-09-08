import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import 'api_key_guide_sheet.dart';
import '../api_service.dart';
import '../secure_storage_service.dart';

/// 首次启动引导页
///
/// 三个页面:
/// 1. 欢迎页 - 介绍尤里卡是什么
/// 2. 核心功能 - 三大核心特性
/// 3. API Key 配置 - 引导用户设置 API Key
class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onCompleted;
  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  final _apiKeyController = TextEditingController();

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

  void _finishSetup() async {
    final key = _apiKeyController.text.trim();
    if (key.isNotEmpty) {
      ApiService.apiKey = key;
      await SecureStorageService.saveApiKey(key);
    }
    widget.onCompleted();
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
                onPressed: widget.onCompleted,
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
                  _buildApiKeyPage(),
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
                      onPressed: _currentPage < 2 ? _nextPage : _finishSetup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage < 2 ? '下一步' : '开始学习之旅',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (_currentPage < 2) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onCompleted,
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
            '你的 AI 学习伙伴',
            style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildHighlightItem(
            icon: '🧠',
            title: '掌握度门控',
            desc: '没学会？不让走。真正掌握了再前进',
          ),
          const SizedBox(height: 14),
          _buildHighlightItem(
            icon: '🔄',
            title: '遗忘曲线复习',
            desc: '科学安排复习时间，记忆更持久',
          ),
          const SizedBox(height: 14),
          _buildHighlightItem(
            icon: '🎯',
            title: '个性化出题',
            desc: 'AI 根据你的薄弱点，针对性训练',
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
            '科学闭环，让知识从「见过」到「掌握」',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 32),
          _buildStepTile(
            step: '01',
            title: 'AI 讲解',
            desc: '输入想学的知识点，AI 系统化讲解，配生活化类比',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '02',
            title: '主动思考',
            desc: 'AI 出思考题，用自己的话回答，不是被动选择',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '03',
            title: '掌握度评估',
            desc: 'AI 评分反馈，实时计算掌握度，未达标继续练',
          ),
          _buildStepDivider(),
          _buildStepTile(
            step: '04',
            title: '间隔复习',
            desc: '智能安排复习，在遗忘临界点及时巩固',
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

  // ── 第3页: API Key ──
  Widget _buildApiKeyPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.key, size: 48, color: Color(0xFFf97316)),
          const SizedBox(height: 16),
          Text(
            '设置你的 API Key',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '尤里卡使用 AI 来生成讲解和题目，需要你自己的 API Key。',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'API Key 加密存储在你的设备本地，不会上传到任何服务器。'
                    '你可以随时在设置中修改或删除。',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _apiKeyController,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
              labelStyle: TextStyle(color: AppTheme.textSecondary),
              hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.4)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppTheme.accent, width: 2),
              ),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
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
            },
            child: Row(
              children: [
                Icon(Icons.help_outline, size: 14, color: AppTheme.accent),
                const SizedBox(width: 6),
                Text('不知道怎么获取？查看详细教程',
                    style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '💡 提示：没有 API Key 也可以先浏览，但答题等 AI 功能需要配置后才能使用。',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6),
          ),
        ],
      ),
    );
  }
}
