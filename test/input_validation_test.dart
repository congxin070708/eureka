import 'package:flutter_test/flutter_test.dart';
import 'package:eureka/utils/input_validation.dart';

void main() {
  // ═══════════════════════════════════════════════════
  // isValidSubject 学科名验证测试
  // ═══════════════════════════════════════════════════
  group('InputValidation.isValidSubject', () {
    test('空字符串 → false', () {
      expect(InputValidation.isValidSubject(''), false);
    });

    test('单字 → false', () {
      expect(InputValidation.isValidSubject('数'), false);
    });

    test('两字学科名 → true', () {
      expect(InputValidation.isValidSubject('数学'), true);
      expect(InputValidation.isValidSubject('英语'), true);
      expect(InputValidation.isValidSubject('物理'), true);
    });

    test('含"考研"目的词 → true', () {
      expect(InputValidation.isValidSubject('考研数学'), true);
      expect(InputValidation.isValidSubject('考研英语'), true);
    });

    test('含"期末"目的词 → true', () {
      expect(InputValidation.isValidSubject('期末复习'), true);
    });

    test('问句 → false', () {
      expect(InputValidation.isValidSubject('什么是数学'), false);
      expect(InputValidation.isValidSubject('怎么学英语？'), false);
      expect(InputValidation.isValidSubject('为什么物理难'), false);
    });

    test('命令/请求开头 → false', () {
      expect(InputValidation.isValidSubject('帮我学编程'), false);
      expect(InputValidation.isValidSubject('介绍一下物理'), false);
      expect(InputValidation.isValidSubject('推荐几本书'), false);
    });

    test('重复字符(啊啊啊) → false', () {
      expect(InputValidation.isValidSubject('啊啊啊'), false);
      expect(InputValidation.isValidSubject('哈哈哈'), false);
    });

    test('三字学科 → true', () {
      expect(InputValidation.isValidSubject('心理学'), true);
      expect(InputValidation.isValidSubject('经济学'), true);
    });
  });

  // ═══════════════════════════════════════════════════
  // isFollowUp 追问识别测试
  // ═══════════════════════════════════════════════════
  group('InputValidation.isFollowUp', () {
    test('短输入(<3字) → false', () {
      expect(InputValidation.isFollowUp('啊'), false);
      expect(InputValidation.isFollowUp('对'), false);
    });

    test('以"为什么"开头 → true', () {
      expect(InputValidation.isFollowUp('为什么会这样'), true);
    });

    test('以"怎么"开头 → true', () {
      expect(InputValidation.isFollowUp('怎么理解这个概念'), true);
    });

    test('以"什么是"开头 → true', () {
      expect(InputValidation.isFollowUp('什么是微积分'), true);
    });

    test('以问号结尾 → true', () {
      expect(InputValidation.isFollowUp('这个对吗？'), true);
      expect(InputValidation.isFollowUp('Is this right?'), true);
    });

    test('含"是什么意思" → true', () {
      expect(InputValidation.isFollowUp('这个公式是什么意思'), true);
    });

    test('含"怎么理解" → true', () {
      expect(InputValidation.isFollowUp('这个定理怎么理解'), true);
    });

    test('普通陈述 → false', () {
      expect(InputValidation.isFollowUp('我认为导数的定义是这样的'), false);
    });

    test('以"请"开头 → true', () {
      expect(InputValidation.isFollowUp('请再解释一下'), true);
    });

    test('以"帮我"开头 → true', () {
      expect(InputValidation.isFollowUp('帮我分析一下这道题'), true);
    });
  });

  // ═══════════════════════════════════════════════════
  // isOtherSubject 其他学科识别测试
  // ═══════════════════════════════════════════════════
  group('InputValidation.isOtherSubject', () {
    final subjects = <String, dynamic>{
      '数学': null,
      '英语': null,
      '物理': null,
    };

    test('当前学科 → false', () {
      expect(InputValidation.isOtherSubject('数学', '数学', subjects), false);
    });

    test('书架中其他学科 → true', () {
      expect(InputValidation.isOtherSubject('物理', '数学', subjects), true);
      expect(InputValidation.isOtherSubject('英语', '数学', subjects), true);
    });

    test('不在书架的常见学科 → true', () {
      expect(InputValidation.isOtherSubject('化学', '数学', subjects), true);
      expect(InputValidation.isOtherSubject('Python', '数学', subjects), true);
    });

    test('空输入 → false', () {
      expect(InputValidation.isOtherSubject('', '数学', subjects), false);
    });

    test('组合词(如"英语语法") → false', () {
      expect(InputValidation.isOtherSubject('英语语法', '数学', subjects), false);
    });
  });

  // ═══════════════════════════════════════════════════
  // isIrrelevantInput 无关输入拦截测试
  // ═══════════════════════════════════════════════════
  group('InputValidation.isIrrelevantInput', () {
    test('空字符串 → true', () {
      expect(InputValidation.isIrrelevantInput(''), true);
    });

    test('纯空格 → true', () {
      expect(InputValidation.isIrrelevantInput('   '), true);
    });

    test('纯符号 → true', () {
      expect(InputValidation.isIrrelevantInput('!!!'), true);
      expect(InputValidation.isIrrelevantInput('...'), true);
      expect(InputValidation.isIrrelevantInput('😀😀😀'), true);
    });

    test('闲聊词 → true', () {
      expect(InputValidation.isIrrelevantInput('你好'), true);
      expect(InputValidation.isIrrelevantInput('哈哈'), true);
      expect(InputValidation.isIrrelevantInput('好的'), true);
      expect(InputValidation.isIrrelevantInput('谢谢'), true);
      expect(InputValidation.isIrrelevantInput('666'), true);
    });

    test('"跳过" → true(直接看答案的指令)', () {
      expect(InputValidation.isIrrelevantInput('跳过'), true);
    });

    test('太短(<3字) → true', () {
      expect(InputValidation.isIrrelevantInput('对'), true);
      expect(InputValidation.isIrrelevantInput('哦'), true);
      expect(InputValidation.isIrrelevantInput('嗯'), true);
    });

    test('正常回答 → false', () {
      expect(InputValidation.isIrrelevantInput('我认为答案是5'), false);
      expect(InputValidation.isIrrelevantInput('导数是函数的变化率'), false);
    });

    test('nb 不区分大小写 → true', () {
      expect(InputValidation.isIrrelevantInput('nb'), true);
      expect(InputValidation.isIrrelevantInput('NB'), true);
    });
  });

  // ═══════════════════════════════════════════════════
  // detectPurposeHint 目的识别测试
  // ═══════════════════════════════════════════════════
  group('InputValidation.detectPurposeHint', () {
    test('考研 → 返回考研提示', () {
      final hint = InputValidation.detectPurposeHint('考研数学');
      expect(hint, contains('考研'));
      expect(hint, isNotEmpty);
    });

    test('四级 → 返回四级提示', () {
      final hint = InputValidation.detectPurposeHint('英语四级');
      expect(hint, contains('四级'));
      expect(hint, isNotEmpty);
    });

    test('六级 → 返回六级提示', () {
      final hint = InputValidation.detectPurposeHint('六级备考');
      expect(hint, contains('六级'));
      expect(hint, isNotEmpty);
    });

    test('期末 → 返回期末提示', () {
      final hint = InputValidation.detectPurposeHint('期末复习');
      expect(hint, contains('期末'));
      expect(hint, isNotEmpty);
    });

    test('竞赛 → 返回竞赛提示', () {
      final hint = InputValidation.detectPurposeHint('数学竞赛');
      expect(hint, contains('竞赛'));
      expect(hint, isNotEmpty);
    });

    test('雅思 → 返回留学考试提示', () {
      final hint = InputValidation.detectPurposeHint('雅思考试');
      expect(hint, contains('雅思'));
      expect(hint, isNotEmpty);
    });

    test('自考 → 返回自考提示', () {
      final hint = InputValidation.detectPurposeHint('自考本科');
      expect(hint, contains('自考'));
      expect(hint, isNotEmpty);
    });

    test('面试 → 返回面试提示', () {
      final hint = InputValidation.detectPurposeHint('面试准备');
      expect(hint, contains('面试'));
      expect(hint, isNotEmpty);
    });

    test('普通学科 → 空字符串', () {
      expect(InputValidation.detectPurposeHint('高等数学'), '');
      expect(InputValidation.detectPurposeHint('英语'), '');
    });
  });
}
