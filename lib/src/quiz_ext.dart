import 'dart:math' as math;

import 'package:studio_core/core/rng.dart';

import 'data/animals.dart';
import 'data/countries.dart';
import 'data/elements.dart';
import 'data/events.dart';
import 'data/extra.dart';
import 'data/provinces.dart';
import 'quiz.dart';
import 'texts.dart';

// Ek şablonlar: Tahmin Ustası (est), Sırala Bakalım (sortP),
// Doğru mu Uydurma mı (tf) ve Dünya Mutfağı (dish, dishRev).

String _tren(String lang, String tr, String en) => lang == 'tr' ? tr : en;

String _plateCode(int prov) => kProvinces[prov].plate.toString().padLeft(2, '0');

String _kgText(double kg) {
  if (kg >= 1000) return '${groupDigits((kg / 1000).round())} t';
  if (kg >= 1) return '${kg.round()} kg';
  if (kg >= 0.001) return '${(kg * 1000).round()} g';
  return '< 1 g';
}

String _elemLabel(int z, String lang) {
  final e = kElements[z];
  return lang == 'tr' || lang == 'en' ? '${elemName(e, lang)} (${e.sym})' : e.sym;
}

String _animalLabel(int i, String lang) {
  final a = kAnimals[i];
  final n = animalName(a, lang);
  return n.isEmpty ? a.emoji : '${a.emoji} $n';
}

String _mountainName(int i, String lang) => _tren(lang, kMountains[i].tr, kMountains[i].en);

String dishName(int i, String lang) => _tren(lang, kDishes[i].tr, kDishes[i].en);

String dishLabel(int i, String lang) => '${kDishes[i].emoji} ${dishName(i, lang)}';

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  var t = s;
  while (t.endsWith('0')) {
    t = t.substring(0, t.length - 1);
  }
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  return t;
}

/// Sayıyı kısa ve okunur yazar (büyüklerde gruplu tam sayı).
String numText(double v) {
  final a = v.abs();
  if (a >= 100) return groupDigits(v.round());
  if (a >= 10) return _trimZeros(v.toStringAsFixed(1));
  return _trimZeros(v.toStringAsFixed(2));
}

// ------------------------------------------------------------------ Tahmin

/// Tahmin sorusunun kaynakları (BQ.a[0]).
class EstSrc {
  static const area = 0, planetKm = 1, planetDist = 2, atomic = 3, year = 4, mountain = 5, animal = 6, num = 7;
  static const count = 8;
}

/// Tahmin sorusunun aralığı ve doğru değeri.
class EstSpec {
  final double value;
  final double lo;
  final double hi;
  final bool log;
  final String unit;

  /// Kabul edilen sapma: logaritmik sorularda |ln(tahmin/değer)|, yıllarda yıl farkı.
  final double tol;
  const EstSpec(this.value, this.lo, this.hi, this.log, this.unit, this.tol);

  double at(double t) {
    final x = _clampD(t, 0, 1);
    return log ? lo * math.pow(hi / lo, x).toDouble() : lo + (hi - lo) * x;
  }

  double posOf(double v) => log ? math.log(v / lo) / math.log(hi / lo) : (v - lo) / (hi - lo);

  /// Ekranda gösterilen (yuvarlanmış) tahmin.
  double round(double v) => log ? _roundSig(v, 3) : v.roundToDouble();

  double error(double guess) => log ? (math.log(guess / value)).abs() : (guess - value).abs();

  String format(double v) => log ? numText(v) : '${v.round()}';
}

double _clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

double _roundSig(double v, int s) {
  if (v <= 0) return v;
  final e = (math.log(v) / math.ln10).floor() - s + 1;
  final m = math.pow(10, e).toDouble();
  return (v / m).round() * m;
}

