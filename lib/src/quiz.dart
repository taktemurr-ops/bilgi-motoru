import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import 'data/animals.dart';
import 'data/countries.dart';
import 'data/elements.dart';
import 'data/events.dart';
import 'data/provinces.dart';
import 'model.dart';
import 'quiz_ext.dart';
import 'texts.dart';

/// Soru şablonları. Bir soru dil bağımsız tutulur (kimlikler ve sayılar);
/// metinler ekranda, oyuncunun diline göre kurulur.
class Tpl {
  static const cap = 0, cont = 1, pinCountry = 2, tapCountry = 3, area = 4;
  static const plate = 5, plateRev = 6, region = 7, pinProv = 8, tapProv = 9, north = 10, east = 11;
  static const z2s = 12, s2z = 13, cat = 14, liquid = 15, gas = 16, period = 17, mass = 18;
  static const planetN = 19, planetBig = 20, rocky = 21, unit = 22;
  static const cls = 23, notCls = 24, eggs = 25, sea = 26, biggest = 27, legs = 28, herb = 29, carn = 30;
  static const year = 31, first = 32, later = 33, order = 34, span = 35, bigger = 36;
  static const est = 37, sortP = 38, tf = 39, dish = 40, dishRev = 41;
  static const count = 42;
}

/// Bir soru: şablon, argümanlar, seçenekler ve doğru seçeneğin sırası.
/// Harita ve sıralama sorularında [ans] -1'dir.
class BQ {
  final int t;
  final List<int> a;
  final List<int> o;
  final int ans;
  const BQ(this.t, this.a, this.o, this.ans);

  QMode get mode => switch (t) {
        Tpl.tapCountry => QMode.mapWorld,
        Tpl.tapProv => QMode.mapTurkey,
        Tpl.order || Tpl.sortP => QMode.order,
        Tpl.est => QMode.estimate,
        _ => QMode.choice,
      };

  /// Seçenekler uzun yazı mı (alt alta dizilir)?
  bool get longOptions => t == Tpl.first || t == Tpl.later || t == Tpl.order || t == Tpl.dishRev;

  /// Seçenekler emoji mi?
  bool get emojiOptions => t >= Tpl.cls && t <= Tpl.carn && t != Tpl.legs || t == Tpl.bigger;

  /// Seçenekler element kutucuğu mu?
  bool get elementOptions => t == Tpl.z2s || t == Tpl.cat || t == Tpl.liquid || t == Tpl.gas || t == Tpl.mass;
}

enum QMode { choice, mapWorld, mapTurkey, order, estimate }

/// Ekranda soru üstünde gösterilen görsel.
enum QVisual { none, worldPin, turkeyPin, plate, element, number, emoji, event, unit, province, dish }

// ------------------------------------------------------------------ sabit veri

/// Gezegen çapları (km), Güneş'ten uzaklık sırasıyla.
const List<int> kPlanetKm = [4879, 12104, 12742, 6779, 139820, 116460, 50724, 49244];

/// Birim çevirme soruları: sol taraf, sağ birim, doğru değer (yazı).
const List<(String, String, String)> kUnits = [
  ('1 km', 'm', '1000'),
  ('1 m', 'cm', '100'),
  ('1 m', 'mm', '1000'),
  ('1 cm', 'mm', '10'),
  ('1 kg', 'g', '1000'),
  ('1 g', 'mg', '1000'),
  ('1 t', 'kg', '1000'),
  ('1 L', 'mL', '1000'),
  ('1 h', 'min', '60'),
  ('1 min', 's', '60'),
  ('1 h', 's', '3600'),
  ('1 m²', 'cm²', '10000'),
  ('1 km²', 'm²', '1000000'),
  ('1 ha', 'm²', '10000'),
  ('1 m³', 'L', '1000'),
  ('1 cm³', 'mL', '1'),
  ('1 km', 'cm', '100000'),
  ('1 kWh', 'Wh', '1000'),
  ('0 °C', 'K', '273.15'),
  ('0 °C', '°F', '32'),
  ('100 °C', '°F', '212'),
];

/// Her birim sorusu için yanıltıcı seçenekler.
const List<List<String>> kUnitWrong = [
  ['100', '10000', '10'],
  ['10', '1000', '1'],
  ['100', '10', '10000'],
  ['100', '1', '1000'],
  ['100', '10000', '10'],
  ['100', '10', '10000'],
  ['100', '10000', '10'],
  ['100', '10', '10000'],
  ['100', '24', '30'],
  ['100', '24', '30'],
  ['360', '6000', '1000'],
  ['100', '1000', '1000000'],
  ['1000', '10000', '100000'],
  ['1000', '100', '100000'],
  ['100', '10', '10000'],
  ['10', '100', '1000'],
  ['1000', '10000', '1000000'],
  ['100', '10', '3600'],
  ['100', '-273.15', '0'],
  ['0', '100', '-32'],
  ['100', '180', '273'],
];

// ------------------------------------------------------------------ yardımcılar

int langIndex(String lang) {
  final i = Strings.languages.indexOf(lang);
  return i < 0 ? 1 : i;
}

String countryName(int i, String lang) => Strings.pick(kCountryNames[i], lang);

/// Başkentin bu dildeki adı; yoksa null.
String? capitalLocal(int i, String lang) {
  final row = kCapitals[i];
  final li = langIndex(lang);
  return li < row.length ? row[li] : null;
}

