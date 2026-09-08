// ignore_for_file: avoid_print

/// 预置课程 - 零配置体验
///
/// 新用户没有配置 API Key 时，也能走完"讲解→答题→评分"的完整学习循环。
/// 所有内容均为本地内置，不调用任何 AI 接口。
///
/// 预置 3 条学习路线：
///   1. 高等数学 - 极限
///   2. 线性代数 - 矩阵乘法
///   3. 大学物理 - 牛顿第二定律
///
/// 搭配 [PresetCourses.localScore] 方法可在本地完成关键词匹配评分，
/// 无需 AI 参与。

/// 一条预置学习路线
///
/// 包含完整的"讲解→题目→参考答案→解析"链条，
/// 以及用于本地关键词匹配评分的 [answerKeyPoints]。
class PresetCourse {
  /// 科目名，如 "高等数学"
  final String subject;

  /// 知识点，如 "极限"
  final String topic;

  /// 展示用 emoji，如 "📐"
  final String emoji;

  /// 本地讲解内容（代替 AI 生成的讲解）
  final String explanation;

  /// 本地题目
  final String question;

  /// 答案要点（用于本地关键词匹配评分）
  final List<String> answerKeyPoints;

  /// 参考答案
  final String referenceAnswer;

  /// 解析
  final String explanationDetail;

  const PresetCourse({
    required this.subject,
    required this.topic,
    required this.emoji,
    required this.explanation,
    required this.question,
    required this.answerKeyPoints,
    required this.referenceAnswer,
    required this.explanationDetail,
  });
}

/// 预置课程集合 + 本地评分工具
///
/// 用法示例：
/// ```dart
/// final course = PresetCourses.courses[0];
/// // 1. 展示讲解
/// showText(course.explanation);
/// // 2. 出题
/// showText(course.question);
/// // 3. 用户作答后，本地评分
/// final result = PresetCourses.localScore(userAnswer, course.answerKeyPoints);
/// print(result['score']); // 0-100
/// ```
class PresetCourses {
  PresetCourses._();