bool _estIdxOk(int src, int i) => switch (src) {
      EstSrc.area => i >= 0 && i < kCountries.length,
      EstSrc.planetKm || EstSrc.planetDist => i >= 0 && i < 8,
      EstSrc.atomic => i >= 0 && i < kElements.length,
      EstSrc.year => i >= 0 && i < kEvents.length,
      EstSrc.mountain => i >= 0 && i < kMountains.length,
      EstSrc.animal => i >= 0 && i < kAnimals.length && kAnimals[i].kg > 0,
      EstSrc.num => i >= 0 && i < kNumFacts.length,
      _ => false,
    };

double estValue(int src, int i) => switch (src) {
      EstSrc.area => kCountries[i].area.toDouble(),
      EstSrc.planetKm => kPlanetKm[i].toDouble(),
      EstSrc.planetDist => kPlanetDist[i] * 1000000,
      EstSrc.atomic => (i + 1).toDouble(),
      EstSrc.year => kEvents[i].year.toDouble(),
      EstSrc.mountain => kMountains[i].m.toDouble(),
      EstSrc.animal => kAnimals[i].kg,
      _ => kNumFacts[i].value,
    };

String estUnit(int src, int i) => switch (src) {
      EstSrc.area => 'km²',
      EstSrc.planetKm || EstSrc.planetDist => 'km',
      EstSrc.mountain => 'm',
      EstSrc.animal => 'kg',
      EstSrc.num => kNumFacts[i].unit,
      _ => '',
    };

EstSpec estSpec(BQ q) {
  final src = q.a[0], i = q.a[1];
  final p = q.a[2] / 1000.0;
  final d = q.a[3];
  final v = estValue(src, i);
  if (src == EstSrc.year) {
    final w = 120.0 + d * 40;
    var lo = v - p * w;
    var hi = lo + w;
    if (hi > 2025) {
      hi = 2025;
      lo = hi - w;
    }
    return EstSpec(v, lo.roundToDouble(), hi.roundToDouble(), false, '', 45.0 - d * 4);
  }
  final f = math.pow(10, 0.8 + d * 0.17).toDouble();
  final lo = v / math.pow(f, p).toDouble();
  final hi = v * math.pow(f, 1 - p).toDouble();
  return EstSpec(v, lo, hi, true, estUnit(src, i), math.log(1.6 - d * 0.045));
}

String _estPrompt(BQ q, String lang) {
  final i = q.a[1];
  return switch (q.a[0]) {
    EstSrc.area => bt(lang, 'qEst0', {'c': countryName(i, lang)}),
    EstSrc.planetKm => bt(lang, 'qEst1', {'p': planetName(i, lang)}),
    EstSrc.planetDist => bt(lang, 'qEst2', {'p': planetName(i, lang)}),
    EstSrc.atomic => bt(lang, 'qEst3', {'e': _elemLabel(i, lang)}),
    EstSrc.year => bt(lang, 'qEst4', {'e': eventText(kEvents[i], lang)}),
    EstSrc.mountain => bt(lang, 'qEst5', {'m': _mountainName(i, lang)}),
    EstSrc.animal => bt(lang, 'qEst6', {'a': _animalLabel(i, lang)}),
    _ => _tren(lang, kNumFacts[i].tr, kNumFacts[i].en),
  };
}

String _estExplain(BQ q, String lang) {
  final s = estSpec(q);
  final i = q.a[1];
  final value = q.a[0] == EstSrc.animal
      ? _kgText(s.value)
      : (q.a[0] == EstSrc.year ? '${s.value.round()}' : '${numText(s.value)}${s.unit.isEmpty ? '' : ' ${s.unit}'}');
  final what = switch (q.a[0]) {
    EstSrc.area => countryName(i, lang),
    EstSrc.planetKm || EstSrc.planetDist => planetName(i, lang),
    EstSrc.atomic => _elemLabel(i, lang),
    EstSrc.year => eventText(kEvents[i], lang),
    EstSrc.mountain => _mountainName(i, lang),
    EstSrc.animal => _animalLabel(i, lang),
    _ => '',
  };
  return what.isEmpty ? value : '$what · $value';
}

