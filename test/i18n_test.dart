import 'package:bilgi_motoru/src/data/animals.dart';
import 'package:bilgi_motoru/src/data/elements.dart';
import 'package:bilgi_motoru/src/data/events.dart';
import 'package:bilgi_motoru/src/data/extra.dart';
import 'package:bilgi_motoru/src/data/i18n.dart';
import 'package:bilgi_motoru/src/data/sport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/core/strings.dart';

void main() {
  test('her içerik satırı 33 dilde dolu', () {
    final tables = <String, (List<List<String>>, int)>{
      'elements': (kElemNames, kElements.length),
      'animals': (kAnimalNames, kAnimals.length),
      'events': (kEventTexts, kEvents.length),
      'dishes': (kDishNames, kDishes.length),
      'facts': (kFactTexts, kFacts.length),
      'factExplain': (kFactExplain, kFacts.length),
      'numFacts': (kNumFactTexts, kNumFacts.length),
      'mountains': (kMountainNames, kMountains.length),
      'sports': (kSportNames, kSports.length),
    };
    expect(Strings.languages.length, 33);
    tables.forEach((name, t) {
      final (rows, n) = t;
      expect(rows.length, n, reason: name);
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].length, 33, reason: '$name[$i]');
        for (var j = 0; j < 33; j++) {
          expect(rows[i][j].trim(), isNotEmpty, reason: '$name[$i][${Strings.languages[j]}]');
        }
      }
    });
  });

  test('çeviriler İngilizcenin kopyası değil (dil başına çoğunluk)', () {
    // Özel adlar (yemek, dağ) aynı kalabilir; olay cümleleri dile özgü olmalı.
    for (var j = 2; j < 33; j++) {
      final same = kEventTexts.where((r) => r[j] == r[1]).length;
      expect(same, lessThan(10), reason: Strings.languages[j]);
    }
  });
}
