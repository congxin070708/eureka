import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../api_service.dart';
import '../secure_storage_service.dart';
import '../data_export_service.dart';
import '../notification_service.dart';
import '../providers/app_providers.dart';
import '../widgets/api_key_guide_sheet.dart';
import 'about_screen.dart';
import 'legal_screen.dart';

/// 独立设置页
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  bool _notifEnabled = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(text: ApiService.apiKey);
    _loadNotifPref();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  // ── 读取复习提醒开关持久化状态 ──
  Future<void> _loadNotifPref() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notif_enabled') ?? false;
    if (mounted) {
      setState(() => _notifEnabled = enabled);
    }
  }

  // ── 复习提醒开关切换 ──
  Future<void> _onNotifChanged(bool val) async {
    setState(() => _notifEnabled = val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_enabled', val);
    if (val) {
      await NotificationService.requestPermissions();
      await NotificationService.scheduleDailyReviewReminder();
    } else {
      await NotificationService.cancelAll();
    }
  }

  // ── 深色模式切换 ──
  Future<void> _toggleTheme(bool val) async {
    ref.read(themeProvider.notifier).setDark(val);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dark_theme', AppTheme.isDark);
  }

  // ── 弹出 API Key 配置引导页 ──
  void _openApiKeySheet() {
    _apiKeyController.text = ApiService.apiKey;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApiKeyGuideSheet(
        controller: _apiKeyController,
        onSaved: (baseUrl) async {
          ApiService.apiKey = _apiKeyController.text.trim();
          ApiService.customBaseUrl = baseUrl;
          final keyOk = await SecureStorageService.saveApiKey(ApiService.apiKey);
          final urlOk = await SecureStorageService.saveBaseUrl(baseUrl);
          ApiService.clearDetectionCache();
          if (mounted) Navigator.pop(context);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(keyOk && urlOk
                    ? 'API Key 已保存'
                    : '保存失败，请检查系统存储权限'),
                backgroundColor: keyOk && urlOk
                    ? AppTheme.taskDone
                    : const Color(0xFFef4444),
                duration: const Duration(seconds: 2),
              ),
            );
            setState(() {});
          }
        },
        onClosed: () => Navigator.pop(context),
      ),
    );
  }

  // ── 学习模式选择对话框 ──
  void _showStudyModeDialog() {
    final e = ref.read(studyEngineProvider);
    const modes = ['速学', '深度', '挑战'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: Text('学习模式',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: modes.map((m) {
            final desc = m == '速学'
                ? '快速过一遍知识点'
                : m == '深度'
                    ? '详细讲解 + 多轮练习'
                    : '高难度题目 + 严格评分';
            return RadioListTile<String>(
              value: m,
              groupValue: e.studyMode,
              title: Text(m,
                  style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600)),
              subtitle: Text(desc,
                  style:
                      TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              onChanged: (v) async {
                if (v == null) return;
                e.setStudyMode(v);
                await e.save();
                if (ctx.mounted) Navigator.pop(ctx);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── 导出学习数据 ──
  Future<void> _exportData() async {
    await DataExportService.exportData(ref.read(studyEngineProvider));
  }

  // ── 导入学习数据并刷新引擎 ──
  Future<void> _importData() async {
    final imported = await DataExportService.importData();
    if (imported == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('导入失败，请检查文件'),
            backgroundColor: Color(0xFFef4444),
          ),
        );
      }
      return;
    }
    ref.read(studyEngineProvider).replaceEngine(imported);
    await ref.read(studyEngineProvider).save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('数据导入成功'),
          backgroundColor: AppTheme.taskDone,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = ref.watch(studyEngineProvider);
    final isDark = ref.watch(themeProvider);
    final apiKeySubtitle = ApiService.apiKey.isEmpty
        ? '还没设置，点击配置'
        : '已配置 · ${_backendHint(ApiService.apiKey)}';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text('设置', style: TextStyle(color: AppTheme.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('账号', [
              _buildTile(
                Icons.key,
                'API Key',
                apiKeySubtitle,
                _openApiKeySheet,
              ),
            ]),
            _buildSection('学习设置', [
              _buildTile(
                Icons.tune,
                '学习模式',
                e.studyMode,
                _showStudyModeDialog,
              ),
              _buildSwitchTile(
                Icons.notifications,
                '复习提醒',
                '每天 20:00 提醒复习到期知识点',
                _notifEnabled,
                _onNotifChanged,
              ),
            ]),
            _buildSection('外观', [
              _buildSwitchTile(
                Icons.dark_mode,
                '深色模式',
                '切换亮色/深色主题',
                isDark,
                _toggleTheme,
              ),
            ]),
            _buildSection('数据管理', [
              _buildTile(
                Icons.upload,
                '导出数据',
                '导出学习记录为 JSON 文件',
                _exportData,
              ),
              _buildTile(
                Icons.download,
                '导入数据',
                '从备份文件恢复数据',
                _importData,
              ),
            ]),
            _buildSection('关于与法律', [
              _buildTile(
                Icons.info,
                '关于尤里卡',
                '版本信息、功能特性、技术栈',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AboutScreen()),
                ),
              ),
              _buildTile(
                Icons.privacy_tip,
                '隐私政策',
                '查看隐私政策',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: 0)),
                ),
              ),
              _buildTile(
                Icons.description,
                '用户协议',
                '查看用户协议',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const LegalScreen(initialTab: 1)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  // ── 辅助构建方法 ──

  Widget _buildTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppTheme.accentLight),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Icon(Icons.chevron_right,
          size: 20, color: AppTheme.textSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: AppTheme.accentLight),
      ),
      title: Text(title,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.5)),
        ),
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                      height: 1,
                      color: AppTheme.border.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 后端识别提示（按 Key 前缀，不含 emoji）
  static String _backendHint(String key) {
    final k = key.trim();
    if (k.startsWith('sk-sp-')) return '百炼 Qwen';
    if (k.startsWith('sk-proj-')) return 'OpenAI';
    if (k.startsWith('sk-')) return 'DeepSeek';
    return '未识别后端';
  }
}
