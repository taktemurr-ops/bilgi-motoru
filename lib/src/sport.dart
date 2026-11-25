import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import 'data/countries.dart';
import 'data/sport.dart';
import 'quiz.dart';
import 'texts.dart';

// Spor Bilgisi şablonları: olimpiyat ev sahipleri, futbol Dünya Kupası,
// kural sayıları, spor/ekipman ve olimpik branşlar.

final Map<String, int> _isoIndex = {for (var i = 0; i < kCountries.length; i++) kCountries[i].iso: i};

int _ci(String iso) => _isoIndex[iso]!;

String sportName(int i, String lang) => Strings.pick(kSportNames[i], lang);

String sportLabel(int i, String lang) => '${kSports[i].$1} ${sportName(i, lang)}';

List<(int, String)> _games(int season) => season == 0 ? kSummerGames : kWinterGames;

String _gamesTitle(int season, int year, String lang) => bt(lang, season == 0 ? 'spSummerY' : 'spWinterY', {'y': year});

/// Bir mevsimde ev sahipliği yapmış ülkeler (kCountries sırası).
List<int> _hosts(int season) => {for (final g in _games(season)) _ci(g.$2)}.toList();

List<int> _cupHosts() => {for (final c in kCups) if (c.$2.isNotEmpty) _ci(c.$2)}.toList();

List<int> _cupWinners() => {for (final c in kCups) if (c.$3.isNotEmpty) _ci(c.$3)}.toList();

int _n(int d) => d <= 2 ? 3 : 4;

/// [pool] içinden [exclude] dışında en fazla [k] farklı öğe.
List<int> _others(List<int> pool, Set<int> exclude, int k, SeededRandom r) {
  final xs = pool.where((x) => !exclude.contains(x)).toList();
  r.shuffle(xs);
  return xs.take(k).toList();
}

BQ? _finish(int t, List<int> a, int correct, List<int> wrong, int n, SeededRandom r) {
  if (wrong.length < n - 1) return null;
  final opts = [correct, ...wrong.take(n - 1)];
  r.shuffle(opts);
  return BQ(t, a, opts, opts.indexOf(correct));
}

// ------------------------------------------------------------------ olimpiyat ev sahibi

BQ? genSpOly(int d, SeededRandom r) {
  final season = d <= 2 ? 0 : r.nextInt(2);
  final games = _games(season);
  final ed = r.nextInt(games.length);
  final host = _ci(games[ed].$2);
  final pool = d >= 6 ? [..._hosts(0), ..._hosts(1)].toSet().toList() : _hosts(season);
  return _finish(Tpl.spOly, [season, ed], host, _others(pool, {host}, 3, r), _n(d), r);
}

/// [country] verilen mevsimde ev sahibi olduğu yıllar.
List<int> _hostYears(int season, int country) => [
      for (final g in _games(season))
        if (_ci(g.$2) == country) g.$1
    ];

BQ? genSpOlyYear(int d, SeededRandom r) {
  final season = d <= 2 ? 0 : r.nextInt(2);
  final c = r.pick(_hosts(season));
  final mine = _hostYears(season, c);
  final year = r.pick(mine);
  final other = [
    for (final g in _games(season))
      if (_ci(g.$2) != c) g.$1
  ];
  return _finish(Tpl.spOlyYear, [season, c], year, _others(other, mine.toSet(), 3, r), _n(d), r);
}

// ------------------------------------------------------------------ Dünya Kupası

