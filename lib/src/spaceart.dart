import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import 'data/countries.dart';
import 'data/spaceart.dart';
import 'quiz.dart';
import 'texts.dart';

// Uzay ve Astronomi ile Sanat ve Edebiyat şablonları. Uzay verisi kamuya açık
// kaynaklardan (NASA, IAU); sanat verisi yalnızca kamu malı eserlerden.

final Map<String, int> _isoIndex = {for (var i = 0; i < kCountries.length; i++) kCountries[i].iso: i};

int _n(int d) => d <= 2 ? 3 : 4;

List<int> _others(List<int> pool, Set<int> exclude, int k, SeededRandom r) {
  final xs = pool.where((x) => !exclude.contains(x)).toSet().toList();
  r.shuffle(xs);
  return xs.take(k).toList();
}

BQ? _finish(int t, List<int> a, int correct, List<int> wrong, int n, SeededRandom r) {
  if (wrong.length < n - 1) return null;
  final opts = [correct, ...wrong.take(n - 1)];
  r.shuffle(opts);
  return BQ(t, a, opts, opts.indexOf(correct));
}

bool _onlyAns(BQ q, bool Function(int) ok) {
  for (var i = 0; i < q.o.length; i++) {
    if (ok(q.o[i]) != (i == q.ans)) return false;
  }
  return true;
}

String _pick(List<List<String>> t, int i, String lang) => Strings.pick(t[i], lang);

/// Ondalık ayırıcı dile göre (virgül kullanan diller).
const Set<String> _commaLangs = {
  'tr', 'de', 'es', 'fr', 'ru', 'uk', 'pl', 'cs', 'ro', 'hu', 'el', 'it', 'pt', 'nl', 'sv', 'da', 'nb', 'fi', 'id', 'vi', //
};

String spcNumText(String s, String lang) => _commaLangs.contains(lang) ? s.replaceAll('.', ',') : s;

// ------------------------------------------------------------------ uzay

const int _planets = 8;

/// Uzay cismi kodu: kategori*100 + sıra. 0 cüce gezegen, 1 uydu, 2 yıldız, 3 gezegen.
int _objCount(int cat) => switch (cat) { 0 => kDwarfNames.length, 1 => kMoonNames.length, 2 => kStarNames.length, _ => _planets };

String spaceObjName(int code, String lang) {
  final cat = code ~/ 100, i = code % 100;
  return switch (cat) {
    0 => _pick(kDwarfNames, i, lang),
    1 => _pick(kMoonNames, i, lang),
    2 => _pick(kStarNames, i, lang),
    _ => planetName(i, lang),
  };
}

BQ? genSpcFact(int d, SeededRandom r) {
  final f = r.nextInt(kSpcFactQ.length);
  final ans = kSpcFactAns[f];
  final correct = ans[r.nextInt(ans.length)];
  final pool = [for (var p = 0; p < _planets; p++) p];
  return _finish(Tpl.spcFact, [f], correct, _others(pool, ans.toSet(), 3, r), _n(d), r);
}

BQ? genSpcMoon(int d, SeededRandom r) {
  final m = r.nextInt(kMoonNames.length);
  final p = kMoonPlanet[m];
  // Kolay bölümlerde yalnız uydusu olan gezegenler seçenek olur.
  final pool = d <= 3 ? [2, 3, 4, 5, 6, 7] : [for (var i = 0; i < _planets; i++) i];
  return _finish(Tpl.spcMoon, [m], p, _others(pool, {p}, 3, r), _n(d), r);
}

BQ? genSpcNum(int d, SeededRandom r) {
  final i = r.nextInt(kSpcNumQ.length);
  final n = kSpcNumOpts[i].length;
  final wrong = [for (var k = 1; k < n; k++) k];
  r.shuffle(wrong);
  return _finish(Tpl.spcNum, [i], 0, wrong, _n(d), r);
}