BQ? genEst(int d, SeededRandom r) {
  final src = r.nextInt(EstSrc.count);
  int idx;
  switch (src) {
    case EstSrc.area:
      idx = r.pick(countryPool(d));
    case EstSrc.planetKm:
    case EstSrc.planetDist:
      idx = r.nextInt(8);
    case EstSrc.atomic:
      idx = r.nextInt(math.min<int>(kElements.length, 20 + d * 9));
    case EstSrc.year:
      final evPool = [for (var i = 0; i < kEvents.length; i++) if (d >= 5 || kEvents[i].year >= 1750) i];
      idx = r.pick(evPool);
    case EstSrc.mountain:
      idx = r.nextInt(kMountains.length);
    case EstSrc.animal:
      final anPool = [for (var i = 0; i < kAnimals.length; i++) if (kAnimals[i].kg > 0) i];
      idx = r.pick(anPool);
    default:
      idx = r.nextInt(kNumFacts.length);
  }
  return BQ(Tpl.est, [src, idx, 150 + r.nextInt(701), d], const [], -1);
}

bool _checkEst(BQ q) {
  if (q.a.length != 4 || q.o.isNotEmpty) return false;
  final src = q.a[0], i = q.a[1], p = q.a[2], d = q.a[3];
  if (src < 0 || src >= EstSrc.count || !_estIdxOk(src, i)) return false;
  if (p < 150 || p > 850 || d < 1 || d > 10) return false;
  final s = estSpec(q);
  return s.value > 0 && s.lo < s.value && s.value <= s.hi && s.tol > 0;
}

// ------------------------------------------------------------------ Sırala

/// Sıralama ölçütleri (BQ.a[0]).
class SortProp {
  static const area = 0, planetKm = 1, planetDist = 2, atomic = 3, animal = 4, mountain = 5, north = 6;
  static const count = 7;
}

/// Doğru sırada küçükten büyüğe giden anahtar.
double sortKey(int prop, int i) => switch (prop) {
      SortProp.area => -kCountries[i].area.toDouble(),
      SortProp.planetKm => -kPlanetKm[i].toDouble(),
      SortProp.planetDist => kPlanetDist[i],
      SortProp.atomic => i.toDouble(),
      SortProp.animal => -kAnimals[i].kg,
      SortProp.mountain => -kMountains[i].m.toDouble(),
      _ => -kCountries[i].lat,
    };

bool _sortIdxOk(int prop, int i) => switch (prop) {
      SortProp.area || SortProp.north => i >= 0 && i < kCountries.length,
      SortProp.planetKm || SortProp.planetDist => i >= 0 && i < 8,
      SortProp.atomic => i >= 0 && i < kElements.length,
      SortProp.animal => i >= 0 && i < kAnimals.length && kAnimals[i].kg > 0,
      SortProp.mountain => i >= 0 && i < kMountains.length,
      _ => false,
    };

/// İki öğe, sırası tartışmasız olacak kadar farklı mı?
bool _farApart(int prop, int a, int b, int d) {
  switch (prop) {
    case SortProp.area:
      return _ratio(kCountries[a].area.toDouble(), kCountries[b].area.toDouble()) >= 1.2;
    case SortProp.planetKm:
      return _ratio(kPlanetKm[a].toDouble(), kPlanetKm[b].toDouble()) >= 1.08;
    case SortProp.planetDist:
      return a != b;
    case SortProp.atomic:
      return (a - b).abs() >= math.max<int>(2, 12 - d);
    case SortProp.animal:
      return _ratio(kAnimals[a].kg, kAnimals[b].kg) >= 1.6;
    case SortProp.mountain:
      return _ratio(kMountains[a].m.toDouble(), kMountains[b].m.toDouble()) >= 1.04;
    default:
      return (kCountries[a].lat - kCountries[b].lat).abs() >= math.max<double>(2.0, 9.0 - d * 0.6);
  }
}

double _ratio(double x, double y) {
  final lo = math.min<double>(x, y), hi = math.max<double>(x, y);
  return lo <= 0 ? 0 : hi / lo;
}