  /// 3 条预置学习路线
  static const List<PresetCourse> courses = [
    // ── 1. 高等数学 - 极限 ──
    PresetCourse(
      subject: '高等数学',
      topic: '极限',
      emoji: '📐',
      explanation: '''
📐 极限（Limit）

【什么是极限】
极限描述的是一个变量在无限靠近某个值时，函数值的变化趋势。
关键在于"趋势"而非"到达"——变量可以无限接近目标值，但不一定真正等于它。

【直观理解】
想象你走向一堵墙：每一步走剩余距离的一半。
你永远不会真正撞到墙（因为总还剩一半），但你和墙的距离可以无限接近于零。
这就是极限的核心思想：趋近，但不一定到达。

【ε-δ 语言的简化版】
严谨定义（柯西 ε-δ 语言）说的是：
对于任意小的正数 ε，总能找到一个正数 δ，
使得当 0 < |x - a| < δ 时，|f(x) - L| < ε。

翻译成人话：只要 x 足够接近 a（但不等于 a），
f(x) 就能任意接近 L。你想让 f(x) 多接近 L 都行，只要你让 x 足够接近 a。

【经典例子】
lim(x→0) sin(x)/x = 1
当 x 趋近于 0 时，sin(x)/x 的值趋近于 1。
注意：x=0 时这个式子是 0/0 无意义，但极限依然存在。
''',
      question: '请用自己的话解释什么是极限，并说明 lim(x→0) sin(x)/x = 1 的含义。',
      answerKeyPoints: ['趋近', '无限接近', '不等于', 'x趋近于0', 'sin(x)/x', '1'],
      referenceAnswer: '''
极限是指：当自变量无限趋近某个值时（但不一定等于该值），函数值无限接近一个确定的数。

lim(x→0) sin(x)/x = 1 的含义：
当 x 无限趋近于 0（但 x ≠ 0，因为 x=0 时分母为 0 无意义）时，
sin(x)/x 的值无限接近于 1。

这说明虽然 x=0 处函数没有定义，但当 x 趋近于 0 时，函数有确定的极限值 1。
这是微积分中的一个重要结论，也是很多求导公式的基石。
''',
      explanationDetail: '''
【考查要点】
1. 极限的核心是"趋近"——无限接近但不一定到达。
2. x 趋近于 0 不等于 x = 0，函数在该点可以无定义但极限存在。
3. sin(x)/x 在 x→0 时极限为 1，是经典重要极限，由夹逼定理可证明。

【常见误区】
- 误区一：以为极限值就是函数值。错！极限是趋势，函数在趋近点甚至可以没有定义。
- 误区二：以为"趋近"就是"等于"。错！趋近是无限接近，不一定到达。
- 误区三：认为 0/0 就没有极限。错！0/0 是未定式，极限可能存在也可能不存在，需要具体分析。

【延伸】
sin(x)/x → 1 可以通过泰勒展开理解：
sin(x) ≈ x - x³/6 + ... 所以 sin(x)/x ≈ 1 - x²/6 → 1（当 x→0）。
''',
    ),

    // ── 2. 线性代数 - 矩阵乘法 ──
    PresetCourse(
      subject: '线性代数',
      topic: '矩阵乘法',
      emoji: '🔢',
      explanation: '''
🔢 矩阵乘法（Matrix Multiplication）

【基本规则：行乘以列】
矩阵乘法不是对应元素相乘，而是"行向量 × 列向量"的点积。

设 A 是 m×n 矩阵，B 是 n×p 矩阵，
则 C = AB 是 m×p 矩阵，
其中 C 的第 i 行第 j 列元素 = A 的第 i 行与 B 的第 j 列的点积：

  C[i][j] = Σ A[i][k] × B[k][j]  （k 从 1 到 n）

注意：A 的列数必须等于 B 的行数，否则不能相乘。

【计算示例】
A = [[1, 2], [3, 4]]，B = [[5, 6], [7, 8]]

AB[0][0] = 1×5 + 2×7 = 5 + 14 = 19
AB[0][1] = 1×6 + 2×8 = 6 + 16 = 22
AB[1][0] = 3×5 + 4×7 = 15 + 28 = 43
AB[1][1] = 3×6 + 4×8 = 18 + 32 = 50

所以 AB = [[19, 22], [43, 50]]

【为什么不满足交换律：AB ≠ BA】
矩阵乘法的本质是线性变换的复合，而变换的先后顺序会影响结果。
从计算角度看：
- AB 的第 i 行第 j 列 = A 的第 i 行 · B 的第 j 列
- BA 的第 i 行第 j 列 = B 的第 i 行 · A 的第 j 列
行和列的来源不同，结果自然不同。

例如上面的 A、B：
BA[0][0] = 5×1 + 6×3 = 5 + 18 = 23  （≠ 19）
显然 AB ≠ BA。
''',
      question:
          '给定 A=[[1,2],[3,4]]，B=[[5,6],[7,8]]，计算 AB，并解释为什么矩阵乘法不满足交换律。',
      answerKeyPoints: ['19', '22', '43', '50', '行乘以列', '不满足交换', 'AB≠BA'],
      referenceAnswer: '''
【计算 AB】
A = [[1, 2], [3, 4]]，B = [[5, 6], [7, 8]]

AB[0][0] = 1×5 + 2×7 = 5 + 14 = 19
AB[0][1] = 1×6 + 2×8 = 6 + 16 = 22
AB[1][0] = 3×5 + 4×7 = 15 + 28 = 43
AB[1][1] = 3×6 + 4×8 = 18 + 32 = 50

AB = [[19, 22], [43, 50]]

【为什么不满足交换律（AB ≠ BA）】
矩阵乘法是"行乘以列"的运算：
- AB 的元素 = A 的行 · B 的列
- BA 的元素 = B 的行 · A 的列
两者的行、列来源不同，计算结果自然不同。

验证：
BA[0][0] = 5×1 + 6×3 = 5 + 18 = 23  （而 AB[0][0] = 19）
所以 AB ≠ BA。

从几何角度理解：矩阵代表线性变换，矩阵乘法是变换的复合。
先做变换 A 再做变换 B，和先做 B 再做 A，结果通常不同
（就像先旋转再平移，与先平移再旋转，效果不同）。
''',
      explanationDetail: '''
【考查要点】
1. 掌握"行乘以列"的矩阵乘法规则。
2. 正确计算 2×2 矩阵乘积：AB = [[19, 22], [43, 50]]。
3. 理解矩阵乘法不满足交换律的原因。

【常见错误】
- 错误一：把矩阵乘法当成对应元素相乘（element-wise），得到 [[5,12],[21,32]]，这是错的。
- 错误二：计算时行列搞混，比如用 A 的列去乘 B 的行。
- 错误三：以为交换律对矩阵也成立。

【判断 AB ≠ BA 的简便方法】
对于 2×2 矩阵，只需比较 AB[0][0] 和 BA[0][0]：
- AB[0][0] = a11×b11 + a12×b21
- BA[0][0] = b11×a11 + b12×a21
两者通常不等（除非特殊矩阵）。
''',
    ),

    // ── 3. 大学物理 - 牛顿第二定律 ──
    PresetCourse(
      subject: '大学物理',
      topic: '牛顿第二定律',
      emoji: '⚡',
      explanation: '''
⚡ 牛顿第二定律（Newton's Second Law）

【核心公式】
  F = m × a

其中：
- F：物体所受的合外力（Net Force），单位牛顿（N）
- m：物体质量（Mass），单位千克（kg）
- a：加速度（Acceleration），单位 m/s²

【物理含义】
力是改变物体运动状态的原因，而不是维持运动的原因。
质量越大，同样大小的力产生的加速度越小（惯性越大）。
力越大，加速度越大，速度变化越快。

【单位】
力的单位"牛顿"的定义：1 N = 1 kg × 1 m/s²
即让 1 kg 的物体产生 1 m/s² 加速度的力就是 1 牛顿。

【有摩擦力的情况】
实际中物体还受摩擦力阻碍运动：
- 滑动摩擦力 f = μ × N，其中 μ 为摩擦系数，N 为正压力
- 在水平面上，正压力 N = mg（重力）
- 所以摩擦力 f = μmg
- 实际加速度由"净力"决定：a = F_net / m = (F - f) / m

【g 的取值】
重力加速度 g ≈ 9.8 m/s²，题目中常取 g = 10 m/s² 简化计算。
''',
      question:
          '一个 2kg 的物体受到 10N 的水平力，求加速度。如果摩擦系数为 0.2，实际加速度是多少？(g=10m/s²)',
      answerKeyPoints: ['5', 'm/s²', '3', '摩擦力', '4N', '净力', '6N'],
      referenceAnswer: '''
【第一问：无摩擦时的加速度】
由牛顿第二定律 F = ma，得：
  a = F / m = 10N / 2kg = 5 m/s²

无摩擦时加速度为 5 m/s²。

【第二问：有摩擦时的实际加速度】
摩擦力 f = μmg = 0.2 × 2kg × 10m/s² = 4N

净力（合外力）= F - f = 10N - 4N = 6N

实际加速度 a = 净力 / m = 6N / 2kg = 3 m/s²

有摩擦时实际加速度为 3 m/s²。
''',
      explanationDetail: '''
【考查要点】
1. 直接应用 F = ma 求加速度：a = F/m = 10/2 = 5 m/s²。
2. 计算滑动摩擦力：f = μmg = 0.2 × 2 × 10 = 4N。
3. 用净力求实际加速度：a = (F - f) / m = (10 - 4) / 2 = 3 m/s²。

【关键概念】
- 牛顿第二定律中的 F 是"合外力"（净力），不是单个力。
- 无摩擦时净力 = 拉力 = 10N → a = 5 m/s²
- 有摩擦时净力 = 拉力 - 摩擦力 = 10 - 4 = 6N → a = 3 m/s²
- 摩擦力始终与运动方向相反，会减小加速度。

【易错点】
- 忘记减去摩擦力，直接用 10N 算（忽略了"实际"两字）。
- 摩擦力公式用错：f = μmg 中的 m 是质量 2kg，不是力 10N。
- g 取值：题目明确给 g=10m/s²，不要用 9.8。
''',
    ),
  ];

