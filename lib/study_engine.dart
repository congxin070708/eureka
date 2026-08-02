/// 学习引擎 - 管理等级/XP/成就/收藏/统计
class StudyEngine {
  StudyEngine(); // 默认构造函数

  // ── 学习模式 ──
  String studyMode = '深度'; // '速学' | '深度' | '挑战'

  // ── 当前科目（多学科切换用） ──
  String currentSubject = '';

  // ── 等级/经验 ──
  int level = 1;
  int xp = 0;
  int xpNext = 100;
  int totalXp = 0;
  int totalQ = 0;
  int totalCorrect = 0;
  int streak = 0;
  int bestStreak = 0;
  int totalStudyMinutes = 0;

  Map<String, SubjectData> subjects = {};
  List<HistoryItem> history = [];
  List<Bookmark> bookmarks = [];
  List<DailyRecord> dailyRecords = [];
  // ── 聊天记录持久化 ──
  Map<String, List<Map<String, dynamic>>> chatHistory = {};

  int get accuracy => totalQ > 0 ? (totalCorrect * 100 ~/ totalQ) : 0;
  int get xpPercent => (xp * 100 ~/ xpNext);

  // ── 今日统计 ──
  DailyRecord get todayRecord {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    for (final r in dailyRecords) {
      if (r.date == today) return r;
    }
    final rec = DailyRecord(date: today);
    dailyRecords.insert(0, rec);
    if (dailyRecords.length > 30) dailyRecords = dailyRecords.sublist(0, 30);
    return rec;
  }

  // ── 收藏 ──
  void addBookmark(String subject, String title, String content) {
    bookmarks.insert(0, Bookmark(
      subject: subject, title: title, content: content,
      time: DateTime.now().toIso8601String(),
    ));
    if (bookmarks.length > 100) bookmarks = bookmarks.sublist(0, 100);
  }

  void removeBookmark(int index) {
    if (index >= 0 && index < bookmarks.length) {
      bookmarks.removeAt(index);
    }
  }

  bool get hasBookmarks => bookmarks.isNotEmpty;

  // ── 学习计时 ──
  void addStudyMinutes(int minutes) {
    totalStudyMinutes += minutes;
    todayRecord.minutes += minutes;
  }

  // ── 今日打卡 ──
  bool get isCheckedInToday => todayRecord.checkedIn;
  void checkIn() {
    if (!todayRecord.checkedIn) {
      todayRecord.checkedIn = true;
      // 签到奖励
      xp += 5;
      totalXp += 5;
      _checkLevelUp();
    }
  }

  // ── 学习天数统计 ──
  int get studyDays => dailyRecords.where((r) => r.minutes > 0 || r.checkedIn).length;
  int get consecutiveDays {
    if (dailyRecords.isEmpty) return 0;
    int count = 0;
    final now = DateTime.now();
    for (int i = 0; i < dailyRecords.length; i++) {
      final expected = now.subtract(Duration(days: i));
      final dateStr = expected.toIso8601String().substring(0, 10);
      if (dailyRecords.any((r) => r.date == dateStr && (r.minutes > 0 || r.checkedIn))) {
        count++;
      } else if (i > 0) {
        break; // 允许今天没学，但昨天要学
      }
    }
    return count;
  }

  SubjectData getSubject(String name) {
    subjects.putIfAbsent(name, () => SubjectData());
    return subjects[name]!;
  }

  /// 获取或创建知识点(按名字匹配)
  KnowledgePoint getOrCreateKnowledgePoint(String subject, String kpName,
      {String type = 'concept', int importance = 70}) {
    final sub = getSubject(subject);
    for (final kp in sub.knowledgePoints) {
      if (kp.name == kpName) return kp;
    }
    final kp = KnowledgePoint(
      name: kpName, type: type, importance: importance,
    );
    sub.knowledgePoints.add(kp);
    return kp;
  }

  /// 找知识点,找不到返回 null
  KnowledgePoint? findKnowledgePoint(String subject, String kpName) {
    final sub = subjects[subject];
    if (sub == null) return null;
    for (final kp in sub.knowledgePoints) {
      if (kp.name == kpName) return kp;
    }
    return null;
  }