String capitalAny(int i, String lang) => capitalLocal(i, lang) ?? kCapitals[i][1]!;

String continentName(int c, String lang) => Strings.pick(kContinents[c], lang);

String regionName(int r, String lang) => bt(lang, 'reg$r');

String planetName(int p, String lang) => bt(lang, 'pl$p');

String clsName(int c, String lang) => bt(lang, 'cls$c');

String catName(int c, String lang) => bt(lang, 'cat$c');

String elemName(Elem e, String lang) => lang == 'tr' ? e.tr : e.en;

/// Hayvanın adı yalnız Türkçe ve İngilizcede yazılır; diğer dillerde emoji yeter.
String animalName(Animal a, String lang) => lang == 'tr' ? a.tr : (lang == 'en' ? a.en : '');

String eventText(HEvent e, String lang) => lang == 'tr' ? e.tr : e.en;

/// 643801 → "643 801" (dar boşlukla gruplanır, her dilde okunur).
String groupDigits(int v) {
  final s = v.abs().toString();
  final b = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}

String spanText(int start, int len) => '$start–${start + len - 1}';

/// İki nokta arası büyük daire uzaklığı (km).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.min<double>(1.0, math.sqrt(h)));
}

/// Haritaya dokunma sorusunda kabul edilen uzaklık (km).
double tapToleranceKm(int countryIndex, int d) {
  final c = kCountries[countryIndex];
  final base = math.max<double>(350.0, math.sqrt(c.area.toDouble()) * 0.75);
  final easy = 1.0 + (10 - d) * 0.06;
  return base * easy;
}

/// Türkiye haritasında kabul edilen uzaklık (km).
double tapProvToleranceKm(int d) => 30.0 + (10 - d) * 4.0;

// ------------------------------------------------------------------ metinler

class QText {
  final String prompt;
  final List<String> options;
  const QText(this.prompt, this.options);
}