BQ? genSpCup(int d, SeededRandom r) {
  final kind = r.nextInt(4);
  if (kind < 2) {
    // 0 ev sahibi, 1 şampiyon: yıl verilir, ülke sorulur.
    final idx = [
      for (var i = 0; i < kCups.length; i++)
        if ((kind == 0 ? kCups[i].$2 : kCups[i].$3).isNotEmpty) i
    ];
    final i = r.pick(idx);
    final c = _ci(kind == 0 ? kCups[i].$2 : kCups[i].$3);
    final pool = {..._cupHosts(), ..._cupWinners()}.toList();
    return _finish(Tpl.spCup, [kind, i], c, _others(pool, {c}, 3, r), _n(d), r);
  }
  // 2 şampiyonluk yılı, 3 ev sahipliği yılı: ülke verilir, yıl sorulur.
  final role = kind - 2;
  final cs = role == 0 ? _cupWinners() : _cupHosts();
  final c = r.pick(cs);
  final iso = kCountries[c].iso;
  final mine = [
    for (final x in kCups)
      if ((role == 0 ? x.$3 : x.$2) == iso) x.$1
  ];
  final year = r.pick(mine);
  final other = [
    for (final x in kCups)
      if ((role == 0 ? x.$3 : x.$2) != iso) x.$1
  ];
  return _finish(Tpl.spCup, [kind, c], year, _others(other, mine.toSet(), 3, r), _n(d), r);
}

List<int> _cupYears(int role, int c) {
  final iso = kCountries[c].iso;
  return [
    for (final x in kCups)
      if ((role == 0 ? x.$3 : x.$2) == iso) x.$1
  ];
}

// ------------------------------------------------------------------ kurallar ve sayılar

int _enc(double v) => (v * 1000).round();

BQ? genSpRule(int d, SeededRandom r) {
  final i = r.nextInt(kSportRules.length);
  final rule = kSportRules[i];
  final wrong = [for (final w in rule.$6) _enc(w)];
  r.shuffle(wrong);
  return _finish(Tpl.spRule, [i], _enc(rule.$3), wrong, _n(d), r);
}

String _ruleValue(int i, int enc) {
  final rule = kSportRules[i];
  final s = (enc / 1000).toStringAsFixed(rule.$5);
  return rule.$4.isEmpty ? s : '$s ${rule.$4}';
}

String _rulePrompt(int i, String lang) {
  final rule = kSportRules[i];
  return rule.$2 >= 0 ? bt(lang, rule.$1, {'s': sportName(rule.$2, lang)}) : bt(lang, rule.$1);
}

// ------------------------------------------------------------------ spor ve ekipman

BQ? genSpSport(int d, SeededRandom r) {
  final mode = r.nextInt(2);
  final s = r.nextInt(kSports.length);
  final pool = [for (var i = 0; i < kSports.length; i++) i];
  return _finish(Tpl.spSport, [mode, s], s, _others(pool, {s}, 3, r), _n(d), r);
}

/// 0: kış olimpik branşı, 1: olimpik olmayan, 2: yaz olimpik branşı.
BQ? genSpSeason(int d, SeededRandom r) {
  final kind = r.nextInt(3);
  final want = switch (kind) { 0 => 1, 1 => 2, _ => 0 };
  final good = [for (var i = 0; i < kSports.length; i++) if (kSports[i].$2 == want) i];
  final bad = [
    for (var i = 0; i < kSports.length; i++)
      if (kSports[i].$2 >= 0 && kSports[i].$2 != want && !(want == 2 && kSports[i].$2 == 1)) i
  ];
  final s = r.pick(good);
  return _finish(Tpl.spSeason, [kind], s, _others(bad, <int>{}, 3, r), _n(d), r);
}

bool _seasonOk(int kind, int s) => kSports[s].$2 == switch (kind) { 0 => 1, 1 => 2, _ => 0 };

// ------------------------------------------------------------------ ortak giriş noktaları

bool _onlyAns(BQ q, bool Function(int) ok) {
  for (var i = 0; i < q.o.length; i++) {
    if (ok(q.o[i]) != (i == q.ans)) return false;
  }
  return true;
}