BQ? genSpcYear(int d, SeededRandom r) {
  final e = r.nextInt(kSpcEventYears.length);
  final y = kSpcEventYears[e];
  // Zorluk arttıkça yanlış yıllar doğru yıla yaklaşır.
  final spread = d <= 3 ? 40 : (d <= 6 ? 20 : 8);
  final wrong = <int>{};
  for (var a = 0; a < 40 && wrong.length < 3; a++) {
    final off = (1 + r.nextInt(spread)) * (r.chance(0.5) ? 1 : -1);
    final w = y + off;
    if (w != y && w <= 2026) wrong.add(w);
  }
  return _finish(Tpl.spcYear, [e], y, wrong.toList(), _n(d), r);
}

BQ? genSpcConst(int d, SeededRandom r) {
  final s = r.nextInt(kStarNames.length);
  final c = kStarConst[s];
  final pool = [for (var i = 0; i < kConstNames.length; i++) i];
  return _finish(Tpl.spcConst, [s], c, _others(pool, {c}, 3, r), _n(d), r);
}

BQ? genSpcType(int d, SeededRandom r) {
  final cat = r.nextInt(4);
  final correct = cat * 100 + r.nextInt(_objCount(cat));
  final pool = <int>[
    for (var c = 0; c < 4; c++)
      if (c != cat)
        for (var i = 0; i < _objCount(c); i++) c * 100 + i,
  ];
  return _finish(Tpl.spcType, [cat], correct, _others(pool, {correct}, 3, r), _n(d), r);
}

// ------------------------------------------------------------------ sanat ve edebiyat

/// Eser kodu: tablolar 0.., kitaplar 100+.
String workName(int code, String lang) => code >= 100 ? _pick(kBookNames, code - 100, lang) : _pick(kPaintNames, code, lang);

int workYear(int code) => code >= 100 ? kBookInfo[code - 100].$2 : kPaintInfo[code].$2;

String workCreator(int code, String lang) =>
    code >= 100 ? _pick(kAuthorNames, kBookInfo[code - 100].$1, lang) : _pick(kArtistNames, kPaintInfo[code].$1, lang);

BQ? genArtPaint(int d, SeededRandom r) {
  final p = r.nextInt(kPaintNames.length);
  final a = kPaintInfo[p].$1;
  final pool = [for (var i = 0; i < kArtistNames.length; i++) i];
  return _finish(Tpl.artPaint, [p], a, _others(pool, {a}, 3, r), _n(d), r);
}

BQ? genArtPaintRev(int d, SeededRandom r) {
  final p = r.nextInt(kPaintNames.length);
  final a = kPaintInfo[p].$1;
  final pool = [for (var i = 0; i < kPaintNames.length; i++) if (kPaintInfo[i].$1 != a) i];
  return _finish(Tpl.artPaintRev, [a], p, _others(pool, {p}, 3, r), _n(d), r);
}

BQ? genArtBook(int d, SeededRandom r) {
  final b = r.nextInt(kBookNames.length);
  final a = kBookInfo[b].$1;
  final pool = [for (var i = 0; i < kAuthorNames.length; i++) i];
  return _finish(Tpl.artBook, [b], a, _others(pool, {a}, 3, r), _n(d), r);
}

BQ? genArtBookRev(int d, SeededRandom r) {
  final b = r.nextInt(kBookNames.length);
  final a = kBookInfo[b].$1;
  final pool = [for (var i = 0; i < kBookNames.length; i++) if (kBookInfo[i].$1 != a) i];
  return _finish(Tpl.artBookRev, [a], b, _others(pool, {b}, 3, r), _n(d), r);
}

BQ? genArtMove(int d, SeededRandom r) {
  final m = r.nextInt(kMoveNames.length);
  final good = [for (var i = 0; i < kArtistInfo.length; i++) if (kArtistInfo[i].$2 == m) i];
  final bad = [for (var i = 0; i < kArtistInfo.length; i++) if (kArtistInfo[i].$2 >= 0 && kArtistInfo[i].$2 != m) i];
  if (good.isEmpty) return null;
  return _finish(Tpl.artMove, [m], r.pick(good), _others(bad, <int>{}, 3, r), _n(d), r);
}

