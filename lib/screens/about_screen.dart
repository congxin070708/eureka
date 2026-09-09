import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../version.dart';

/// 关于页 - 版本信息、功能特性、技术栈、开源许可、致谢
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text('关于', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 应用信息卡片 ──
            _buildAppInfoCard(),
            const SizedBox(height: 20),

            // ── 功能特性 ──
            _sectionTitle('功能特性'),
            _featureRow(Icons.psychology, 'AI 对话式教学',
                '苏格拉底式提问，引导主动思考'),
            _featureRow(Icons.gpp_good, '掌握度门控',
                '低于阈值不允许进入下一关'),
            _featureRow(Icons.autorenew, '遗忘曲线复习',
                'SM-2 间隔重复算法，科学抗遗忘'),
            _featureRow(Icons.account_tree, '技能树系统',
                '网状知识图谱，前置依赖解锁'),
            _featureRow(Icons.sports_esports, '游戏化激励',
                '任务、抽奖、背包、Boss 战'),
            _featureRow(Icons.menu_book, '知识库 RAG',
                '文档上传，向量检索与问答'),
            _featureRow(Icons.description, '文件学习',
                '智能分段，逐段讲解与测试'),
            _featureRow(Icons.record_voice_over, '语音系统',
                'TTS 朗读与语音识别输入'),

            // ── 技术栈 ──
            _sectionTitle('技术栈'),
            _buildTechStackCard(),
            const SizedBox(height: 20),

            // ── 开源许可 ──
            _sectionTitle('开源许可'),
            _buildLicenses(),
            const SizedBox(height: 20),

            // ── 致谢 ──
            _sectionTitle('致谢'),
            _buildAcknowledgement(),
            const SizedBox(height: 24),

            // ── 版权声明 ──
            _buildCopyright(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppTheme.accent, AppTheme.accentLight],
              ),
            ),
            child: Icon(Icons.lightbulb, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            '尤里卡 Eureka',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI 学习强化训练 - 掌握度门控 - 遗忘曲线复习',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            appVersion,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _featureRow(
      IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppTheme.accentLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTechStackCard() {
    const tags = [
      'Flutter', 'Dart', 'Riverpod', 'SQLite',
      'SharedPreferences', 'Google Fonts', 'File Picker', 'PDF Text',
      'HTTP', 'TTS',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: AppTheme.accent.withValues(alpha: 0.2)),
            ),
            child: Text(
              tag,
              style: TextStyle(fontSize: 12, color: AppTheme.accentLight),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLicenses() {
    const packages = [
      'flutter_riverpod', 'shared_preferences', 'sqflite', 'path_provider',
      'file_picker', 'pdf_text', 'google_fonts', 'http',
      'speech_to_text', 'flutter_tts', 'share_plus', 'url_launcher',
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本项目使用了以下开源组件，感谢它们的贡献者。',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: packages.map((pkg) {
              return Text(
                pkg,
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAcknowledgement() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '感谢所有开源社区的贡献者，你们的智慧成果是本项目的基础。\n\n'
        '感谢 DeepSeek、阿里云百炼、OpenAI 等 AI 服务提供商，'
        '让智能教学成为可能。',
        style: TextStyle(
            fontSize: 13, color: AppTheme.textSecondary, height: 1.6),
      ),
    );
  }

  Widget _buildCopyright() {
    return Center(
      child: Column(
        children: [
          Text(
            '(c) 2024-2026 尤里卡 Eureka',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            '本应用最终用户许可协议及隐私政策见设置页',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
