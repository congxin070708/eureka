import 'package:flutter/material.dart';
import '../app_theme.dart';

/// 隐私政策与用户协议
class LegalScreen extends StatefulWidget {
  final int initialTab;
  const LegalScreen({super.key, this.initialTab = 0});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialTab.clamp(0, 1);
    _tabCtrl = TabController(length: 2, vsync: this, initialIndex: idx);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        backgroundColor: AppTheme.bg,
        elevation: 0,
        title: Text('法律信息', style: TextStyle(color: AppTheme.textPrimary)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.accent,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: '隐私政策'),
            Tab(text: '用户协议'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildDoc(_privacySections),
          _buildDoc(_agreementSections),
        ],
      ),
    );
  }

  Widget _buildDoc(List<Widget> sections) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: sections,
      ),
    );
  }

  Widget _heading(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.accentLight,
          ),
        ),
      ],
    );
  }

  Widget _paragraph(String text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textPrimary,
            height: 1.8,
          ),
        ),
      ],
    );
  }

  // ── 隐私政策 ──
  List<Widget> get _privacySections => [
        _heading('一、引言'),
        _paragraph(
            '尤里卡 Eureka（以下简称"本应用"）是一款基于人工智能技术的学习辅助工具。'
            '本应用深知个人信息对您的重要性，并会尽全力保护您的个人信息安全可靠。'
            '我们致力于维持您对我们的信任，恪守以下原则，保护您的个人信息：'
            '谨慎收集、合理利用、安全保护、尊重选择。'),
        _heading('二、信息收集与使用'),
        _paragraph('本应用收集的信息包括：'),
        _paragraph(
            '1. API 密钥：您主动配置的 AI 服务 API 密钥，仅存储在设备本地的安全存储区域'
            '（Android Keystore / iOS Keychain），不会上传至任何服务器。'),
        _paragraph(
            '2. 学习数据：包括您的学习记录、答题历史、掌握度评分、学习统计等数据，'
            '全部存储在设备本地文件中，不会上传至服务器。'),
        _paragraph(
            '3. 知识库文档：您上传的文档内容存储在设备本地 SQLite 数据库中，不会上传至服务器。'),
        _paragraph(
            '4. AI 交互数据：当您使用 AI 教学功能时，您的输入内容和 AI 的回复'
            '会通过 HTTPS 加密传输至您配置的 AI 服务提供商（如 DeepSeek、OpenAI 等），'
            '具体处理方式请参阅相应服务商的隐私政策。'),
        _heading('三、信息存储'),
        _paragraph('本应用的所有数据均存储在您的设备本地，包括：'),
        _paragraph('- 学习引擎数据存储为本地 JSON 文件'),
        _paragraph('- API 密钥使用平台级安全存储'),
        _paragraph('- 知识库数据使用本地 SQLite 数据库'),
        _paragraph('- 应用配置使用 SharedPreferences'),
        _paragraph(
            '本应用不使用任何远程服务器存储您的个人数据。当您卸载应用时，所有本地数据将被清除。'),
        _heading('四、信息共享'),
        _paragraph(
            '本应用不会将您的个人信息共享给任何第三方。您的 AI 交互数据仅会在您使用 AI 功能时'
            '传输至您自行配置的 AI 服务提供商。本应用开发者无法接触您的任何数据。'),
        _heading('五、信息安全'),
        _paragraph('本应用采取以下安全措施保护您的信息：'),
        _paragraph('- API 密钥使用平台级加密存储'),
        _paragraph('- AI 交互使用 HTTPS 加密传输'),
        _paragraph('- 本地数据不与远程服务器同步'),
        _paragraph(
            '但请注意，互联网传输并非绝对安全，我们无法保证信息传输的绝对安全性。'),
        _heading('六、未成年人保护'),
        _paragraph(
            '本应用面向一般用户，不专门面向未成年人。如果您是未成年人，'
            '请在监护人指导下使用本应用，并在使用 AI 功能前征得监护人同意。'),
        _heading('七、您的权利'),
        _paragraph('您对个人信息享有以下权利：'),
        _paragraph('- 访问权：您可在应用内查看您的学习数据'),
        _paragraph('- 删除权：您可通过卸载应用或使用数据导出/导入功能管理数据'),
        _paragraph('- 撤回同意权：您可随时停止使用 AI 功能，或清除 API 密钥'),
        _heading('八、隐私政策更新'),
        _paragraph(
            '本应用可能会不定期更新本隐私政策。更新后的隐私政策将在应用内展示，请您定期查阅。'),
        _heading('九、联系我们'),
        _paragraph(
            '如果您对本隐私政策有任何疑问，可通过应用内的反馈功能与我们联系。'),
      ];

  // ── 用户协议 ──
  List<Widget> get _agreementSections => [
        _heading('一、协议接受'),
        _paragraph(
            '欢迎使用尤里卡 Eureka（以下简称"本应用"）。在使用本应用前，'
            '请您仔细阅读并同意本用户协议。一旦您开始使用本应用，'
            '即表示您已阅读、理解并同意接受本协议的全部条款。'),
        _heading('二、服务描述'),
        _paragraph('本应用是一款基于人工智能技术的学习辅助工具，提供以下服务：'),
        _paragraph('- AI 对话式教学与出题评分'),
        _paragraph('- 知识掌握度追踪与遗忘曲线复习'),
        _paragraph('- 技能树知识图谱管理'),
        _paragraph('- 文件学习与知识库 RAG 问答'),
        _paragraph('- 游戏化学习激励系统'),
        _paragraph('本应用需要您自行配置 AI 服务 API 密钥才能使用 AI 相关功能。'),
        _heading('三、使用条件'),
        _paragraph('1. 您应年满 13 周岁或达到您所在地区规定的最低年龄要求。'),
        _paragraph('2. 您应确保所提供的信息真实、准确、完整。'),
        _paragraph('3. 您应合法使用本应用，不得将本应用用于任何违法或侵权目的。'),
        _paragraph(
            '4. 您应对自己的学习内容负责，AI 生成的内容仅供参考，不构成专业建议。'),
        _heading('四、AI 服务使用'),
        _paragraph(
            '1. 本应用的 AI 功能依赖于第三方 AI 服务（如 DeepSeek、OpenAI 等），'
            '您需自行注册并获取 API 密钥。'),
        _paragraph(
            '2. AI 生成的内容可能存在错误或不准确之处，您应自行判断并核实。'),
        _paragraph('3. 您使用 AI 服务的费用、合规性由您自行承担。'),
        _paragraph('4. 本应用不对 AI 服务的可用性、准确性作任何保证。'),
        _heading('五、知识产权'),
        _paragraph('1. 本应用的软件代码、界面设计、教学体系等知识产权归本应用开发者所有。'),
        _paragraph('2. 您上传的学习文档、学习记录等数据的知识产权归您或其他权利人所有。'),
        _paragraph('3. AI 生成内容的知识产权归属请参阅相应 AI 服务商的用户协议。'),
        _paragraph('4. 未经授权，您不得复制、修改、传播本应用的源代码和设计。'),
        _heading('六、免责声明'),
        _paragraph('1. 本应用按"现状"提供，不作任何明示或暗示的保证。'),
        _paragraph('2. 本应用不对因使用本应用而产生的任何直接或间接损失承担责任。'),
        _paragraph(
            '3. AI 生成内容仅供参考，本应用不对内容的准确性、完整性负责。'),
        _paragraph('4. 因第三方 AI 服务导致的问题，请您联系相应服务商。'),
        _heading('七、数据责任'),
        _paragraph('1. 您的学习数据存储在您的设备本地，您应自行做好数据备份。'),
        _paragraph('2. 本应用提供数据导出功能，建议您定期备份重要数据。'),
        _paragraph('3. 因设备故障、应用卸载等导致的数据丢失，本应用不承担责任。'),
        _heading('八、协议修改'),
        _paragraph(
            '本应用保留随时修改本协议的权利。修改后的协议将在应用内展示，'
            '继续使用即表示您同意修改后的协议。'),
        _heading('九、适用法律'),
        _paragraph('本协议的解释与适用，以及与协议有关的争议，应依照中华人民共和国法律管辖。'),
      ];
}
