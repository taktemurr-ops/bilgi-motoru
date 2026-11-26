import 'package:bilgi_motoru/bilgi_motoru.dart';
import 'package:bilgi_motoru/src/data/shapes.dart';
import 'package:bilgi_motoru/src/ek4.dart';
import 'package:bilgi_motoru/src/texts_ek4.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  test('4. tur metinleri ve Halk Ne Dedi? verisi 33 dilde', () {
    for (final e in kBilgiTexts4.entries) {
      expect(e.value.length, 33, reason: e.key);
      expect(e.value.every((s) => s.trim().isNotEmpty), isTrue, reason: e.key);
    }
    expect(kSvQ.length, greaterThanOrEqualTo(15));
    for (var i = 0; i < kSvQ.length; i++) {
      expect(kSvQ[i].length, 33);
      expect(kSvA[i].length, 5);
      expect(kSvD[i].length, 3);
      for (final a in [...kSvA[i], ...kSvD[i]]) {
        expect(a.length, 33);
      }
      for (var l = 0; l < 33; l++) {
        final words = {for (final a in [...kSvA[i], ...kSvD[i]]) a[l]};
        expect(words.length, 8, reason: 'soru $i dil $l: yanıtlar ayırt edilebilir olmalı');
      }
    }
    // Tahmini olduğu açıkça yazılır.
    expect(kBilgiTexts4['svNote']!.first.contains('tahmini'), isTrue);
  });

  test('cin her kategoride çoğu varlığı dürüst yanıtlarla 20 soruda bulur', () {
    for (var cat = 0; cat < 3; cat++) {
      final n = kGenieBases[cat].n;
      var ok = 0;
      for (var e = 0; e < n; e++) {
        if (genieSolves(cat, e, 20)) ok++;
      }
      expect(ok / n, greaterThan(0.9), reason: 'kategori $cat: $ok/$n');
    }
  });

  test('silüetler: neredeyse her ülke için en az bir halka', () {
    expect(kShapes.length, 193);
    expect(kShapes.where((s) => s.length >= 9).length, greaterThanOrEqualTo(190));
  });

  test('pusula yönü: kuzeye 0, doğuya 90', () {
    expect(bearingDeg(0, 0, 10, 0), closeTo(0, 0.01));
    expect(bearingDeg(0, 0, 0, 10), closeTo(90, 0.01));
  });

  test('100.000 bölümün geniş örneklemi kurulur ve doğrulanır', () {
    for (final k in ['aklimdan', 'halk', 'merdiven', 'siluet']) {
      final rules = bilgiRulesFor('oyun-test-$k', k);
      expect(rules.levelCount, 100000);
      final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
      final r = SeededRandom(17);
      for (var i = 0; i < 200; i++) {
        final n = 1 + r.nextInt(100000);
        expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: '$k $n');
      }
    }
  });
}