/// Yaratıcı kodu: ressamlar 0.., yazarlar 100+. Ülkesi bilinmeyenler sorulmaz.
String _creatorIso(int code) => code >= 100 ? kAuthorIso[code - 100] : kArtistInfo[code].$1;

String creatorName(int code, String lang) => code >= 100 ? _pick(kAuthorNames, code - 100, lang) : _pick(kArtistNames, code, lang);

List<int> get _creators => [
      for (var i = 0; i < kArtistInfo.length; i++)
        if (kArtistInfo[i].$1.isNotEmpty) i,
      for (var i = 0; i < kAuthorIso.length; i++)
        if (kAuthorIso[i].isNotEmpty) 100 + i,
    ];

BQ? genArtFrom(int d, SeededRandom r) {
  final cs = _creators;
  final c = r.pick(cs);
  final ci = _isoIndex[_creatorIso(c)];
  if (ci == null) return null;
  final pool = [for (final x in cs) if (_isoIndex[_creatorIso(x)] != null) _isoIndex[_creatorIso(x)]!];
  return _finish(Tpl.artFrom, [c], ci, _others(pool, {ci}, 3, r), _n(d), r);
}

BQ? genArtOld(int d, SeededRandom r) {
  final works = [
    for (var i = 0; i < kPaintInfo.length; i++)
      if (kPaintInfo[i].$2 > 0) i,
    for (var i = 0; i < kBookInfo.length; i++)
      if (kBookInfo[i].$2 > 0) 100 + i,
  ];
  r.shuffle(works);
  // Aralarında en az 20 yıl olan eserler seçilir (yaklaşık tarihler karışmasın).
  final gap = d <= 4 ? 40 : 20;
  final pick = <int>[];
  for (final w in works) {
    if (pick.every((p) => (workYear(p) - workYear(w)).abs() >= gap)) pick.add(w);
    if (pick.length == _n(d)) break;
  }
  if (pick.length < _n(d)) return null;
  final oldest = pick.reduce((a, b) => workYear(a) <= workYear(b) ? a : b);
  return _finish(Tpl.artOld, const [], oldest, [for (final p in pick) if (p != oldest) p], _n(d), r);
}

// ------------------------------------------------------------------ ortak giriş noktaları