  /// 本地关键词匹配评分
  ///
  /// 将用户答案转为小写，检查每个 [keyPoints] 是否出现在答案中。
  /// - score = (命中数 / 总数) × 100，四舍五入
  /// - 返回 {"score": int, "matched": List<String>, "missed": List<String>}
  ///
  /// 示例：
  /// ```dart
  /// final r = PresetCourses.localScore(
  ///   '当x趋近于0时，sin(x)/x无限接近1但不等于1',
  ///   ['趋近', '无限接近', '不等于', 'x趋近于0', 'sin(x)/x', '1'],
  /// );
  /// print(r['score']); // 100
  /// ```
  static Map<String, dynamic> localScore(
    String userAnswer,
    List<String> keyPoints,
  ) {
    // 统一转小写做匹配，兼容大小写差异
    final answer = userAnswer.toLowerCase();

    final matched = <String>[];
    final missed = <String>[];

    for (final kp in keyPoints) {
      if (answer.contains(kp.toLowerCase())) {
        matched.add(kp);
      } else {
        missed.add(kp);
      }
    }

    // score = (命中 / 总数) * 100，四舍五入
    final total = keyPoints.length;
    final score = total > 0 ? (matched.length / total * 100).round() : 0;

    return {
      'score': score,
      'matched': matched,
      'missed': missed,
    };
  }

  /// 按科目名查找预置课程，找不到返回 null
  static PresetCourse? findBySubject(String subject) {
    for (final c in courses) {
      if (c.subject == subject) return c;
    }
    return null;
  }
}
