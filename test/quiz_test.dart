import 'package:flutter_test/flutter_test.dart';
import 'package:bilgi_motoru/src/data/countries.dart';
import 'package:bilgi_motoru/src/data/elements.dart';
import 'package:bilgi_motoru/src/data/events.dart';
import 'package:bilgi_motoru/src/data/provinces.dart';
import 'package:bilgi_motoru/src/data/extra.dart';
import 'package:bilgi_motoru/src/quiz.dart';
import 'package:bilgi_motoru/src/quiz_ext.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  test('veri tabloları tutarlı', () {
    expect(kCountries.length, 193);
    expect(kCountryNames.length, 193);
    expect(kCapitals.length, 193);
    for (final row in kCountryNames) {
      expect(row.length, 33);
    }
    expect(kProvinces.length, 81);
    for (var i = 0; i < 81; i++) {
      expect(kProvinces[i].plate, i + 1);
    }
    expect(kElements.length, 118);
    expect(kUnits.length, kUnitWrong.length);
  });

  test('her şablon her zorlukta geçerli soru üretir', () {
    for (var t = 0; t < Tpl.count; t++) {
      for (var d = 1; d <= 10; d++) {
        var ok = 0;
        for (var s = 0; s < 40; s++) {
          final q = kGens[t](d, SeededRandom(mixSeed([t, d, s])));
          if (q != null && q.t == t && checkQ(q)) ok++;
        }
        expect(ok, greaterThan(5), reason: 'şablon $t zorluk $d');
      }
    }
  });

  test('her soru 33 dilde yazılabilir', () {
    for (var t = 0; t < Tpl.count; t++) {
      final q = kGens[t](5, SeededRandom(mixSeed([t, 99])));
      if (q == null) continue;
      for (final lang in const ['tr', 'en', 'ar', 'ja', 'fil', 'ru']) {
        final r = renderQ(q, lang);
        expect(r.prompt.contains('{'), isFalse, reason: '$t $lang ${r.prompt}');
        expect(r.options.length, q.o.length);
        expect(explain(q, lang).isNotEmpty, isTrue);
      }
    }
  });

  test('sıralama denetimi', () {
    for (var s = 0; s < 20; s++) {
      final q = genOrder(5, SeededRandom(s));
      if (q == null) continue;
      final idx = [for (var i = 0; i < q.o.length; i++) i]
        ..sort((a, b) => kEvents[q.o[a]].year.compareTo(kEvents[q.o[b]].year));
      expect(orderCorrect(q, idx), isTrue);
      expect(orderCorrect(q, idx.reversed.toList()), isFalse);
    }
  });

  test('ek veri tabloları tutarlı', () {
    expect(kDishes.length, greaterThanOrEqualTo(120));
    for (final x in kDishes) {
      expect(x.country >= 0 && x.country < kCountries.length, isTrue, reason: x.en);
    }
    expect(kFacts.length, greaterThanOrEqualTo(100));
    expect(kFacts.where((f) => f.truth).length, greaterThan(40));
    expect(kFacts.where((f) => !f.truth).length, greaterThan(40));
    for (var i = 1; i < kMountains.length; i++) {
      expect(kMountains[i - 1].m, greaterThan(kMountains[i].m));
    }
    expect(kPlanetDist.length, 8);
  });

  test('tahminde doğru değere yakın yanıt kabul edilir, uzak yanıt edilmez', () {
    for (var s = 0; s < 200; s++) {
      final q = genEst(1 + s % 10, SeededRandom(s));
      if (q == null) continue;
      expect(checkQ(q), isTrue);
      final spec = estSpec(q);
      final g = spec.round(spec.at(spec.posOf(spec.value)));
      expect(spec.error(g) <= spec.tol, isTrue, reason: 'tahmin ${q.a}');
      expect(spec.error(spec.round(spec.at(0))) <= spec.tol && spec.error(spec.round(spec.at(1))) <= spec.tol, isFalse);
    }
  });

  test('sıralama ölçütleri ve doğru/uydurma tutarlı', () {
    for (var s = 0; s < 100; s++) {
      final q = genSortP(1 + s % 10, SeededRandom(s));
      if (q != null) {
        expect(checkQ(q), isTrue);
        final idx = [for (var i = 0; i < q.o.length; i++) i]..sort((a, b) => orderKey(q, a).compareTo(orderKey(q, b)));
        expect(orderCorrect(q, idx), isTrue);
        expect(orderCorrect(q, idx.reversed.toList()), isFalse);
      }
      final t = genTf(1 + s % 10, SeededRandom(s + 500));
      if (t != null) {
        expect(checkQ(t), isTrue);
        expect(t.ans, tfTruth(t.a) ? 0 : 1);
      }
    }
  });
}