String sortLabel(int prop, int i, String lang) => switch (prop) {
      SortProp.area || SortProp.north => countryName(i, lang),
      SortProp.planetKm || SortProp.planetDist => planetName(i, lang),
      SortProp.atomic => _elemLabel(i, lang),
      SortProp.animal => _animalLabel(i, lang),
      _ => _mountainName(i, lang),
    };

String sortValue(int prop, int i) => switch (prop) {
      SortProp.area => '${groupDigits(kCountries[i].area)} km²',
      SortProp.planetKm => '${groupDigits(kPlanetKm[i])} km',
      SortProp.planetDist => '${groupDigits((kPlanetDist[i] * 1000000).round())} km',
      SortProp.atomic => '${i + 1}',
      SortProp.animal => _kgText(kAnimals[i].kg),
      SortProp.mountain => '${groupDigits(kMountains[i].m)} m',
      _ => '${kCountries[i].lat.toStringAsFixed(1)}°',
    };

/// Sıralama sorusunda [i]. seçeneğin anahtarı (küçükten büyüğe doğru sıra).
double orderKey(BQ q, int i) =>
    q.t == Tpl.order ? kEvents[q.o[i]].year.toDouble() : sortKey(q.a[0], q.o[i]);

/// Sıralama sorusunda [i]. seçeneğin değeri (yanıttan sonra gösterilir).
String orderValue(BQ q, int i) => q.t == Tpl.order ? '${kEvents[q.o[i]].year}' : sortValue(q.a[0], q.o[i]);

List<int> _sortPool(int prop, int d) {
  switch (prop) {
    case SortProp.area:
      return countryPool(d);
    case SortProp.north:
      return countryPool(d).where((i) => kCountries[i].onMap).toList();
    case SortProp.planetKm:
    case SortProp.planetDist:
      return [for (var i = 0; i < 8; i++) i];
    case SortProp.atomic:
      return [for (var i = 0; i < math.min<int>(kElements.length, 30 + d * 9); i++) i];
    case SortProp.animal:
      return [for (var i = 0; i < kAnimals.length; i++) if (kAnimals[i].kg > 0) i];
    default:
      return [for (var i = 0; i < kMountains.length; i++) i];
  }
}

BQ? genSortP(int d, SeededRandom r) {
  final prop = r.nextInt(SortProp.count);
  final n = d <= 3 ? 3 : (d <= 7 ? 4 : 5);
  final pool = _sortPool(prop, d);
  final xs = <int>[];
  for (var t = 0; t < 300 && xs.length < n; t++) {
    final c = r.pick(pool);
    if (xs.contains(c)) continue;
    if (xs.every((x) => _farApart(prop, x, c, d))) xs.add(c);
  }
  if (xs.length < n) return null;
  r.shuffle(xs);
  return BQ(Tpl.sortP, [prop], xs, -1);
}

bool _checkSort(BQ q) {
  if (q.a.length != 1 || q.ans != -1) return false;
  final prop = q.a[0];
  if (prop < 0 || prop >= SortProp.count || q.o.length < 3 || q.o.length > 6) return false;
  if (q.o.toSet().length != q.o.length || !q.o.every((i) => _sortIdxOk(prop, i))) return false;
  for (var a = 0; a < q.o.length; a++) {
    for (var b = a + 1; b < q.o.length; b++) {
      if (!_farApart(prop, q.o[a], q.o[b], 10)) return false;
    }
  }
  return true;
}

// ------------------------------------------------------------------ Doğru mu Uydurma mı

/// Önerme kaynakları (BQ.a[0]).
class TfSrc {
  static const cap = 0, cont = 1, elem = 2, planet = 3, animal = 4, event = 5, plate = 6, fact = 7;
  static const count = 8;
}

/// Önerme doğru mu?
bool tfTruth(List<int> a) {
  final x = a[1], y = a[2];
  return switch (a[0]) {
    TfSrc.cap || TfSrc.elem || TfSrc.planet || TfSrc.plate => x == y,
    TfSrc.cont => kCountries[x].cont == y,
    TfSrc.animal => kAnimals[x].cls == y,
    TfSrc.event => kEvents[x].year == y,
    _ => kFacts[x].truth,
  };
}