  RecordResult record(String subject, int score) {
    totalQ++;
    final ok = score >= 60;
    if (ok) {
      totalCorrect++;
      streak++;
      bestStreak = streak > bestStreak ? streak : bestStreak;
    } else {
      streak = 0;
    }

    int xpGain = (score ~/ 10).clamp(1, 100);
    if (score >= 90) xpGain += 5;
    if (streak >= 3) xpGain += 2;

    xp += xpGain;
    totalXp += xpGain;

    bool leveledUp = false;
    while (xp >= xpNext) {
      xp -= xpNext;
      level++;
      xpNext = (xpNext * 1.4).toInt();
      leveledUp = true;
    }

    final sub = getSubject(subject);
    sub.q++;
    if (ok) sub.ok++;

    history.insert(0, HistoryItem(
      subject: subject,
      score: score,
      xpGain: xpGain,
      time: DateTime.now().toIso8601String(),
    ));
    if (history.length > 50) history = history.sublist(0, 50);

    // 记录今日答题
    todayRecord.questions++;
    todayRecord.correct += ok ? 1 : 0;

    return RecordResult(
      xpGain: xpGain,
      leveledUp: leveledUp,
      newLevel: leveledUp ? level : null,
      streak: streak,
      accuracy: accuracy,
      xp: xp,
      xpNext: xpNext,
      level: level,
    );
  }

  void _checkLevelUp() {
    while (xp >= xpNext) {
      xp -= xpNext;
      level++;
      xpNext = (xpNext * 1.4).toInt();
    }
  }

  Map<String, dynamic> toJson() => {
    'level': level, 'xp': xp, 'xpNext': xpNext, 'totalXp': totalXp,
    'totalQ': totalQ, 'totalCorrect': totalCorrect,
    'streak': streak, 'bestStreak': bestStreak,
    'totalStudyMinutes': totalStudyMinutes,
    'subjects': subjects.map((k, v) => MapEntry(k, v.toJson())),
    'history': history.map((h) => h.toJson()).toList(),
    'bookmarks': bookmarks.map((b) => b.toJson()).toList(),
    'dailyRecords': dailyRecords.map((r) => r.toJson()).toList(),
    'chatHistory': chatHistory.map((k, v) => MapEntry(k, v.map((m) => {
      'emoji': m['emoji'] ?? '',
      'text': m['text'] ?? '',
      'isAI': m['isAI'] ?? true,
    }).toList())),
  };

  factory StudyEngine.fromJson(Map<String, dynamic> json) {
    final e = StudyEngine();
    e.level = json['level'] ?? 1;
    e.xp = json['xp'] ?? 0;
    e.xpNext = json['xpNext'] ?? 100;
    e.totalXp = json['totalXp'] ?? 0;
    e.totalQ = json['totalQ'] ?? 0;
    e.totalCorrect = json['totalCorrect'] ?? 0;
    e.streak = json['streak'] ?? 0;
    e.bestStreak = json['bestStreak'] ?? 0;
    e.totalStudyMinutes = json['totalStudyMinutes'] ?? 0;
    if (json['subjects'] != null) {
      (json['subjects'] as Map).forEach((k, v) {
        e.subjects[k] = SubjectData.fromJson(v);
      });
    }
    if (json['history'] != null) {
      e.history = (json['history'] as List).map((h) => HistoryItem.fromJson(h)).toList();
    }
    if (json['bookmarks'] != null) {
      e.bookmarks = (json['bookmarks'] as List).map((b) => Bookmark.fromJson(b)).toList();
    }
    if (json['dailyRecords'] != null) {
      e.dailyRecords = (json['dailyRecords'] as List).map((r) => DailyRecord.fromJson(r)).toList();
    }
    return e;
  }
}

// ── 科目数据 ──
class SubjectData {
  int q = 0;
  int ok = 0;
  /// 该科目的知识点清单(掌握度门控用)
  List<KnowledgePoint> knowledgePoints = [];
  SubjectData({this.q = 0, this.ok = 0, List<KnowledgePoint>? knowledgePoints})
      : knowledgePoints = knowledgePoints ?? [];
  int get accuracy => q > 0 ? (ok * 100 ~/ q) : 0;
  Map<String, dynamic> toJson() => {
    'q': q, 'ok': ok,
    'kps': knowledgePoints.map((k) => k.toJson()).toList(),
  };
  factory SubjectData.fromJson(Map<String, dynamic> json) => SubjectData(
    q: json['q'] ?? 0, ok: json['ok'] ?? 0,
    knowledgePoints: (json['kps'] as List? ?? [])
        .map((k) => KnowledgePoint.fromJson(k)).toList(),
  );
}

// ── 知识点(掌握度门控) ──
class KnowledgePoint {
  final String name;        // 知识点名称(话题名)
  String type;              // memory | concept | procedure | design
  int importance;           // 价值系数 0-100
  List<bool> attempts;      // 答题历史 [对,错,对,...] 按时间顺序
  int intervalIndex;        // 遗忘曲线进度
  int consecutiveCorrect;
  int consecutiveWrong;
  int nextReviewAt;         // 下次复习时间戳(秒)
  bool qualitativeMastery;  // 概念/设计类AI评判通过标记

  KnowledgePoint({
    required this.name,
    this.type = 'concept',
    this.importance = 70,
    List<bool>? attempts,
    this.intervalIndex = 0,
    this.consecutiveCorrect = 0,
    this.consecutiveWrong = 0,
    this.nextReviewAt = 0,
    this.qualitativeMastery = false,
  }) : attempts = attempts ?? [];