/// Ekrandaki soru ve seçenek metinleri.
QText renderQ(BQ q, String lang) {
  if (q.t >= Tpl.est) return renderExt(q, lang);
  switch (q.t) {
    case Tpl.cap: {
      final c = q.a[0];
      final local = q.o.every((i) => capitalLocal(i, lang) != null);
      if (local) {
        return QText(bt(lang, 'qCap', {'c': countryName(c, lang)}), [for (final i in q.o) capitalLocal(i, lang)!]);
      }
      return QText(bt(lang, 'qCapRev', {'x': capitalAny(c, lang)}), [for (final i in q.o) countryName(i, lang)]);
    }
    case Tpl.cont:
      return QText(bt(lang, 'qCont', {'c': countryName(q.a[0], lang)}), [for (final i in q.o) continentName(i, lang)]);
    case Tpl.pinCountry:
      return QText(bt(lang, 'qPinCountry'), [for (final i in q.o) countryName(i, lang)]);
    case Tpl.tapCountry:
      return QText(bt(lang, 'qTapCountry', {'c': countryName(q.a[0], lang)}), const []);
    case Tpl.area:
      return QText(bt(lang, 'qArea'), [for (final i in q.o) countryName(i, lang)]);
    case Tpl.plate:
      return QText(bt(lang, 'qPlate', {'n': _plate(q.a[0])}), [for (final i in q.o) kProvinces[i].name]);
    case Tpl.plateRev:
      return QText(bt(lang, 'qPlateRev', {'x': kProvinces[q.a[0]].name}), [for (final i in q.o) _plate(i)]);
    case Tpl.region:
      return QText(bt(lang, 'qRegion', {'x': kProvinces[q.a[0]].name}), [for (final i in q.o) regionName(i, lang)]);
    case Tpl.pinProv:
      return QText(bt(lang, 'qPinProv'), [for (final i in q.o) kProvinces[i].name]);
    case Tpl.tapProv:
      return QText(bt(lang, 'qTapProv', {'x': kProvinces[q.a[0]].name}), const []);
    case Tpl.north:
      return QText(bt(lang, 'qNorth'), [for (final i in q.o) kProvinces[i].name]);
    case Tpl.east:
      return QText(bt(lang, 'qEast'), [for (final i in q.o) kProvinces[i].name]);
    case Tpl.z2s:
      return QText(bt(lang, 'qZ2S', {'n': kElements[q.a[0]].z}), [for (final i in q.o) kElements[i].sym]);
    case Tpl.s2z:
      return QText(bt(lang, 'qS2Z', {'s': kElements[q.a[0]].sym}), [for (final i in q.o) '${kElements[i].z}']);
    case Tpl.cat:
      return QText(bt(lang, 'qCat', {'cat': catName(q.a[0], lang)}), [for (final i in q.o) kElements[i].sym]);
    case Tpl.liquid:
      return QText(bt(lang, 'qLiquid'), [for (final i in q.o) kElements[i].sym]);
    case Tpl.gas:
      return QText(bt(lang, 'qGas'), [for (final i in q.o) kElements[i].sym]);
    case Tpl.period:
      return QText(bt(lang, 'qPeriod', {'s': kElements[q.a[0]].sym}), [for (final p in q.o) '$p']);
    case Tpl.mass:
      return QText(bt(lang, 'qMass'), [for (final i in q.o) kElements[i].sym]);
    case Tpl.planetN:
      return QText(bt(lang, 'qPlanetN', {'n': q.a[0] + 1}), [for (final p in q.o) planetName(p, lang)]);
    case Tpl.planetBig:
      return QText(bt(lang, 'qPlanetBig'), [for (final p in q.o) planetName(p, lang)]);
    case Tpl.rocky:
      return QText(bt(lang, 'qRocky'), [for (final p in q.o) planetName(p, lang)]);
    case Tpl.unit: {
      final u = kUnits[q.a[0]];
      return QText(bt(lang, 'qUnit'), [for (final i in q.o) '${i == 0 ? u.$3 : kUnitWrong[q.a[0]][i - 1]} ${u.$2}']);
    }
    case Tpl.cls:
      return QText(bt(lang, 'qCls', {'cls': clsName(q.a[0], lang)}), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.notCls:
      return QText(bt(lang, 'qNotCls', {'cls': clsName(q.a[0], lang)}), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.eggs:
      return QText(bt(lang, 'qEggs'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.sea:
      return QText(bt(lang, 'qSea'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.biggest:
      return QText(bt(lang, 'qBiggest'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.bigger:
      return QText(bt(lang, 'qBigger'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.legs:
      return QText(bt(lang, 'qLegs'), [for (final n in q.o) '$n']);
    case Tpl.herb:
      return QText(bt(lang, 'qHerb'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.carn:
      return QText(bt(lang, 'qCarn'), [for (final i in q.o) kAnimals[i].emoji]);
    case Tpl.year:
      return QText(bt(lang, 'qYear'), [for (final y in q.o) '$y']);
    case Tpl.first:
      return QText(bt(lang, 'qFirst'), [for (final i in q.o) eventText(kEvents[i], lang)]);
    case Tpl.later:
      return QText(bt(lang, 'qLater'), [for (final i in q.o) eventText(kEvents[i], lang)]);
    case Tpl.order:
      return QText(bt(lang, 'qOrder'), [for (final i in q.o) eventText(kEvents[i], lang)]);
    case Tpl.span:
      return QText(bt(lang, 'qSpan'), [for (final s in q.o) spanText(s, q.a[1])]);
  }
  return const QText('?', []);
}

String _plate(int prov) => kProvinces[prov].plate.toString().padLeft(2, '0');

/// Soru üstündeki görsel.
QVisual visualOf(BQ q) => switch (q.t) {
      Tpl.pinCountry => QVisual.worldPin,
      Tpl.pinProv => QVisual.turkeyPin,
      Tpl.plate => QVisual.plate,
      Tpl.s2z || Tpl.period => QVisual.element,
      Tpl.z2s => QVisual.number,
      Tpl.legs => QVisual.emoji,
      Tpl.year || Tpl.span => QVisual.event,
      Tpl.unit => QVisual.unit,
      Tpl.plateRev || Tpl.region => QVisual.province,
      Tpl.dish => QVisual.dish,
      _ => QVisual.none,
    };

/// Yanıttan sonra gösterilen kısa açıklama.
String explain(BQ q, String lang) {
  if (q.t >= Tpl.est) return explainExt(q, lang);
  String prov(int i) {
    final p = kProvinces[i];
    return '${_plate(i)} · ${p.name} · ${regionName(p.region, lang)}';
  }

  String el(int i) {
    final e = kElements[i];
    final n = elemName(e, lang);
    return lang == 'tr' || lang == 'en' ? '${e.sym} · ${e.z} · $n' : '${e.sym} · ${e.z}';
  }

  String an(int i) {
    final a = kAnimals[i];
    final n = animalName(a, lang);
    return n.isEmpty ? a.emoji : '${a.emoji} $n';
  }

  switch (q.t) {
    case Tpl.cap:
    case Tpl.pinCountry:
    case Tpl.tapCountry: {
      final c = q.a[0];
      final cont = kCountries[c].cont;
      return [countryName(c, lang), capitalAny(c, lang), if (cont >= 0) continentName(cont, lang)].join(' · ');
    }
    case Tpl.cont:
      return '${countryName(q.a[0], lang)} · ${continentName(kCountries[q.a[0]].cont, lang)}';
    case Tpl.area:
      return [for (final i in q.o) '${countryName(i, lang)}: ${groupDigits(kCountries[i].area)} km²'].join('\n');
    case Tpl.plate:
    case Tpl.plateRev:
    case Tpl.region:
    case Tpl.pinProv:
    case Tpl.tapProv:
      return prov(q.a[0]);
    case Tpl.north:
      return [for (final i in q.o) '${kProvinces[i].name}: ${kProvinces[i].lat.toStringAsFixed(2)}°'].join('\n');
    case Tpl.east:
      return [for (final i in q.o) '${kProvinces[i].name}: ${kProvinces[i].lon.toStringAsFixed(2)}°'].join('\n');
    case Tpl.z2s:
    case Tpl.s2z:
      return el(q.a[0]);
    case Tpl.period:
      return '${el(q.a[0])} · ${kElements[q.a[0]].period}';
    case Tpl.cat:
    case Tpl.liquid:
    case Tpl.gas:
      return el(q.o[q.ans]);
    case Tpl.mass:
      return [for (final i in q.o) '${kElements[i].sym}: ${kElements[i].mass.toStringAsFixed(2)} u'].join('\n');
    case Tpl.planetN:
    case Tpl.rocky:
      return [for (var p = 0; p < 8; p++) '${p + 1}. ${planetName(p, lang)}'].join('  ');
    case Tpl.planetBig:
      return [for (final p in q.o) '${planetName(p, lang)}: ${groupDigits(kPlanetKm[p])} km'].join('\n');
    case Tpl.unit: {
      final u = kUnits[q.a[0]];
      return '${u.$1} = ${u.$3} ${u.$2}';
    }
    case Tpl.cls:
    case Tpl.notCls:
      return [
        for (final i in q.o)
          if (kAnimals[i].cls >= 0) '${an(i)}: ${clsName(kAnimals[i].cls, lang)}'
      ].join('\n');
    case Tpl.eggs:
    case Tpl.sea:
    case Tpl.herb:
    case Tpl.carn:
      return an(q.o[q.ans]);
    case Tpl.biggest:
    case Tpl.bigger:
      return [for (final i in q.o) '${an(i)} ≈ ${_kg(kAnimals[i].kg)}'].join('\n');
    case Tpl.legs:
      return '${an(q.a[0])}: ${kAnimals[q.a[0]].legs}';
    case Tpl.year:
    case Tpl.span: {
      final e = kEvents[q.a[0]];
      return '${e.year} · ${eventText(e, lang)}';
    }
    case Tpl.first:
    case Tpl.later:
    case Tpl.order: {
      final xs = [...q.o]..sort((a, b) => kEvents[a].year.compareTo(kEvents[b].year));
      return [for (final i in xs) '${kEvents[i].year} · ${eventText(kEvents[i], lang)}'].join('\n');
    }
  }
  return '';
}

String _kg(double kg) {
  if (kg >= 1000) return '${groupDigits((kg / 1000).round())} t';
  if (kg >= 1) return '${kg.round()} kg';
  if (kg >= 0.001) return '${(kg * 1000).round()} g';
  return '< 1 g';
}

// ------------------------------------------------------------------ denetim

bool _distinct(List<Object> xs) => xs.toSet().length == xs.length;

/// Soru verilerle tutarlı ve tek doğru yanıtlı mı?
bool checkQ(BQ q) {
  final o = q.o;
  if (q.t < 0 || q.t >= Tpl.count) return false;
  if (q.mode == QMode.choice) {
    if (o.length < 2 || q.ans < 0 || q.ans >= o.length || !_distinct(o)) return false;
  }
  bool onlyAns(bool Function(int) ok) {
    for (var i = 0; i < o.length; i++) {
      if (ok(o[i]) != (i == q.ans)) return false;
    }
    return true;
  }

  if (q.t >= Tpl.est) return checkExt(q);
  switch (q.t) {
    case Tpl.cap: {
      final c = q.a[0];
      return kCountries[c].capOk && o[q.ans] == c && o.every((i) => kCountries[i].capOk) &&
          _distinct([for (final i in o) kCapitals[i][1]!]);
    }
    case Tpl.cont: {
      final cont = kCountries[q.a[0]].cont;
      return cont >= 0 && o[q.ans] == cont && o.every((x) => x >= 0 && x < kContinents.length);
    }
    case Tpl.pinCountry:
      return o[q.ans] == q.a[0] && kCountries[q.a[0]].onMap;
    case Tpl.tapCountry:
      return o.isEmpty && kCountries[q.a[0]].onMap;
    case Tpl.area: {
      final best = o[q.ans];
      return o.every((i) => i == best || kCountries[best].area >= kCountries[i].area * 1.25);
    }
    case Tpl.plate:
    case Tpl.plateRev:
    case Tpl.pinProv:
      return o[q.ans] == q.a[0];
    case Tpl.region:
      return o[q.ans] == kProvinces[q.a[0]].region && o.every((r) => r >= 0 && r < 7);
    case Tpl.tapProv:
      return o.isEmpty && q.a[0] >= 0 && q.a[0] < kProvinces.length;
    case Tpl.north: {
      final b = kProvinces[o[q.ans]].lat;
      return o.every((i) => i == o[q.ans] || b - kProvinces[i].lat >= 0.4);
    }
    case Tpl.east: {
      final b = kProvinces[o[q.ans]].lon;
      return o.every((i) => i == o[q.ans] || b - kProvinces[i].lon >= 0.6);
    }
    case Tpl.z2s:
    case Tpl.s2z:
      return o[q.ans] == q.a[0];
    case Tpl.cat:
      return onlyAns((i) => kElements[i].cat == q.a[0]);
    case Tpl.liquid:
      return onlyAns((i) => kElements[i].state == 1) && o.every((i) => kElements[i].state >= 0);
    case Tpl.gas:
      return onlyAns((i) => kElements[i].state == 2) && o.every((i) => kElements[i].state >= 0);
    case Tpl.period:
      return o[q.ans] == kElements[q.a[0]].period && o.every((p) => p >= 1 && p <= 7);
    case Tpl.mass: {
      final b = kElements[o[q.ans]].mass;
      return o.every((i) => i == o[q.ans] || b >= kElements[i].mass * 1.1);
    }
    case Tpl.planetN:
      return o[q.ans] == q.a[0];
    case Tpl.planetBig: {
      final b = kPlanetKm[o[q.ans]];
      return o.every((p) => p == o[q.ans] || b >= kPlanetKm[p] * 1.1);
    }
    case Tpl.rocky:
      return onlyAns((p) => p < 4);
    case Tpl.unit:
      return q.a[0] >= 0 && q.a[0] < kUnits.length && o[q.ans] == 0 && o.every((i) => i >= 0 && i <= 3);
    case Tpl.cls:
      return onlyAns((i) => kAnimals[i].cls == q.a[0]) && o.every((i) => kAnimals[i].cls >= -1);
    case Tpl.notCls:
      return onlyAns((i) => kAnimals[i].cls != q.a[0]);
    case Tpl.eggs:
      return onlyAns((i) => kAnimals[i].eggs == 1) && o.every((i) => kAnimals[i].eggs >= 0);
    case Tpl.sea:
      return onlyAns((i) => kAnimals[i].sea == 1) && o.every((i) => kAnimals[i].sea >= 0);
    case Tpl.biggest:
    case Tpl.bigger: {
      final b = kAnimals[o[q.ans]].kg;
      return o.every((i) => kAnimals[i].kg > 0 && (i == o[q.ans] || b >= kAnimals[i].kg * 3));
    }
    case Tpl.legs:
      return o[q.ans] == kAnimals[q.a[0]].legs && kAnimals[q.a[0]].legs >= 0;
    case Tpl.herb:
      return onlyAns((i) => kAnimals[i].diet == 0) && o.every((i) => kAnimals[i].diet == 0 || kAnimals[i].diet == 1);
    case Tpl.carn:
      return onlyAns((i) => kAnimals[i].diet == 1) && o.every((i) => kAnimals[i].diet == 0 || kAnimals[i].diet == 1);
    case Tpl.year:
      return o[q.ans] == kEvents[q.a[0]].year;
    case Tpl.first: {
      final y = kEvents[o[q.ans]].year;
      return o.every((i) => i == o[q.ans] || kEvents[i].year > y);
    }
    case Tpl.later: {
      final y = kEvents[o[q.ans]].year;
      return o.every((i) => i == o[q.ans] || kEvents[i].year < y);
    }
    case Tpl.order:
      return o.length >= 3 && _distinct([for (final i in o) kEvents[i].year]);
    case Tpl.span: {
      final y = kEvents[q.a[0]].year, len = q.a[1];
      return onlyAns((s) => y >= s && y < s + len);
    }
  }
  return false;
}

/// Sıralama sorusu: verilen dokunuş sırası doğru mu?
bool orderCorrect(BQ q, List<int> picks) {
  if (picks.length != q.o.length || picks.toSet().length != picks.length) return false;
  for (var k = 1; k < picks.length; k++) {
    if (orderKey(q, picks[k - 1]) >= orderKey(q, picks[k])) return false;
  }
  return true;
}

// ------------------------------------------------------------------ üretim

/// Şablon üreticisi: zorluk ve rastgele kaynakla bir soru kurar (olmazsa null).
typedef QGen = BQ? Function(int d, SeededRandom r);

List<int> _pickDistinct(SeededRandom r, int n, int count, bool Function(int) ok, {Set<int> avoid = const {}}) {
  final out = <int>[];
  for (var g = 0; g < 400 && out.length < count; g++) {
    final v = r.nextInt(n);
    if (!ok(v) || out.contains(v) || avoid.contains(v)) continue;
    out.add(v);
  }
  return out;
}

/// Doğru yanıtı rastgele bir sıraya yerleştirir.
BQ _mk(int t, List<int> a, int correct, List<int> wrong, SeededRandom r) {
  final opts = [correct, ...wrong];
  r.shuffle(opts);
  return BQ(t, a, opts, opts.indexOf(correct));
}

int _nOpts(int d) => d <= 2 ? 3 : 4;

/// Zorluğa göre ülke havuzu: kolayda büyük ve tanınmış ülkeler.
List<int> _countryPool(int d) {
  final idx = [for (var i = 0; i < kCountries.length; i++) i]
    ..sort((a, b) => kCountries[b].area.compareTo(kCountries[a].area));
  final n = math.min<int>(kCountries.length, 45 + d * 16);
  final pool = idx.take(n).toSet()..addAll(_famous());
  return pool.toList()..sort();
}

Set<int> _famous() {
  const isos = {'TR', 'DE', 'FR', 'IT', 'ES', 'GB', 'JP', 'KR', 'NL', 'GR', 'PT', 'CH', 'AT', 'BE', 'IE', 'IL', 'QA', 'SG', 'CU', 'NZ', 'AZ', 'GE', 'KW', 'LB', 'JO', 'DK'};
  return {for (var i = 0; i < kCountries.length; i++) if (isos.contains(kCountries[i].iso)) i};
}

final Map<int, List<int>> _poolCache = {};
List<int> countryPool(int d) => _poolCache.putIfAbsent(d, () => _countryPool(d));

BQ? genCap(int d, SeededRandom r) {
  final pool = countryPool(d).where((i) => kCountries[i].capOk).toList();
  final c = r.pick(pool);
  final wrong = _pickDistinct(r, pool.length, _nOpts(d) - 1, (k) => pool[k] != c).map((k) => pool[k]).toList();
  // Zorda aynı kıtadan seçenekler.
  if (d >= 6 && kCountries[c].cont >= 0) {
    final same = pool.where((i) => i != c && kCountries[i].cont == kCountries[c].cont).toList();
    if (same.length >= 3) {
      r.shuffle(same);
      return _mk(Tpl.cap, [c], c, same.take(_nOpts(d) - 1).toList(), r);
    }
  }
  return _mk(Tpl.cap, [c], c, wrong, r);
}

BQ? genCont(int d, SeededRandom r) {
  final pool = countryPool(d).where((i) => kCountries[i].cont >= 0).toList();
  final c = r.pick(pool);
  final cont = kCountries[c].cont;
  final wrong = _pickDistinct(r, 6, _nOpts(d) - 1, (k) => k != cont);
  return _mk(Tpl.cont, [c], cont, wrong, r);
}

BQ? genPinCountry(int d, SeededRandom r) {
  final pool = countryPool(d).where((i) => kCountries[i].onMap).toList();
  final c = r.pick(pool);
  List<int> wrong;
  if (d >= 5 && kCountries[c].cont >= 0) {
    final same = pool.where((i) => i != c && kCountries[i].cont == kCountries[c].cont).toList();
    r.shuffle(same);
    wrong = same.take(_nOpts(d) - 1).toList();
  } else {
    wrong = _pickDistinct(r, pool.length, _nOpts(d) - 1, (k) => pool[k] != c).map((k) => pool[k]).toList();
  }
  if (wrong.length < 2) return null;
  return _mk(Tpl.pinCountry, [c], c, wrong, r);
}

BQ? genTapCountry(int d, SeededRandom r) {
  final pool = countryPool(d).where((i) => kCountries[i].onMap && kCountries[i].area >= 25000).toList();
  return BQ(Tpl.tapCountry, [r.pick(pool)], const [], -1);
}

BQ? genArea(int d, SeededRandom r) {
  final pool = countryPool(d);
  const n = 2;
  final xs = _pickDistinct(r, pool.length, n, (_) => true).map((k) => pool[k]).toList();
  if (xs.length < n) return null;
  xs.sort((a, b) => kCountries[b].area.compareTo(kCountries[a].area));
  final best = xs.first;
  final rest = xs.skip(1).toList();
  return _mk(Tpl.area, const [], best, rest, r);
}

List<int> _provPool(int d) => [for (var i = 0; i < kProvinces.length; i++) i];

BQ? genPlate(int d, SeededRandom r) {
  final p = r.nextInt(kProvinces.length);
  final wrong = _pickDistinct(r, kProvinces.length, _nOpts(d) - 1, (k) => k != p);
  return _mk(Tpl.plate, [p], p, wrong, r);
}

BQ? genPlateRev(int d, SeededRandom r) {
  final p = r.nextInt(kProvinces.length);
  // Zorda yakın plakalar.
  final wrong = d >= 6
      ? _pickDistinct(r, kProvinces.length, _nOpts(d) - 1, (k) => k != p && (k - p).abs() <= 6)
      : _pickDistinct(r, kProvinces.length, _nOpts(d) - 1, (k) => k != p);
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.plateRev, [p], p, wrong, r);
}

BQ? genRegion(int d, SeededRandom r) {
  final p = r.nextInt(kProvinces.length);
  final reg = kProvinces[p].region;
  final wrong = _pickDistinct(r, 7, _nOpts(d) - 1, (k) => k != reg);
  return _mk(Tpl.region, [p], reg, wrong, r);
}

BQ? genPinProv(int d, SeededRandom r) {
  final p = r.nextInt(kProvinces.length);
  final pp = kProvinces[p];
  // Zorda komşu çevredeki iller seçenek olur.
  final near = d >= 5;
  final wrong = _pickDistinct(r, kProvinces.length, _nOpts(d) - 1, (k) {
    if (k == p) return false;
    if (!near) return true;
    final q = kProvinces[k];
    return haversineKm(pp.lat, pp.lon, q.lat, q.lon) < 260;
  });
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.pinProv, [p], p, wrong, r);
}

BQ? genTapProv(int d, SeededRandom r) => BQ(Tpl.tapProv, [r.nextInt(kProvinces.length)], const [], -1);

BQ? genNorth(int d, SeededRandom r) {
  final pool = _provPool(d);
  final gap = 0.4 + (10 - d) * 0.15;
  final a = r.pick(pool);
  final cands = pool.where((b) => (kProvinces[a].lat - kProvinces[b].lat).abs() >= gap).toList();
  if (cands.isEmpty) return null;
  final b = r.pick(cands);
  final hi = kProvinces[a].lat > kProvinces[b].lat ? a : b;
  return _mk(Tpl.north, const [], hi, [hi == a ? b : a], r);
}

BQ? genEast(int d, SeededRandom r) {
  final pool = _provPool(d);
  final gap = 0.6 + (10 - d) * 0.25;
  final a = r.pick(pool);
  final cands = pool.where((b) => (kProvinces[a].lon - kProvinces[b].lon).abs() >= gap).toList();
  if (cands.isEmpty) return null;
  final b = r.pick(cands);
  final hi = kProvinces[a].lon > kProvinces[b].lon ? a : b;
  return _mk(Tpl.east, const [], hi, [hi == a ? b : a], r);
}

int _zMax(int d) => math.min<int>(103, 20 + d * 9);

BQ? genZ2S(int d, SeededRandom r) {
  final z = r.nextInt(_zMax(d));
  final wrong = _pickDistinct(r, _zMax(d), _nOpts(d) - 1, (k) => k != z && (d < 6 || (k - z).abs() <= 8));
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.z2s, [z], z, wrong, r);
}

BQ? genS2Z(int d, SeededRandom r) {
  final z = r.nextInt(_zMax(d));
  final wrong = _pickDistinct(r, _zMax(d), _nOpts(d) - 1, (k) => k != z && (k - z).abs() <= 10 - d ~/ 2 + 2);
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.s2z, [z], z, wrong, r);
}

BQ? genCat(int d, SeededRandom r) {
  final c = r.nextInt(5);
  final lim = math.max<int>(_zMax(d), 56);
  final good = [for (var i = 0; i < lim; i++) if (kElements[i].cat == c) i];
  final bad = [for (var i = 0; i < lim; i++) if (kElements[i].cat != c) i];
  if (good.isEmpty) return null;
  final ans = r.pick(good);
  final wrong = _pickDistinct(r, bad.length, _nOpts(d) - 1, (_) => true).map((k) => bad[k]).toList();
  return _mk(Tpl.cat, [c], ans, wrong, r);
}

BQ? _genState(int t, int want, int d, SeededRandom r) {
  final lim = math.max<int>(_zMax(d), 40);
  final good = [for (var i = 0; i < lim; i++) if (kElements[i].state == want) i];
  final solid = [for (var i = 0; i < lim; i++) if (kElements[i].state == 0) i];
  if (good.isEmpty) return null;
  final ans = r.pick(good);
  final wrong = _pickDistinct(r, solid.length, _nOpts(d) - 1, (_) => true).map((k) => solid[k]).toList();
  return _mk(t, const [], ans, wrong, r);
}

BQ? genLiquid(int d, SeededRandom r) => _genState(Tpl.liquid, 1, d, r);
BQ? genGas(int d, SeededRandom r) => _genState(Tpl.gas, 2, d, r);

BQ? genPeriod(int d, SeededRandom r) {
  final z = r.nextInt(_zMax(d));
  final p = kElements[z].period;
  final wrong = _pickDistinct(r, 8, _nOpts(d) - 1, (k) => k >= 1 && k != p && (k - p).abs() <= 3);
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.period, [z], p, wrong, r);
}

BQ? genMass(int d, SeededRandom r) {
  final lim = math.min<int>(92, _zMax(d));
  final a = r.nextInt(lim), b = r.nextInt(lim);
  final ma = kElements[a].mass, mb = kElements[b].mass;
  final hi = ma >= mb ? a : b, lo = hi == a ? b : a;
  if (kElements[hi].mass < kElements[lo].mass * 1.1) return null;
  return _mk(Tpl.mass, const [], hi, [lo], r);
}

BQ? genPlanetN(int d, SeededRandom r) {
  final n = r.nextInt(8);
  final wrong = _pickDistinct(r, 8, _nOpts(d) - 1, (k) => k != n);
  return _mk(Tpl.planetN, [n], n, wrong, r);
}

BQ? genPlanetBig(int d, SeededRandom r) {
  final a = r.nextInt(8), b = r.nextInt(8);
  final hi = kPlanetKm[a] >= kPlanetKm[b] ? a : b, lo = hi == a ? b : a;
  if (kPlanetKm[hi] < kPlanetKm[lo] * 1.1) return null;
  return _mk(Tpl.planetBig, const [], hi, [lo], r);
}

BQ? genRocky(int d, SeededRandom r) {
  final ans = r.nextInt(4);
  final wrong = _pickDistinct(r, 8, _nOpts(d) - 1, (k) => k >= 4);
  return _mk(Tpl.rocky, const [], ans, wrong, r);
}

BQ? genUnit(int d, SeededRandom r) {
  final lim = math.min<int>(kUnits.length, 10 + d * 2);
  final u = r.nextInt(lim);
  final n = _nOpts(d);
  final wrong = [1, 2, 3]..length = n - 1;
  return _mk(Tpl.unit, [u], 0, wrong, r);
}

List<int> get _animalIdx => [for (var i = 0; i < kAnimals.length; i++) i];

BQ? genCls(int d, SeededRandom r) {
  final c = r.pick(d <= 3 ? const [0, 1, 4, 5] : const [0, 1, 2, 3, 4, 5, 6]);
  final good = _animalIdx.where((i) => kAnimals[i].cls == c).toList();
  final bad = _animalIdx.where((i) => kAnimals[i].cls != c).toList();
  if (good.isEmpty) return null;
  final ans = r.pick(good);
  final wrong = _pickDistinct(r, bad.length, _nOpts(d) - 1, (_) => true).map((k) => bad[k]).toList();
  return _mk(Tpl.cls, [c], ans, wrong, r);
}

BQ? genNotCls(int d, SeededRandom r) {
  final c = r.pick(const [0, 1, 5]);
  final good = _animalIdx.where((i) => kAnimals[i].cls == c).toList();
  final bad = _animalIdx.where((i) => kAnimals[i].cls != c).toList();
  final ans = r.pick(bad);
  final wrong = _pickDistinct(r, good.length, _nOpts(d) - 1, (_) => true).map((k) => good[k]).toList();
  return _mk(Tpl.notCls, [c], ans, wrong, r);
}

BQ? _genFlag(int t, int Function(Animal) f, int d, SeededRandom r) {
  final good = _animalIdx.where((i) => f(kAnimals[i]) == 1).toList();
  final bad = _animalIdx.where((i) => f(kAnimals[i]) == 0).toList();
  final ans = r.pick(good);
  final wrong = _pickDistinct(r, bad.length, _nOpts(d) - 1, (_) => true).map((k) => bad[k]).toList();
  return _mk(t, const [], ans, wrong, r);
}

BQ? genEggs(int d, SeededRandom r) => _genFlag(Tpl.eggs, (a) => a.eggs, d, r);
BQ? genSea(int d, SeededRandom r) => _genFlag(Tpl.sea, (a) => a.sea, d, r);
BQ? genHerb(int d, SeededRandom r) => _genFlag(Tpl.herb, (a) => a.diet == 0 ? 1 : (a.diet == 1 ? 0 : -1), d, r);
BQ? genCarn(int d, SeededRandom r) => _genFlag(Tpl.carn, (a) => a.diet == 1 ? 1 : (a.diet == 0 ? 0 : -1), d, r);

BQ? _genSize(int t, int n, SeededRandom r) {
  final pool = _animalIdx.where((i) => kAnimals[i].kg > 0).toList();
  final xs = _pickDistinct(r, pool.length, n, (_) => true).map((k) => pool[k]).toList()
    ..sort((a, b) => kAnimals[b].kg.compareTo(kAnimals[a].kg));
  if (xs.length < n || kAnimals[xs[0]].kg < kAnimals[xs[1]].kg * 3) return null;
  return _mk(t, const [], xs[0], xs.skip(1).toList(), r);
}

BQ? genBiggest(int d, SeededRandom r) => _genSize(Tpl.biggest, d <= 3 ? 3 : 4, r);
BQ? genBigger(int d, SeededRandom r) => _genSize(Tpl.bigger, 2, r);

BQ? genLegs(int d, SeededRandom r) {
  final pool = _animalIdx.where((i) => kAnimals[i].legs >= 0).toList();
  final a = r.pick(pool);
  final n = kAnimals[a].legs;
  final wrong = [for (final x in const [0, 2, 4, 6, 8]) if (x != n) x];
  r.shuffle(wrong);
  return _mk(Tpl.legs, [a], n, wrong.take(_nOpts(d) - 1).toList(), r);
}

/// Olay havuzu: kolayda iyi bilinen ve yakın tarihli olaylar.
List<int> _eventPool(int d) => [
      for (var i = 0; i < kEvents.length; i++)
        if (d >= 5 || kEvents[i].year >= 1750) i
    ];

int _gap(int d) => math.max<int>(3, 110 - d * 11);

BQ? genYear(int d, SeededRandom r) {
  final pool = _eventPool(d);
  final e = r.pick(pool);
  final y = kEvents[e].year;
  final step = math.max<int>(1, 22 - d * 2);
  final wrong = <int>{};
  for (var g = 0; g < 50 && wrong.length < _nOpts(d) - 1; g++) {
    final off = (r.nextInt(4) + 1) * step * (r.chance(0.5) ? 1 : -1);
    final v = y + off;
    if (v != y && v <= 2025) wrong.add(v);
  }
  if (wrong.length < _nOpts(d) - 1) return null;
  return _mk(Tpl.year, [e], y, wrong.toList(), r);
}

BQ? _genPair(int t, int d, SeededRandom r) {
  final pool = _eventPool(d);
  final a = r.pick(pool);
  final cands = pool.where((b) => (kEvents[a].year - kEvents[b].year).abs() >= _gap(d)).toList();
  if (cands.isEmpty) return null;
  final b = r.pick(cands);
  final early = kEvents[a].year < kEvents[b].year ? a : b;
  final late = early == a ? b : a;
  return t == Tpl.first ? _mk(t, const [], early, [late], r) : _mk(t, const [], late, [early], r);
}

BQ? genFirst(int d, SeededRandom r) => _genPair(Tpl.first, d, r);
BQ? genLater(int d, SeededRandom r) => _genPair(Tpl.later, d, r);

BQ? genOrder(int d, SeededRandom r) {
  final pool = _eventPool(d);
  final n = d <= 3 ? 3 : (d <= 7 ? 4 : 5);
  final g = math.max<int>(2, _gap(d) ~/ 2);
  final xs = <int>[];
  for (var t = 0; t < 300 && xs.length < n; t++) {
    final c = r.pick(pool);
    if (xs.every((x) => (kEvents[x].year - kEvents[c].year).abs() >= g)) xs.add(c);
  }
  if (xs.length < n) return null;
  r.shuffle(xs);
  return BQ(Tpl.order, const [], xs, -1);
}

BQ? genSpan(int d, SeededRandom r) {
  final pool = _eventPool(d);
  final e = r.pick(pool);
  final y = kEvents[e].year;
  final len = d <= 4 ? 100 : (d <= 7 ? 50 : 25);
  final s0 = ((y - 1) ~/ len) * len + 1;
  final n = _nOpts(d);
  final k = r.nextInt(n);
  final starts = [for (var i = 0; i < n; i++) s0 + (i - k) * len];
  return BQ(Tpl.span, [e, len], starts, k);
}

/// Bütün üreticiler şablon sırasıyla.
final List<QGen> kGens = [
  genCap, genCont, genPinCountry, genTapCountry, genArea, //
  genPlate, genPlateRev, genRegion, genPinProv, genTapProv, genNorth, genEast, //
  genZ2S, genS2Z, genCat, genLiquid, genGas, genPeriod, genMass, //
  genPlanetN, genPlanetBig, genRocky, genUnit, //
  genCls, genNotCls, genEggs, genSea, genBiggest, genLegs, genHerb, genCarn, //
  genYear, genFirst, genLater, genOrder, genSpan, genBigger, //
  genEst, genSortP, genTf, genDish, genDishRev,
];

/// Aynı bölümde aynı konunun tekrar sorulmaması için anahtar.
String subjectKey(BQ q) {
  if (q.t >= Tpl.est) return subjectKeyExt(q);
  if (q.a.isNotEmpty) return '${q.t ~/ 5}:${q.a[0]}';
  final xs = [...q.o]..sort();
  return '${q.t}:${xs.join(',')}';
}