bool checkSport(BQ q) {
  final a = q.a;
  if (a.length != 2 && a.length != 1) return false;
  switch (q.t) {
    case Tpl.spOly:
      final games = _games(a[0]);
      if (a[1] < 0 || a[1] >= games.length) return false;
      final host = _ci(games[a[1]].$2);
      return _onlyAns(q, (c) => c == host);
    case Tpl.spOlyYear:
      final mine = _hostYears(a[0], a[1]);
      return mine.isNotEmpty && _onlyAns(q, mine.contains);
    case Tpl.spCup:
      if (a[0] < 2) {
        final x = kCups[a[1]];
        final iso = a[0] == 0 ? x.$2 : x.$3;
        if (iso.isEmpty) return false;
        return _onlyAns(q, (c) => c == _ci(iso));
      }
      final mine = _cupYears(a[0] - 2, a[1]);
      return mine.isNotEmpty && _onlyAns(q, mine.contains);
    case Tpl.spRule:
      final v = _enc(kSportRules[a[0]].$3);
      return _onlyAns(q, (x) => x == v);
    case Tpl.spSport:
      return _onlyAns(q, (s) => s == a[1]);
    case Tpl.spSeason:
      return _onlyAns(q, (s) => _seasonOk(a[0], s));
  }
  return false;
}

QText renderSport(BQ q, String lang) {
  final a = q.a;
  switch (q.t) {
    case Tpl.spOly:
      final e = _gamesTitle(a[0], _games(a[0])[a[1]].$1, lang);
      return QText(bt(lang, 'spQHost', {'e': e}), [for (final c in q.o) countryName(c, lang)]);
    case Tpl.spOlyYear:
      return QText(bt(lang, a[0] == 0 ? 'spQYearS' : 'spQYearW', {'c': countryName(a[1], lang)}), [for (final y in q.o) '$y']);
    case Tpl.spCup:
      if (a[0] < 2) {
        final e = bt(lang, 'spCupY', {'y': kCups[a[1]].$1});
        return QText(bt(lang, a[0] == 0 ? 'spQHost' : 'spQWin', {'e': e}), [for (final c in q.o) countryName(c, lang)]);
      }
      return QText(bt(lang, a[0] == 2 ? 'spQCupWinYear' : 'spQCupHostYear', {'c': countryName(a[1], lang)}),
          [for (final y in q.o) '$y']);
    case Tpl.spRule:
      return QText(_rulePrompt(a[0], lang), [for (final v in q.o) _ruleValue(a[0], v)]);
    case Tpl.spSport:
      if (a[0] == 0) {
        return QText(bt(lang, 'spWhich', {'x': kSports[a[1]].$1}), [for (final s in q.o) sportName(s, lang)]);
      }
      return QText(bt(lang, 'spEquip', {'s': sportName(a[1], lang)}), [for (final s in q.o) kSports[s].$1]);
    case Tpl.spSeason:
      final key = switch (a[0]) { 0 => 'spWinter', 1 => 'spNotOly', _ => 'spSummer' };
      return QText(bt(lang, key), [for (final s in q.o) sportLabel(s, lang)]);
  }
  return const QText('?', []);
}

String explainSport(BQ q, String lang) {
  final a = q.a;
  switch (q.t) {
    case Tpl.spOly:
      final g = _games(a[0])[a[1]];
      return '${_gamesTitle(a[0], g.$1, lang)}: ${countryName(_ci(g.$2), lang)}';
    case Tpl.spOlyYear:
      return [for (final y in _hostYears(a[0], a[1])) '${_gamesTitle(a[0], y, lang)}: ${countryName(a[1], lang)}'].join('\n');
    case Tpl.spCup:
      if (a[0] < 2) {
        final x = kCups[a[1]];
        return '${bt(lang, 'spCupY', {'y': x.$1})}: ${countryName(_ci(a[0] == 0 ? x.$2 : x.$3), lang)}';
      }
      return [for (final y in _cupYears(a[0] - 2, a[1])) '${bt(lang, 'spCupY', {'y': y})}: ${countryName(a[1], lang)}']
          .join('\n');
    case Tpl.spRule:
      return '${_rulePrompt(a[0], lang)} → ${_ruleValue(a[0], _enc(kSportRules[a[0]].$3))}';
    case Tpl.spSport:
      return sportLabel(a[1], lang);
    case Tpl.spSeason:
      return sportLabel(q.o[q.ans], lang);
  }
  return '';
}

String subjectKeySport(BQ q) => 'sp:${q.t}:${q.a.join(':')}';
