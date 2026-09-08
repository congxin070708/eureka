import 'package:flutter_test/flutter_test.dart';
import 'package:eureka/study_engine.dart';

void main() {
  test('StudyEngine smoke test - create and record', () {
    final engine = StudyEngine();
    expect(engine.level, 1);
    expect(engine.xp, 0);

    final result = engine.record('数学', 80);
    expect(engine.totalQ, 1);
    expect(engine.totalCorrect, 1);
    expect(result.xpGain, greaterThan(0));
  });
}
