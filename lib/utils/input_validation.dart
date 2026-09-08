/// 输入验证工具集 - 从 learn_screen.dart 抽取
/// 负责判断用户输入的合法性:学科名识别、追问识别、无关输入拦截
class InputValidation {
  InputValidation._();

  /// 检查是否是正经学科名
  static bool isValidSubject(String text) {
    if (text.length < 2) return false;
    // 允许含目的词的输入(考研、期末、竞赛等)
    if (RegExp(r'考研|期末|竞赛|考试|自考|留学|面试|工作|项目|实战')
        .hasMatch(text)) return true;
    // 排除问句
    if (RegExp(r'[?？吗么吧呢呀的怎么什么是如何为什么哪哪些]')
        .hasMatch(text)) return false;
    // 排除命令/请求
    if (RegExp(r'^(帮我|给我|请|介绍|解释|说明|推荐|搜索|查)')
        .hasMatch(text)) return false;
    // 排除乱输
    final hasMeaningfulChar = text.contains(RegExp(
      r'[数学物理化英语文历地政经编程算机网工原逻心哲艺设]'
      r'|学|论|理|法|术|导|程|基|概|原|设|计|管|统|分|析'
    ));
    if (hasMeaningfulChar) return true;
    if (RegExp(r'^(.)\1+$').hasMatch(text)) return false;
    if (text.length <= 4 &&
        RegExp(r'^[顶啊哦嗯哈嘻哇呀哟]+$').hasMatch(text)) return false;
    return true;
  }

  /// 追问识别:输入看起来像"追问/请教"而非"回答问题"
  static bool isFollowUp(String text) {
    final t = text.trim();
    if (t.length < 3) return false;
    // 以问词开头
    if (RegExp(
            r'^(为什么|怎么|如何|什么是|啥是|是不是|能否|能不能|可以|请|帮我|解释|讲讲|说明|举个例子)')
        .hasMatch(t)) return true;
    // 含追问特征词
    if (RegExp(r'(是什么意思|怎么理解|怎么用|为什么|能不能再|再讲讲|详细说说|展开讲讲)')
        .hasMatch(t)) return true;
    // 以问号结尾
    if (t.endsWith('?') || t.endsWith('？')) return true;
    return false;
  }

  /// 学科名识别:输入是否为其他学科名(整词匹配,避免误伤"英语语法"这类组合)
  static bool isOtherSubject(String text, String currentSubject, Map<String, dynamic> subjects) {
    final t = text.trim();
    if (t.isEmpty) return false;
    // 书架里已有的其他学科
    for (final s in subjects.keys) {
      if (s != currentSubject && t == s) return true;
    }
    // 当前学科不算"其他学科"
    if (t == currentSubject) return false;
    // 常见学科名单(整词匹配)
    const common = [
      '英语', '数学', '物理', '化学', '生物', '历史', '地理', '政治',
      '语文', '编程', '计算机', '高数', '线代', '概率论', '经济学',
      '心理学', '哲学', '法学', '医学', '艺术', '设计',
      'C语言', 'Python', 'Java'
    ];
    if (common.contains(t)) return true;
    return false;
  }

  /// 规则拦截:判断输入是否明显与问题无关(闲聊/纯符号/反问/超短)
  static bool isIrrelevantInput(String text) {
    final t = text.trim();
    if (t.isEmpty) return true;
    // 纯符号/表情/无意义字符
    if (!RegExp(r'[\u4e00-\u9fa5a-zA-Z0-9]').hasMatch(t)) return true;
    // 闲聊/敷衍词
    if (RegExp(
            r'^(你好|哈哈|呵呵|好的|嗯|哦|知道|不知道|谢谢|不错|666|nb|行|可以|对|是|随便|不会|没想好|跳过|看答案)$',
            caseSensitive: false)
        .hasMatch(t)) return true;
    // 太短(<3字)视为敷衍
    if (t.length < 3) return true;
    return false;
  }

  /// 智能识别用户目的,返回目的提示词
  static String detectPurposeHint(String input) {
    if (input.contains('考研')) return '用户目的是考研，推荐考研辅导书（如张宇、汤家凤、李永乐等），侧重真题和应试技巧。';
    if (input.contains('四级')) return '用户目的是英语四级，推荐四级真题、词汇书、听力材料。';
    if (input.contains('六级')) return '用户目的是英语六级，推荐六级真题、词汇书、听力材料。';
    if (input.contains('期末')) return '用户目的是期末考试，推荐复习资料、重点归纳、习题集。';
    if (input.contains('竞赛')) return '用户目的是学科竞赛，推荐竞赛辅导书、历年真题、进阶教材。';
    if (input.contains('雅思') || input.contains('托福')) return '用户目的是出国留学考试，推荐雅思/托福备考资料。';
    if (input.contains('自考')) return '用户目的是自学考试，推荐自考教材和真题。';
    if (input.contains('面试')) return '用户目的是面试准备，推荐面试题集和实战指南。';
    return '';
  }
}
