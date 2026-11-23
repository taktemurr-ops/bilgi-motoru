import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:bilgi_motoru/bilgi_motoru.dart';

void main() {
  for (final e in kBilgiKinds.entries) {
    test('${e.key}: bölümler kurulur ve doğrulanır', () {
      final rules = bilgiRulesFor('oyun-test-${e.key}', e.key);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      for (final n in const [1, 7, 40, 300, 5000, 33333, 99999]) {
        final gl = rules.build(planner.spec(n));
        expect(gl.validation.ok, isTrue, reason: '${e.key} $n');
      }
    });
  }

  test('metinler 33 dilde', () {
    for (final e in kBilgiTexts.entries) {
      expect(e.value.length, 33, reason: e.key);
    }
  });
}