  /// 近因加权掌握度 0..1 (借鉴 DeepTutor mastery.py, Dart 重写)
  double get mastery {
    if (attempts.isEmpty) return 0.0;
    const weights = [0.5, 0.7, 0.85, 0.95, 1.0];
    final recent = attempts.length > 5
        ? attempts.sublist(attempts.length - 5) : attempts;
    final w = weights.sublist(weights.length - recent.length);
    var score = 0.0;
    for (var i = 0; i < recent.length; i++) {
      score += w[i] * (recent[i] ? 1.0 : 0.0);
    }
    score /= w.reduce((a, b) => a + b);
    // 信心上限:只答1题最多50%,答2题最多80%,防蒙对一次就毕业
    final cap = recent.length == 1 ? 0.5 : (recent.length == 2 ? 0.8 : 1.0);
    return score > cap ? cap : score;
  }

  /// 掌握度门槛:价值系数(重要程度)加成
  /// 神级(90+)要练到95%;拓展(≤29)70%即可;默认90%
  double get gateThreshold {
    if (type == 'concept' || type == 'design') return 1.0; // 定性评判
    if (importance >= 90) return 0.95;
    if (importance <= 29) return 0.70;
    return 0.90;
  }

  bool get isMastered {
    if (type == 'concept' || type == 'design') return qualitativeMastery;
    return mastery >= gateThreshold;
  }

  /// 记录一次答题结果,返回最新掌握度
  double recordAttempt(bool correct) {
    attempts.add(correct);
    if (attempts.length > 20) attempts = attempts.sublist(attempts.length - 20);
    if (correct) {
      consecutiveWrong = 0;
      consecutiveCorrect++;
    } else {
      consecutiveCorrect = 0;
      consecutiveWrong++;
    }
    return mastery;
  }

  Map<String, dynamic> toJson() => {
    'n': name, 't': type, 'i': importance,
    'a': attempts, 'ii': intervalIndex,
    'cc': consecutiveCorrect, 'cw': consecutiveWrong,
    'nr': nextReviewAt, 'qm': qualitativeMastery,
  };

  factory KnowledgePoint.fromJson(Map<String, dynamic> json) => KnowledgePoint(
    name: json['n'] ?? '',
    type: json['t'] ?? 'concept',
    importance: json['i'] ?? 70,
    attempts: (json['a'] as List? ?? []).map((e) => e == true).toList(),
    intervalIndex: json['ii'] ?? 0,
    consecutiveCorrect: json['cc'] ?? 0,
    consecutiveWrong: json['cw'] ?? 0,
    nextReviewAt: json['nr'] ?? 0,
    qualitativeMastery: json['qm'] ?? false,
  );
}

// ── 历史记录 ──
class HistoryItem {
  final String subject;
  final int score;
  final int xpGain;
  final String time;
  HistoryItem({required this.subject, required this.score, required this.xpGain, required this.time});
  Map<String, dynamic> toJson() => {'s': subject, 'sc': score, 'xp': xpGain, 't': time};
  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    subject: json['s'] ?? '', score: json['sc'] ?? 0, xpGain: json['xp'] ?? 0, time: json['t'] ?? '',
  );
}

// ── 评分结果 ──
class RecordResult {
  final int xpGain;
  final bool leveledUp;
  final int? newLevel;
  final int streak;
  final int accuracy;
  final int xp;
  final int xpNext;
  final int level;
  RecordResult({required this.xpGain, required this.leveledUp, this.newLevel,
    required this.streak, required this.accuracy, required this.xp, required this.xpNext, required this.level});
}

// ── 收藏 ──
class Bookmark {
  final String subject;
  final String title;
  String content;
  final String time;
  Bookmark({required this.subject, required this.title, required this.content, required this.time});
  Map<String, dynamic> toJson() => {'s': subject, 't': title, 'c': content, 'tm': time};
  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
    subject: json['s'] ?? '', title: json['t'] ?? '', content: json['c'] ?? '', time: json['tm'] ?? '',
  );
}

// ── 每日记录 ──
class DailyRecord {
  final String date;
  int minutes = 0;
  int questions = 0;
  int correct = 0;
  bool checkedIn = false;

  DailyRecord({required this.date, this.minutes = 0, this.questions = 0, this.correct = 0, this.checkedIn = false});

  int get accuracy => questions > 0 ? (correct * 100 ~/ questions) : 0;

  Map<String, dynamic> toJson() => {
    'd': date, 'm': minutes, 'q': questions, 'c': correct, 'ci': checkedIn,
  };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
    date: json['d'] ?? '', minutes: json['m'] ?? 0,
    questions: json['q'] ?? 0, correct: json['c'] ?? 0,
    checkedIn: json['ci'] ?? false,
  );
}
