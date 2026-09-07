import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../api_service.dart';

/// API Key 配置引导页
///
/// 新用户友好的设置界面,包含:
/// - 为什么需要 API Key
/// - 支持哪些后端及对比
/// - 各平台获取教程
/// - 安全说明
/// - 自定义 Base URL + 连通性自动检测
class ApiKeyGuideSheet extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSaved; // 参数: baseUrl
  final VoidCallback onClosed;

  const ApiKeyGuideSheet({
    super.key,
    required this.controller,
    required this.onSaved,
    required this.onClosed,
  });

  @override
  State<ApiKeyGuideSheet> createState() => _ApiKeyGuideSheetState();
}

class _ApiKeyGuideSheetState extends State<ApiKeyGuideSheet> {
  final _baseUrlController = TextEditingController();
  bool _showAdvanced = false;
  bool _detecting = false;
  ApiDetectionResult? _detectResult;

  @override
  void initState() {
    super.initState();
    // 监听输入变化，实时更新后端识别提示
    widget.controller.addListener(_onTextChanged);
    // 加载保存的自定义 URL
    _baseUrlController.text = ApiService.customBaseUrl;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _baseUrlController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // ── 顶部把手 ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // ── 标题栏 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Text(
                    '🔑 API Key 设置',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close, color: AppTheme.textSecondary),
                    onPressed: widget.onClosed,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                children: [
                  // ── 为什么需要 API Key ──
                  _buildInfoCard(
                    icon: '🤔',
                    title: '为什么需要 API Key？',
                    content: '尤里卡使用大语言模型 AI 来生成讲解和题目。'
                        'API Key 是你调用 AI 服务的凭证，所有数据都在你的手机本地，'
                        '我们不会收集或上传你的 Key。',
                  ),
                  const SizedBox(height: 16),

                  // ── 支持的后端对比 ──
                  _buildSectionTitle('📊 支持的后端对比'),
                  const SizedBox(height: 10),
                  _buildBackendCompare(),
                  const SizedBox(height: 16),

                  // ── 输入框 ──
                  _buildSectionTitle('✏️ 填入你的 API Key'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.controller,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'sk-xxxxxxxxxxxxxxxxxxxxxxxx',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5)),
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
                      suffixIcon: IconButton(
                        icon: Icon(Icons.paste, size: 18, color: AppTheme.textSecondary),
                        onPressed: () {
                          // 粘贴功能交给系统处理
                        },
                        tooltip: '粘贴',
                      ),
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  _buildBackendHint(widget.controller.text),
                  const SizedBox(height: 12),