bool _tfValid(List<int> a) {
  if (a.length != 3) return false;
  final x = a[1], y = a[2];
  switch (a[0]) {
    case TfSrc.cap:
      if (x < 0 || x >= kCountries.length || y < 0 || y >= kCountries.length) return false;
      if (!kCountries[x].capOk || !kCountries[y].capOk) return false;
      return x == y || kCapitals[x][1] != kCapitals[y][1];
    case TfSrc.cont:
      return x >= 0 && x < kCountries.length && kCountries[x].cont >= 0 && y >= 0 && y < kContinents.length;
    case TfSrc.elem:
      return x >= 0 && x < kElements.length && y >= 0 && y < kElements.length;
    case TfSrc.planet:
      return x >= 0 && x < 8 && y >= 0 && y < 8;
    case TfSrc.animal:
      return x >= 0 && x < kAnimals.length && kAnimals[x].cls >= 0 && y >= 0 && y <= 6;
    case TfSrc.event:
      return x >= 0 && x < kEvents.length && y > 0 && y <= 2025;
    case TfSrc.plate:
      return x >= 0 && x < kProvinces.length && y >= 0 && y < kProvinces.length;
    case TfSrc.fact:
      return x >= 0 && x < kFacts.length && y == 0;
  }
  return false;
}

String tfStatement(List<int> a, String lang) {
  final x = a[1], y = a[2];
  return switch (a[0]) {
    TfSrc.cap => bt(lang, 'tf0', {'c': countryName(x, lang), 'x': capitalAny(y, lang)}),
    TfSrc.cont => bt(lang, 'tf1', {'c': countryName(x, lang), 'k': continentName(y, lang)}),
    TfSrc.elem => bt(lang, 'tf2', {'n': x + 1, 's': kElements[y].sym}),
    TfSrc.planet => bt(lang, 'tf3', {'p': planetName(x, lang), 'n': y + 1}),
    TfSrc.animal => bt(lang, 'tf4', {'a': _animalLabel(x, lang), 'cls': clsName(y, lang)}),
    TfSrc.event => bt(lang, 'tf5', {'e': eventText(kEvents[x], lang), 'y': y}),
    TfSrc.plate => bt(lang, 'tf6', {'x': kProvinces[x].name, 'n': _plateCode(y)}),
    _ => _tren(lang, kFacts[x].tr, kFacts[x].en),
  };
}

String _tfExplain(List<int> a, String lang) {
  final x = a[1];
  switch (a[0]) {
    case TfSrc.cap:
      return '${countryName(x, lang)} · ${capitalAny(x, lang)}';
    case TfSrc.cont:
      return '${countryName(x, lang)} · ${continentName(kCountries[x].cont, lang)}';
    case TfSrc.elem:
      return '${x + 1} · ${_elemLabel(x, lang)}';
    case TfSrc.planet:
      return [for (var p = 0; p < 8; p++) '${p + 1}. ${planetName(p, lang)}'].join('  ');
    case TfSrc.animal:
      return '${_animalLabel(x, lang)}: ${clsName(kAnimals[x].cls, lang)}';
    case TfSrc.event:
      return '${kEvents[x].year} · ${eventText(kEvents[x], lang)}';
    case TfSrc.plate:
      final p = kProvinces[x];
      return '${_plateCode(x)} · ${p.name} · ${regionName(p.region, lang)}';
    default:
      return _tren(lang, kFacts[x].exTr, kFacts[x].exEn);
  }
}

