import 'package:flutter_test/flutter_test.dart';
import 'package:bilgi_motoru/src/data/countries.dart';
import 'package:bilgi_motoru/src/data/elements.dart';
import 'package:bilgi_motoru/src/data/events.dart';
import 'package:bilgi_motoru/src/data/provinces.dart';
import 'package:bilgi_motoru/src/quiz.dart';
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
}