bool checkSpaceArt(BQ q) {
  final a = q.a;
  bool inRange(int v, int n) => v >= 0 && v < n;
  switch (q.t) {
    case Tpl.spcFact:
      if (a.length != 1 || !inRange(a[0], kSpcFactQ.length) || !q.o.every((p) => inRange(p, _planets))) return false;
      return _onlyAns(q, kSpcFactAns[a[0]].contains);
    case Tpl.spcMoon:
      if (a.length != 1 || !inRange(a[0], kMoonNames.length) || !q.o.every((p) => inRange(p, _planets))) return false;
      return _onlyAns(q, (p) => p == kMoonPlanet[a[0]]);
    case Tpl.spcNum:
      if (a.length != 1 || !inRange(a[0], kSpcNumQ.length) || !q.o.every((x) => inRange(x, kSpcNumOpts[a[0]].length))) return false;
      return _onlyAns(q, (x) => x == 0);
    case Tpl.spcYear:
      if (a.length != 1 || !inRange(a[0], kSpcEventYears.length)) return false;
      return _onlyAns(q, (y) => y == kSpcEventYears[a[0]]);
    case Tpl.spcConst:
      if (a.length != 1 || !inRange(a[0], kStarNames.length) || !q.o.every((c) => inRange(c, kConstNames.length))) return false;
      return _onlyAns(q, (c) => c == kStarConst[a[0]]);
    case Tpl.spcType:
      if (a.length != 1 || !inRange(a[0], 4) || !q.o.every((x) => inRange(x ~/ 100, 4) && inRange(x % 100, _objCount(x ~/ 100)))) return false;
      return _onlyAns(q, (x) => x ~/ 100 == a[0]);
    case Tpl.artPaint:
      if (a.length != 1 || !inRange(a[0], kPaintNames.length) || !q.o.every((x) => inRange(x, kArtistNames.length))) return false;
      return _onlyAns(q, (x) => x == kPaintInfo[a[0]].$1);
    case Tpl.artPaintRev:
      if (a.length != 1 || !inRange(a[0], kArtistNames.length) || !q.o.every((x) => inRange(x, kPaintNames.length))) return false;
      return _onlyAns(q, (x) => kPaintInfo[x].$1 == a[0]);
    case Tpl.artBook:
      if (a.length != 1 || !inRange(a[0], kBookNames.length) || !q.o.every((x) => inRange(x, kAuthorNames.length))) return false;
      return _onlyAns(q, (x) => x == kBookInfo[a[0]].$1);
    case Tpl.artBookRev:
      if (a.length != 1 || !inRange(a[0], kAuthorNames.length) || !q.o.every((x) => inRange(x, kBookNames.length))) return false;
      return _onlyAns(q, (x) => kBookInfo[x].$1 == a[0]);
    case Tpl.artMove:
      if (a.length != 1 || !inRange(a[0], kMoveNames.length) || !q.o.every((x) => inRange(x, kArtistInfo.length) && kArtistInfo[x].$2 >= 0)) return false;
      return _onlyAns(q, (x) => kArtistInfo[x].$2 == a[0]);
    case Tpl.artFrom:
      if (a.length != 1 || !q.o.every((x) => inRange(x, kCountries.length))) return false;
      final ci = _isoIndex[_creatorIso(a[0])];
      return ci != null && _onlyAns(q, (x) => x == ci);
    case Tpl.artOld:
      if (q.o.any((w) => w >= 100 ? !inRange(w - 100, kBookInfo.length) : !inRange(w, kPaintInfo.length))) return false;
      if (q.o.any((w) => workYear(w) <= 0)) return false;
      final years = [for (final w in q.o) workYear(w)]..sort();
      for (var i = 1; i < years.length; i++) {
        if (years[i] - years[i - 1] < 20) return false;
      }
      return _onlyAns(q, (w) => workYear(w) == years.first);
  }
  return false;
}

QText renderSpaceArt(BQ q, String lang) {
  final a = q.a;
  switch (q.t) {
    case Tpl.spcFact:
      return QText(_pick(kSpcFactQ, a[0], lang), [for (final p in q.o) planetName(p, lang)]);
    case Tpl.spcMoon:
      return QText(bt(lang, 'spcQMoon', {'m': _pick(kMoonNames, a[0], lang)}), [for (final p in q.o) planetName(p, lang)]);
    case Tpl.spcNum:
      return QText(_pick(kSpcNumQ, a[0], lang), [for (final x in q.o) spcNumText(kSpcNumOpts[a[0]][x], lang)]);
    case Tpl.spcYear:
      return QText(bt(lang, 'spcQYear', {'e': _pick(kSpcEventTexts, a[0], lang)}), [for (final y in q.o) '$y']);
    case Tpl.spcConst:
      return QText(bt(lang, 'spcQConst', {'s': _pick(kStarNames, a[0], lang)}), [for (final c in q.o) _pick(kConstNames, c, lang)]);
    case Tpl.spcType:
      return QText(bt(lang, 'spcQType${a[0]}'), [for (final x in q.o) spaceObjName(x, lang)]);
    case Tpl.artPaint:
      return QText(bt(lang, 'artQPaint', {'w': _pick(kPaintNames, a[0], lang)}), [for (final x in q.o) _pick(kArtistNames, x, lang)]);
    case Tpl.artPaintRev:
      return QText(bt(lang, 'artQPaintRev', {'a': _pick(kArtistNames, a[0], lang)}), [for (final x in q.o) _pick(kPaintNames, x, lang)]);
    case Tpl.artBook:
      return QText(bt(lang, 'artQBook', {'w': _pick(kBookNames, a[0], lang)}), [for (final x in q.o) _pick(kAuthorNames, x, lang)]);
    case Tpl.artBookRev:
      return QText(bt(lang, 'artQBookRev', {'a': _pick(kAuthorNames, a[0], lang)}), [for (final x in q.o) _pick(kBookNames, x, lang)]);
    case Tpl.artMove:
      return QText(bt(lang, 'artQMove', {'m': _pick(kMoveNames, a[0], lang)}), [for (final x in q.o) _pick(kArtistNames, x, lang)]);
    case Tpl.artFrom:
      return QText(bt(lang, 'artQFrom', {'a': creatorName(a[0], lang)}), [for (final c in q.o) countryName(c, lang)]);
    case Tpl.artOld:
      return QText(bt(lang, 'artQOld'), [for (final w in q.o) workName(w, lang)]);
  }
  return const QText('?', []);
}

