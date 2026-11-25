import 'package:bilgi_motoru/src/data/spaceart.dart';
import 'package:bilgi_motoru/src/quiz.dart';
import 'package:bilgi_motoru/src/spaceart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/rng.dart';

void main() {
  test('uzay ve sanat tabloları 33 dilde ve tutarlı', () {
    final tables = <String, List<List<String>>>{
      'kSpcFactQ': kSpcFactQ, 'kSpcNumQ': kSpcNumQ, 'kSpcEventTexts': kSpcEventTexts, 'kMoonNames': kMoonNames, //
      'kConstNames': kConstNames, 'kStarNames': kStarNames, 'kDwarfNames': kDwarfNames, 'kMoveNames': kMoveNames, //
      'kArtistNames': kArtistNames, 'kPaintNames': kPaintNames, 'kAuthorNames': kAuthorNames, 'kBookNames': kBookNames,
    };
    tables.forEach((name, rows) {
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].length, 33, reason: '$name[$i]');
        expect(rows[i].every((s) => s.trim().isNotEmpty), isTrue, reason: '$name[$i]');
      }
    });
    expect(kSpcFactQ.length, kSpcFactAns.length);
    expect(kSpcNumQ.length, kSpcNumOpts.length);
    expect(kSpcEventTexts.length, kSpcEventYears.length);
    expect(kMoonNames.length, kMoonPlanet.length);
    expect(kStarNames.length, kStarConst.length);
    expect(kArtistNames.length, kArtistInfo.length);
    expect(kPaintNames.length, kPaintInfo.length);
    expect(kAuthorNames.length, kAuthorIso.length);
    expect(kBookNames.length, kBookInfo.length);
    for (final o in kSpcNumOpts) {
      expect(o.toSet().length, o.length);
    }
    // Kamu malı: bütün tarihli eserler 1930 öncesi.
    for (final p in kPaintInfo) {
      expect(p.$2 < 1930, isTrue);
    }
    for (final b in kBookInfo) {
      expect(b.$2 < 1930, isTrue);
    }
  });

  test('uzay ve sanat şablonları her zorlukta tek doğru yanıtlı soru üretir', () {
    for (var t = Tpl.spcFact; t <= Tpl.artOld; t++) {
      for (var d = 1; d <= 10; d++) {
        var ok = 0;
        for (var s = 0; s < 60; s++) {
          final q = kGens[t](d, SeededRandom(mixSeed([t, d, s, 5])));
          if (q != null && q.t == t && checkQ(q)) ok++;
        }
        expect(ok, greaterThan(30), reason: 'şablon $t zorluk $d');
      }
    }
  });

  test('ondalık ayırıcı dile göre', () {
    expect(spcNumText('13.8', 'tr'), '13,8');
    expect(spcNumText('13.8', 'en'), '13.8');
  });
}