                  // ── 高级设置开关 ──
                  GestureDetector(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Row(
                      children: [
                        Icon(Icons.settings, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text('高级设置（自定义 Base URL）',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const Spacer(),
                        Icon(
                          _showAdvanced ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),

                  if (_showAdvanced) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _baseUrlController,
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: '自定义 Base URL',
                        hintText: 'https://api.example.com/v1',
                        labelStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.5), fontSize: 12),
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
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '只要是兼容 OpenAI 协议的 API 服务都可以填，比如本地部署的 Ollama、各种中转服务等。',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.5),
                    ),
                    const SizedBox(height: 12),
                    // 检测按钮
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: OutlinedButton.icon(
                        onPressed: _detecting ? null : _runDetection,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.accent),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _detecting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.accent),
                              )
                            : Icon(Icons.search, size: 18, color: AppTheme.accent),
                        label: Text(
                          _detecting ? '检测中...' : '🔍 自动检测连通性',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.accent),
                        ),
                      ),
                    ),
                    if (_detectResult != null) ...[
                      const SizedBox(height: 10),
                      _buildDetectionResult(),
                    ],
                  ],
                  const SizedBox(height: 16),

                  // ── 获取教程 ──
                  _buildSectionTitle('📖 如何获取 API Key？'),
                  const SizedBox(height: 10),
                  _buildTutorialTile(
                    platform: 'DeepSeek',
                    tag: '推荐新手',
                    tagColor: const Color(0xFF22c55e),
                    steps: const [
                      '打开 platform.deepseek.com 并注册',
                      '进入「API Keys」页面',
                      '点击「创建」，复制生成的 Key',
                      '新用户赠送免费额度，够用很久',
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTutorialTile(
                    platform: '阿里云百炼',
                    tag: 'TokenPlan便宜',
                    tagColor: const Color(0xFFf97316),
                    steps: const [
                      '打开 dashscope.console.aliyun.com',
                      '开通「模型服务」并选择 Qwen 系列',
                      '在「API-KEY 管理」中创建 Key',
                      '推荐购买 TokenPlan 包更划算',
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildTutorialTile(
                    platform: 'SiliconFlow',
                    tag: '模型多',
                    tagColor: const Color(0xFF3b82f6),
                    steps: const [
                      '打开 cloud.siliconflow.cn 注册',
                      '进入「API Key」页面创建',
                      '支持 DeepSeek/Qwen/Llama 等多种模型',
                      '新用户送免费额度',
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── 安全说明 ──
                  _buildInfoCard(
                    icon: '🔒',
                    title: '你的 Key 安全吗？',
                    content: '非常安全。\n\n'
                        '• API Key 使用 AES 加密存储在本地（Keychain/Keystore）\n'
                        '• 只在调用 AI API 时使用，不会上传到任何第三方服务器\n'
                        '• 卸载应用时数据会被完全清除\n'
                        '• 你可以随时在对应平台的控制台撤销 Key',
                  ),
                  const SizedBox(height: 16),

                  // ── 常见问题 ──
                  _buildSectionTitle('❓ 常见问题'),
                  const SizedBox(height: 10),
                  _buildFaqTile(
                    'API Key 会扣钱吗？',
                    '只有在你使用 AI 功能（讲解、出题、评分）时才会消耗 token。'
                        '各平台都有免费额度，轻度使用基本够用。建议在平台设置消费上限。',
                  ),
                  const SizedBox(height: 6),
                  _buildFaqTile(
                    '可以用其他平台吗？',
                    '只要是兼容 OpenAI 协议的 API 服务都可以用。'
                        '在 API Key 前面加上自定义地址即可（高级功能）。',
                  ),
                  const SizedBox(height: 6),
                  _buildFaqTile(
                    'Key 填错了怎么办？',
                    '在这里修改即可。如果调用失败，会提示错误信息，'
                        '可以根据错误信息排查是 Key 错了还是网络问题。',
                  ),
                  const SizedBox(height: 24),

                  // ── 保存按钮 ──
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => widget.onSaved(_baseUrlController.text.trim()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        '保存并开始学习',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
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

  // ── 小组件 ──
  Widget _buildInfoCard({
    required String icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Text(content,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _buildBackendCompare() {
    final backends = [
      {'name': 'DeepSeek', 'price': '💰 便宜', 'speed': '⚡ 快', 'quality': '⭐⭐⭐⭐', 'good': '新手首选'},
      {'name': '百炼 Qwen', 'price': '💰 便宜', 'speed': '⚡ 快', 'quality': '⭐⭐⭐⭐', 'good': '中文最强'},
      {'name': 'SiliconFlow', 'price': '💎 多模型', 'speed': '⚡ 快', 'quality': '⭐⭐⭐⭐', 'good': '模型丰富'},
      {'name': 'OpenAI GPT', 'price': '💸 贵', 'speed': '🐢 一般', 'quality': '⭐⭐⭐⭐⭐', 'good': '效果最好'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          // 表头
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.accent.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text('平台', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(child: Text('价格', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(child: Text('速度', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(flex: 2, child: Text('特点', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          ...backends.asMap().entries.map((e) {
            final b = e.value;
            final isLast = e.key == backends.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: isLast ? BorderSide.none : BorderSide(color: AppTheme.border, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(b['name'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  ),
                  Expanded(child: Text(b['price'] as String, style: const TextStyle(fontSize: 11))),
                  Expanded(child: Text(b['speed'] as String, style: const TextStyle(fontSize: 11))),
                  Expanded(
                    flex: 2,
                    child: Text(b['good'] as String,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTutorialTile({
    required String platform,
    required String tag,
    required Color tagColor,
    required List<String> steps,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(platform,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(tag, style: TextStyle(fontSize: 10, color: tagColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...steps.asMap().entries.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.only(right: 8, top: 1),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('${e.key + 1}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.accentLight)),
                    ),
                  ),
                  Expanded(
                    child: Text(e.value,
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.5)),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildFaqTile(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Q: $question',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          Text('A: $answer',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.6)),
        ],
      ),
    );
  }

  Widget _buildBackendHint(String key) {
    final k = key.trim();
    IconData icon;
    String text;
    Color color;

    if (k.startsWith('sk-sp-')) {
      icon = Icons.auto_awesome;
      text = '已识别：阿里云百炼（Qwen 系列）';
      color = const Color(0xFFf97316);
    } else if (k.startsWith('sk-proj-')) {
      icon = Icons.bolt;
      text = '已识别：OpenAI（GPT 系列）';
      color = const Color(0xFF3b82f6);
    } else if (k.startsWith('sk-')) {
      icon = Icons.key;
      text = '已识别：DeepSeek 官方';
      color = const Color(0xFF22c55e);
    } else {
      icon = Icons.lightbulb_outline;
      text = '填入 API Key 后会自动识别后端';
      color = AppTheme.textSecondary;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }

  /// 执行 API 连通性检测
  Future<void> _runDetection() async {
    setState(() {
      _detecting = true;
      _detectResult = null;
    });

    final result = await ApiService.detectApi(
      testKey: widget.controller.text.trim(),
      testBaseUrl: _baseUrlController.text.trim(),
    );

    setState(() {
      _detecting = false;
      _detectResult = result;
    });
  }

  /// 检测结果展示
  Widget _buildDetectionResult() {
    final r = _detectResult!;
    if (r.success) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF22c55e).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF22c55e).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, size: 16, color: Color(0xFF22c55e)),
                const SizedBox(width: 6),
                const Text('连接成功！',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF22c55e))),
              ],
            ),
            const SizedBox(height: 6),
            Text('后端：${r.backendName}',
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
            if (r.modelCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('可用模型：${r.modelCount} 个',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            if (r.firstModel != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('默认使用：${r.firstModel}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFef4444).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFef4444).withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: Color(0xFFef4444)),
                const SizedBox(width: 6),
                const Text('连接失败',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFef4444))),
              ],
            ),
            const SizedBox(height: 6),
            Text(r.error,
                style: TextStyle(fontSize: 12, color: AppTheme.textPrimary, height: 1.4)),
          ],
        ),
      );
    }
  }
}