String explainSpaceArt(BQ q, String lang) {
  final a = q.a;
  switch (q.t) {
    case Tpl.spcFact:
      return [for (final p in kSpcFactAns[a[0]]) planetName(p, lang)].join(', ');
    case Tpl.spcMoon:
      return '${_pick(kMoonNames, a[0], lang)} → ${planetName(kMoonPlanet[a[0]], lang)}';
    case Tpl.spcNum:
      return spcNumText(kSpcNumOpts[a[0]][0], lang);
    case Tpl.spcYear:
      return '${_pick(kSpcEventTexts, a[0], lang)}: ${kSpcEventYears[a[0]]}';
    case Tpl.spcConst:
      return '${_pick(kStarNames, a[0], lang)} → ${_pick(kConstNames, kStarConst[a[0]], lang)}';
    case Tpl.spcType:
      return spaceObjName(q.o[q.ans], lang);
    case Tpl.artPaint:
      return '${_pick(kPaintNames, a[0], lang)} — ${_pick(kArtistNames, kPaintInfo[a[0]].$1, lang)}${kPaintInfo[a[0]].$2 > 0 ? ' (${kPaintInfo[a[0]].$2})' : ''}';
    case Tpl.artPaintRev:
      final p = q.o[q.ans];
      return '${_pick(kPaintNames, p, lang)} — ${_pick(kArtistNames, a[0], lang)}';
    case Tpl.artBook:
      return '${_pick(kBookNames, a[0], lang)} — ${_pick(kAuthorNames, kBookInfo[a[0]].$1, lang)}${kBookInfo[a[0]].$2 > 0 ? ' (${kBookInfo[a[0]].$2})' : ''}';
    case Tpl.artBookRev:
      final b = q.o[q.ans];
      return '${_pick(kBookNames, b, lang)} — ${_pick(kAuthorNames, a[0], lang)}';
    case Tpl.artMove:
      return '${_pick(kArtistNames, q.o[q.ans], lang)} · ${_pick(kMoveNames, a[0], lang)}';
    case Tpl.artFrom:
      final ci = _isoIndex[_creatorIso(a[0])];
      return ci == null ? '' : '${creatorName(a[0], lang)} · ${countryName(ci, lang)}';
    case Tpl.artOld:
      final xs = [...q.o]..sort((x, y) => workYear(x).compareTo(workYear(y)));
      return [for (final w in xs) '${workName(w, lang)} (${workCreator(w, lang)}, ${workYear(w)})'].join('\n');
  }
  return '';
}

String subjectKeySpaceArt(BQ q) => switch (q.t) {
      Tpl.artOld => 'sa:${q.t}:${([...q.o]..sort()).join(',')}',
      Tpl.spcType => 'sa:${q.t}:${q.o[q.ans]}',
      _ => 'sa:${q.t}:${q.a.isEmpty ? 0 : q.a[0]}',
    };