BQ? genTf(int d, SeededRandom r) {
  const weights = [3, 1, 1, 1, 1, 1, 1, 6];
  final src = r.weighted(weights);
  final truth = r.chance(0.5);
  int x, y;
  switch (src) {
    case TfSrc.cap:
      final capPool = countryPool(d).where((i) => kCountries[i].capOk).toList();
      x = r.pick(capPool);
      if (truth) {
        y = x;
      } else {
        final cont = kCountries[x].cont;
        final same = capPool.where((i) => i != x && kCapitals[i][1] != kCapitals[x][1] && (cont < 0 || kCountries[i].cont == cont)).toList();
        if (same.isEmpty) return null;
        y = r.pick(same);
      }
    case TfSrc.cont:
      final contPool = countryPool(d).where((i) => kCountries[i].cont >= 0).toList();
      x = r.pick(contPool);
      final cc = kCountries[x].cont;
      y = truth ? cc : (cc + 1 + r.nextInt(5)) % 6;
    case TfSrc.elem:
      x = r.nextInt(math.min<int>(kElements.length, 20 + d * 9));
      if (truth) {
        y = x;
      } else {
        final off = (1 + r.nextInt(3)) * (r.chance(0.5) ? 1 : -1);
        y = x + off;
        if (y < 0 || y >= kElements.length) return null;
      }
    case TfSrc.planet:
      x = r.nextInt(8);
      y = truth ? x : (x + 1 + r.nextInt(7)) % 8;
    case TfSrc.animal:
      final anPool = [for (var i = 0; i < kAnimals.length; i++) if (kAnimals[i].cls >= 0) i];
      x = r.pick(anPool);
      final ac = kAnimals[x].cls;
      y = truth ? ac : (ac + 1 + r.nextInt(6)) % 7;
    case TfSrc.event:
      final evPool = [for (var i = 0; i < kEvents.length; i++) if (d >= 5 || kEvents[i].year >= 1750) i];
      x = r.pick(evPool);
      final yr = kEvents[x].year;
      if (truth) {
        y = yr;
      } else {
        final step = math.max<int>(1, 22 - d * 2);
        y = yr + (1 + r.nextInt(4)) * step * (r.chance(0.5) ? 1 : -1);
        if (y > 2025 || y <= 0) y = yr - step * 2;
      }
    case TfSrc.plate:
      x = r.nextInt(kProvinces.length);
      if (truth) {
        y = x;
      } else {
        y = x + (1 + r.nextInt(5)) * (r.chance(0.5) ? 1 : -1);
        if (y < 0 || y >= kProvinces.length) return null;
      }
    default:
      final factPool = [for (var i = 0; i < kFacts.length; i++) if (kFacts[i].truth == truth) i];
      x = r.pick(factPool);
      y = 0;
  }
  final a = [src, x, y];
  if (!_tfValid(a)) return null;
  return BQ(Tpl.tf, a, const [0, 1], tfTruth(a) ? 0 : 1);
}

bool _checkTf(BQ q) =>
    _tfValid(q.a) && q.o.length == 2 && q.o[0] == 0 && q.o[1] == 1 && q.ans == (tfTruth(q.a) ? 0 : 1);

// ------------------------------------------------------------------ Dünya Mutfağı

const Set<String> _famousCuisines = {'IT', 'JP', 'MX', 'CN', 'FR', 'TR', 'US', 'IN', 'GB', 'ES', 'KR', 'TH', 'DE', 'GR'};

List<int> _dishPool(int d) => [
      for (var i = 0; i < kDishes.length; i++)
        if (d >= 4 || _famousCuisines.contains(kCountries[kDishes[i].country].iso)) i
    ];

/// Yemeği olan ülkeler.
final List<int> kDishCountries = ({for (final x in kDishes) x.country}.toList()..sort());

BQ? genDish(int d, SeededRandom r) {
  final dish = r.pick(_dishPool(d));
  final c = kDishes[dish].country;
  final n = d <= 2 ? 3 : 4;
  final cont = kCountries[c].cont;
  final cands = kDishCountries.where((k) => k != c).toList();
  final same = cands.where((k) => cont >= 0 && kCountries[k].cont == cont).toList();
  r.shuffle(cands);
  r.shuffle(same);
  final wrong = <int>[];
  if (d >= 6) wrong.addAll(same.take(n - 1));
  for (final k in cands) {
    if (wrong.length >= n - 1) break;
    if (!wrong.contains(k)) wrong.add(k);
  }
  if (wrong.length < n - 1) return null;
  final opts = [c, ...wrong];
  r.shuffle(opts);
  return BQ(Tpl.dish, [dish], opts, opts.indexOf(c));
}

BQ? genDishRev(int d, SeededRandom r) {
  final pool = _dishPool(d);
  final target = r.pick(pool);
  final c = kDishes[target].country;
  final n = d <= 2 ? 3 : 4;
  final others = pool.where((i) => kDishes[i].country != c).toList();
  final wrong = <int>[];
  final used = <int>{c};
  for (var t = 0; t < 200 && wrong.length < n - 1; t++) {
    final k = r.pick(others);
    if (used.add(kDishes[k].country)) wrong.add(k);
  }
  if (wrong.length < n - 1) return null;
  final opts = [target, ...wrong];
  r.shuffle(opts);
  return BQ(Tpl.dishRev, [c], opts, opts.indexOf(target));
}

bool _checkDish(BQ q) {
  if (q.a.length != 1) return false;
  if (q.t == Tpl.dish) {
    final dish = q.a[0];
    if (dish < 0 || dish >= kDishes.length) return false;
    return q.o[q.ans] == kDishes[dish].country && q.o.every((k) => k >= 0 && k < kCountries.length);
  }
  final c = q.a[0];
  if (!q.o.every((i) => i >= 0 && i < kDishes.length)) return false;
  final hits = q.o.where((i) => kDishes[i].country == c).length;
  return hits == 1 && kDishes[q.o[q.ans]].country == c && {for (final i in q.o) kDishes[i].country}.length == q.o.length;
}

// ------------------------------------------------------------------ ortak giriş noktaları

bool checkExt(BQ q) => switch (q.t) {
      Tpl.est => _checkEst(q),
      Tpl.sortP => _checkSort(q),
      Tpl.tf => _checkTf(q),
      Tpl.dish || Tpl.dishRev => _checkDish(q),
      _ => false,
    };

QText renderExt(BQ q, String lang) => switch (q.t) {
      Tpl.est => QText(_estPrompt(q, lang), const []),
      Tpl.sortP => QText(bt(lang, 'qSort${q.a[0]}'), [for (final i in q.o) sortLabel(q.a[0], i, lang)]),
      Tpl.tf => QText(tfStatement(q.a, lang), [bt(lang, 'tfTrue'), bt(lang, 'tfFake')]),
      Tpl.dish => QText(bt(lang, 'qDish'), [for (final c in q.o) countryName(c, lang)]),
      Tpl.dishRev => QText(bt(lang, 'qDishRev', {'c': countryName(q.a[0], lang)}), [for (final i in q.o) dishLabel(i, lang)]),
      _ => const QText('?', []),
    };

String explainExt(BQ q, String lang) {
  switch (q.t) {
    case Tpl.est:
      return _estExplain(q, lang);
    case Tpl.sortP:
      final xs = [...q.o]..sort((a, b) => sortKey(q.a[0], a).compareTo(sortKey(q.a[0], b)));
      return [for (final i in xs) '${sortLabel(q.a[0], i, lang)}: ${sortValue(q.a[0], i)}'].join('\n');
    case Tpl.tf:
      return _tfExplain(q.a, lang);
    case Tpl.dish:
      return '${dishLabel(q.a[0], lang)} · ${countryName(kDishes[q.a[0]].country, lang)}';
    case Tpl.dishRev:
      return [for (final i in q.o) '${dishLabel(i, lang)} · ${countryName(kDishes[i].country, lang)}'].join('\n');
  }
  return '';
}

String subjectKeyExt(BQ q) => switch (q.t) {
      Tpl.sortP => '${q.t}:${q.a[0]}:${([...q.o]..sort()).join(',')}',
      Tpl.dish => 'dish:${q.a[0]}',
      Tpl.dishRev => 'dishRev:${q.a[0]}',
      _ => '${q.t}:${q.a[0]}:${q.a[1]}',
    };
