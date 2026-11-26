/// 4. tur Bilgi Yarışması türleri: Aklımdan Tuttum (akıl okuyan cin),
/// Halk Ne Dedi? (tahmini sıralamalı anket panosu), Bilgi Merdiveni
/// (15 basamak, 3 joker) ve Ülke Silüeti (silüetten ülke; mesafe ve yön).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/strings.dart';

import 'core.dart';
import 'data/animals.dart';
import 'data/countries.dart';
import 'data/elements.dart';
import 'data/i18n.dart';
import 'data/shapes.dart';
import 'quiz.dart';
import 'stage.dart' show QuestionVisual;
import 'studio_chrome.dart';
import 'texts.dart';
import 'texts_ek4.dart';

/// Özel bölümlerin soru kodları (normal şablonlarla çakışmaz).
class TplX {
  static const genie = 100, survey = 101, shape = 102;
}

// ================================================================ ortak

BLevel? makeSpecial(BilgiKind k, int d, int seed) {
  final r = SeededRandom(mixSeed([seed, d, 7711]));
  switch (k.special) {
    case 'genie':
      return _makeGenie(k, d, r);
    case 'survey':
      return _makeSurvey(k, d, r);
    case 'ladder':
      return _makeLadder(k, d, r);
    case 'shape':
      return _makeShape(k, d, r);
  }
  return null;
}

bool checkSpecial(BilgiKind k, BLevel lv) {
  if (lv.kind != k.id || lv.qs.isEmpty) return false;
  switch (k.special) {
    case 'genie':
      return _checkGenie(lv);
    case 'survey':
      return _checkSurvey(lv);
    case 'ladder':
      return _checkLadder(lv);
    case 'shape':
      return _checkShape(lv);
  }
  return false;
}

Widget buildSpecial(PlayContext ctx, BLevel lv, BilgiKind k) => switch (k.special) {
      'genie' => GenieView(ctx: ctx, level: lv),
      'survey' => SurveyView(ctx: ctx, level: lv),
      'ladder' => LadderView(ctx: ctx, level: lv),
      _ => ShapeView(ctx: ctx, level: lv),
    };

void _finish(PlayContext ctx, {required bool won, int score = 0, int stars = 1, int seconds = 0, int right = 0, String? headline, int hints = 0}) {
  ctx.finish(RoundResult(
    won: won,
    score: score < 0 ? 0 : score,
    stars: clampI(stars, 1, 3),
    seconds: seconds,
    hintsUsed: hints,
    headline: headline,
    gameStats: {if (won) 'rounds_won': 1, 'answers_right': right, if (won && stars >= 3) 'perfect': 1},
  ));
}

/// Zemin açıksa koyu, değilse beyaz yazı (en az 3:1 karşıtlık).
Color _onColor(Color bg) => 1.05 / (bg.computeLuminance() + 0.05) >= 3.2 ? Colors.white : const Color(0xFF14121F);

Widget _bigBtn(BuildContext context, String label, Color color, VoidCallback? onTap, {IconData? icon}) => SizedBox(
      height: 56,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: _onColor(color), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        onPressed: onTap,
        icon: Icon(icon ?? Icons.check_rounded),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );

// ================================================================ Aklımdan Tuttum

/// Cin sorusu: [dim] < 0 ise sabit soru (sıra [idx]); değilse sayısal boyut
/// [dim] ve kıyas varlığı [ref] ("ref'ten büyük mü?").
class GQ {
  final int idx;
  final int dim;
  final int ref;
  const GQ.fixed(this.idx)
      : dim = -1,
        ref = -1;
  const GQ.cmp(this.dim, this.ref) : idx = -1;
}

/// Bir kategorinin varlıkları: sabit soru yanıtları (1 evet, 0 hayır, -1 belirsiz)
/// ve sayısal boyutlar (negatif = bilinmiyor).
class GenieBase {
  final int cat;
  final int n;
  final int fixedCount;
  final int dims;
  final int Function(int e, int q) fixed;
  final double Function(int e, int dim) value;
  final bool Function(int e) refOk;
  const GenieBase(this.cat, this.n, this.fixedCount, this.dims, this.fixed, this.value, this.refOk);

  int answer(int e, GQ q) {
    if (q.dim < 0) return fixed(e, q.idx);
    final a = value(e, q.dim), b = value(q.ref, q.dim);
    if (a < 0 || b < 0) return -1;
    return a > b ? 1 : 0;
  }
}

int _animalFixed(int e, int q) {
  final a = kAnimals[e];
  switch (q) {
    case < 7:
      return a.cls < 0 ? -1 : (a.cls == q ? 1 : 0);
    case 7:
      return a.diet < 0 ? -1 : (a.diet == 0 ? 1 : 0);
    case 8:
      return a.diet < 0 ? -1 : (a.diet >= 1 ? 1 : 0);
    case 9:
      return a.sea;
    case 10:
      return a.eggs;
    case 11:
      return a.legs < 0 ? -1 : (a.legs == 4 ? 1 : 0);
    case 12:
      return a.legs < 0 ? -1 : (a.legs == 2 ? 1 : 0);
    case 13:
      return a.legs < 0 ? -1 : (a.legs == 0 ? 1 : 0);
    default:
      return a.legs < 0 ? -1 : (a.legs >= 6 ? 1 : 0);
  }
}

int _countryFixed(int e, int q) {
  final c = kCountries[e];
  if (q < 6) return c.cont < 0 ? -1 : (c.cont == q ? 1 : 0);
  if (q == 6) return c.lat.abs() < 1 ? -1 : (c.lat > 0 ? 1 : 0);
  if (q == 7) return c.lon.abs() < 1 ? -1 : (c.lon > 0 ? 1 : 0);
  return (c.lat.abs() - 23.44).abs() < 1.5 ? -1 : (c.lat.abs() < 23.44 ? 1 : 0);
}

int _elemFixed(int e, int q) {
  final el = kElements[e];
  if (q < 5) return el.cat == q ? 1 : 0;
  if (q == 5) return el.state < 0 ? -1 : (el.state == 2 ? 1 : 0);
  if (q == 6) return el.state < 0 ? -1 : (el.state == 1 ? 1 : 0);
  return el.group == 0 ? 1 : 0;
}

/// Kıyas için tanınmış ülkeler: haritada görünen ve 250 bin km²'den büyük.
bool _famousCountry(int e) => kCountries[e].onMap && kCountries[e].area >= 250000;

final List<GenieBase> kGenieBases = [
  GenieBase(0, kAnimals.length, 15, 1, _animalFixed, (e, _) => kAnimals[e].kg, (e) => kAnimals[e].kg > 0),
  GenieBase(1, kCountries.length, 9, 3, _countryFixed, (e, dim) {
    final c = kCountries[e];
    return switch (dim) { 0 => c.area.toDouble(), 1 => c.lat + 100, _ => c.lon + 200 };
  }, _famousCountry),
  GenieBase(2, kElements.length, 8, 1, _elemFixed, (e, _) => kElements[e].z.toDouble(), (e) => true),
];

/// Akıl okuyan cin: aday ağırlıklarıyla en dengeli soruyu seçer, bir yanlış yanıtı tolere eder.
class Genie {
  final GenieBase base;
  final int budget;
  late final List<int> miss = List.filled(base.n, 0);
  final Set<int> askedFixed = {};
  final Set<int> askedRef = {};
  int used = 0;
  Genie(this.base, this.budget);

  double weight(int e) => miss[e] == 0 ? 1 : (miss[e] == 1 ? 0.25 : 0);

  List<int> get active => [for (var e = 0; e < base.n; e++) if (miss[e] <= 1) e];

  int get exact => [for (var e = 0; e < base.n; e++) if (miss[e] == 0) e].length;

  double _imbalance(GQ q, List<int> act) {
    var yes = 0.0, no = 0.0;
    for (final e in act) {
      final w = weight(e);
      final a = base.answer(e, q);
      if (a == 1) {
        yes += w;
      } else if (a == 0) {
        no += w;
      } else {
        yes += w / 2;
        no += w / 2;
      }
    }
    if (yes < 1e-9 || no < 1e-9) return double.infinity;
    return (yes - no).abs();
  }

  /// Sıradaki soru; bölen soru kalmadıysa null (tahmin zamanı).
  GQ? nextQuestion() {
    final act = active;
    GQ? best;
    var bs = double.infinity;
    for (var i = 0; i < base.fixedCount; i++) {
      if (askedFixed.contains(i)) continue;
      final q = GQ.fixed(i);
      final s = _imbalance(q, act);
      if (s < bs) {
        bs = s;
        best = q;
      }
    }
    for (var dim = 0; dim < base.dims; dim++) {
      final vals = [for (final e in act) if (base.value(e, dim) >= 0) base.value(e, dim)]..sort();
      if (vals.length < 2) continue;
      final med = vals[(vals.length - 1) ~/ 2];
      // Ortancaya en yakın, daha önce kullanılmamış tanınmış kıyas varlığı.
      var ref = -1;
      var rd = double.infinity;
      for (var e = 0; e < base.n; e++) {
        if (!base.refOk(e) || askedRef.contains(dim * 10000 + e)) continue;
        final v = base.value(e, dim);
        if (v < 0) continue;
        final dd = (v - med).abs();
        if (dd < rd) {
          rd = dd;
          ref = e;
        }
      }
      if (ref < 0) continue;
      final q = GQ.cmp(dim, ref);
      final s = _imbalance(q, act);
      if (s < bs) {
        bs = s;
        best = q;
      }
    }
    return bs.isFinite ? best : null;
  }

  bool get shouldGuess => exact <= 1 || used >= budget - 1 || nextQuestion() == null;

  /// En olası aday (en az uyumsuzluk, eşitlikte küçük sıra).
  int? guess() {
    var best = -1;
    for (var e = 0; e < base.n; e++) {
      if (miss[e] > 1) continue;
      if (best < 0 || miss[e] < miss[best]) best = e;
    }
    return best < 0 ? null : best;
  }

  void ask(GQ q, int answer) {
    used++;
    if (q.dim < 0) {
      askedFixed.add(q.idx);
    } else {
      askedRef.add(q.dim * 10000 + q.ref);
    }
    if (answer < 0) return;
    for (var e = 0; e < base.n; e++) {
      final a = base.answer(e, q);
      if (a >= 0 && a != answer) miss[e]++;
    }
  }

  void wrongGuess(int e) {
    used++;
    miss[e] = 99;
  }
}

/// Dürüst yanıtlarla cin hedefi bütçe içinde bulur mu? (bölüm doğrulaması)
bool genieSolves(int cat, int target, int budget) {
  final g = Genie(kGenieBases[cat], budget);
  while (g.used < budget) {
    if (g.shouldGuess) {
      final e = g.guess();
      if (e == null) return false;
      if (e == target) return true;
      g.wrongGuess(e);
      continue;
    }
    final q = g.nextQuestion()!;
    g.ask(q, g.base.answer(target, q));
  }
  return false;
}

BLevel? _makeGenie(BilgiKind k, int d, SeededRandom r) {
  final cat = r.nextInt(3);
  final base = kGenieBases[cat];
  final budget = 20 - d ~/ 2;
  for (var t = 0; t < 12; t++) {
    final target = r.nextInt(base.n);
    if (cat == 1 && !kCountries[target].onMap && d <= 4) continue;
    if (genieSolves(cat, target, budget)) return BLevel(k.id, d, [BQ(TplX.genie, [cat, target, budget], const [], -1)]);
  }
  return null;
}

bool _checkGenie(BLevel lv) {
  if (lv.qs.length != 1) return false;
  final q = lv.qs.first;
  if (q.t != TplX.genie || q.a.length != 3) return false;
  final cat = q.a[0], target = q.a[1], budget = q.a[2];
  if (cat < 0 || cat > 2 || budget < 12 || budget > 20) return false;
  if (target < 0 || target >= kGenieBases[cat].n) return false;
  return genieSolves(cat, target, budget);
}

String genieEntityName(int cat, int e, String lang) => switch (cat) {
      0 => '${kAnimals[e].emoji} ${Strings.pick(kAnimalNames[e], lang)}',
      1 => countryName(e, lang),
      _ => '${kElements[e].sym} · ${elemName(kElements[e], lang)}',
    };

String genieQuestionText(GenieBase b, GQ q, String lang) {
  if (q.dim >= 0) {
    return switch (b.cat) {
      0 => bt(lang, 'gHeavier', {'x': Strings.pick(kAnimalNames[q.ref], lang)}),
      1 => bt(lang, ['gBiggerC', 'gNorthOf', 'gEastOf'][q.dim], {'x': countryName(q.ref, lang)}),
      _ => bt(lang, 'gZ', {'x': kElements[q.ref].z}),
    };
  }
  switch (b.cat) {
    case 0:
      const keys = [
        'gMammal', 'gBird', 'gReptile', 'gAmph', 'gFish', 'gInsect', 'gArach', 'gHerb', //
        'gCarn', 'gSea', 'gEggs', 'gLegs4', 'gLegs2', 'gLegs0', 'gLegsMany',
      ];
      return bt(lang, keys[q.idx]);
    case 1:
      if (q.idx < 6) return bt(lang, 'gCont', {'x': Strings.pick(kContinents[q.idx], lang)});
      return bt(lang, ['gNorthHem', 'gEastHem', 'gTropic'][q.idx - 6]);
    default:
      if (q.idx < 5) return bt(lang, 'gElCat', {'x': bt(lang, 'cat${q.idx}')});
      return bt(lang, ['gGas', 'gLiquid', 'gRare'][q.idx - 5]);
  }
}

class GenieView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const GenieView({super.key, required this.ctx, required this.level});
  @override
  State<GenieView> createState() => _GenieViewState();
}

class _GenieViewState extends State<GenieView> {
  late final BQ spec = widget.level.qs.first;
  late final int cat = spec.a[0];
  late final int suggestion = spec.a[1];
  late final int budget = spec.a[2];
  late final Genie g = Genie(kGenieBases[cat], budget);
  final Stopwatch watch = Stopwatch()..start();

  /// 0 giriş, 1 soru, 2 tahmin, 3 bitti.
  int phase = 0;
  GQ? q;
  int? guessing;
  bool found = false;
  bool done = false;

  String get lang => widget.ctx.lang;

  void _step() {
    if (g.used >= budget) return _end(false);
    if (g.shouldGuess) {
      final e = g.guess();
      if (e == null) return _end(false);
      setState(() {
        guessing = e;
        phase = 2;
      });
      return;
    }
    setState(() {
      q = g.nextQuestion();
      phase = 1;
    });
  }

  void _answer(int a) {
    final qq = q;
    if (qq == null || phase != 1) return;
    widget.ctx.sfx(Sfx.tap);
    g.ask(qq, a);
    _step();
  }

  void _guessAnswer(bool yes) {
    final e = guessing;
    if (e == null || phase != 2) return;
    if (yes) return _end(true);
    g.wrongGuess(e);
    _step();
  }

  void _end(bool genieWon) {
    if (done) return;
    done = true;
    setState(() {
      found = genieWon;
      phase = 3;
    });
    widget.ctx.sfx(genieWon ? Sfx.coin : Sfx.win);
  }

  void _close() {
    final stars = found ? (g.used > budget ~/ 2 ? 2 : 1) : 3;
    _finish(widget.ctx,
        won: true,
        stars: stars,
        score: found ? 100 + g.used * 10 : 400,
        seconds: watch.elapsed.inSeconds,
        right: g.used,
        headline: found ? bt(lang, 'gnFound') : bt(lang, 'gnBeaten'));
  }

  Widget _genie(BuildContext context, String text) {
    final look = StudioLook.of(context);
    return Column(children: [
      const SizedBox(height: 8),
      Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFE9DDFF), Color(0xFF8E6CE0), Color(0xFF3E2780)]),
          boxShadow: [BoxShadow(color: look.accent.withValues(alpha: 0.5), blurRadius: 24)],
        ),
        alignment: Alignment.center,
        child: Text(phase == 3 ? (found ? '✨' : '🏳️') : '🔮', style: const TextStyle(fontSize: 48)),
      ),
      const SizedBox(height: 14),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final catName = bt(lang, ['gnAnimal', 'gnCountry', 'gnElement'][cat]);
    final top = Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Row(children: [
        Flexible(child: StudioPill(label: catName, selected: true)),
        const SizedBox(width: 8),
        if (phase == 1 || phase == 2)
          Flexible(
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text('${bt(lang, 'gnQuestion')} ${g.used + 1}/$budget',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w800)),
            ),
          ),
      ]),
    );
    Widget body;
    List<Widget> buttons;
    switch (phase) {
      case 0:
        body = SingleChildScrollView(
          child: Column(children: [
            _genie(context, bt(lang, 'gnThink')),
            const SizedBox(height: 16),
            StudioPanel(
              margin: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(children: [
                Text(bt(lang, 'gnSuggest'), style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(genieEntityName(cat, suggestion, lang),
                    textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(bt(lang, 'gnOwn'), textAlign: TextAlign.center, style: const TextStyle(color: kStudioSubtle)),
              ]),
            ),
          ]),
        );
        buttons = [_bigBtn(context, bt(lang, 'start'), StudioLook.of(context).play, _step, icon: Icons.play_arrow_rounded)];
      case 1:
        body = _genie(context, genieQuestionText(g.base, q!, lang));
        buttons = [
          _bigBtn(context, bt(lang, 'gnYes'), const Color(0xFF3E8E5E), () => _answer(1)),
          _bigBtn(context, bt(lang, 'gnNo'), const Color(0xFFB4523A), () => _answer(0), icon: Icons.close_rounded),
          _bigBtn(context, bt(lang, 'gnDk'), const Color(0xFF5C6FC4), () => _answer(-1), icon: Icons.help_outline_rounded),
        ];
      case 2:
        body = Column(children: [
          _genie(context, bt(lang, 'gnGuess')),
          const SizedBox(height: 12),
          Text(genieEntityName(cat, guessing!, lang),
              textAlign: TextAlign.center, style: const TextStyle(color: StudioLook.gold, fontSize: 28, fontWeight: FontWeight.w900)),
        ]);
        buttons = [
          _bigBtn(context, bt(lang, 'gnYes'), const Color(0xFF3E8E5E), () => _guessAnswer(true)),
          _bigBtn(context, bt(lang, 'gnNo'), const Color(0xFFB4523A), () => _guessAnswer(false), icon: Icons.close_rounded),
        ];
      default:
        body = _genie(context, found ? bt(lang, 'gnFound') : bt(lang, 'gnBeaten'));
        buttons = [_bigBtn(context, bt(lang, 'next'), StudioLook.of(context).play, _close, icon: Icons.arrow_forward_rounded)];
    }
    return Column(children: [
      top,
      Expanded(child: Center(child: body)),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Column(children: [for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 8), child: SizedBox(width: double.infinity, child: b))]),
      ),
    ]);
  }
}

// ================================================================ Halk Ne Dedi?

BLevel? _makeSurvey(BilgiKind k, int d, SeededRandom r) {
  final rounds = d <= 3 ? 3 : (d <= 7 ? 4 : 5);
  final qs = perm(kSvQ.length, r).take(rounds).toList();
  return BLevel(k.id, d, [for (final qi in qs) BQ(TplX.survey, [qi], perm(8, r), -1)]);
}

List<int> perm(int n, SeededRandom r) {
  final l = [for (var i = 0; i < n; i++) i];
  r.shuffle(l);
  return l;
}

bool _checkSurvey(BLevel lv) {
  if (lv.qs.length < 3 || lv.qs.length > 5) return false;
  final seen = <int>{};
  for (final q in lv.qs) {
    if (q.t != TplX.survey || q.a.length != 1) return false;
    final qi = q.a[0];
    if (qi < 0 || qi >= kSvQ.length || !seen.add(qi)) return false;
    if (q.o.length != 8 || q.o.toSet().length != 8 || q.o.any((x) => x < 0 || x > 7)) return false;
    final pts = kSvPts[qi];
    for (var i = 1; i < pts.length; i++) {
      if (pts[i] > pts[i - 1]) return false;
    }
  }
  return true;
}

class SurveyView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const SurveyView({super.key, required this.ctx, required this.level});
  @override
  State<SurveyView> createState() => _SurveyViewState();
}

class _SurveyViewState extends State<SurveyView> {
  final Stopwatch watch = Stopwatch()..start();
  int? teams; // 1 veya 2
  int round = 0, team = 0, strikes = 0, bank = 0;
  bool stealing = false, roundOver = false;
  final List<int> scores = [0, 0];
  Set<int> revealed = {};
  Set<int> wrong = {};
  int revealedTotal = 0;
  String banner = '';

  String get lang => widget.ctx.lang;
  BQ get q => widget.level.qs[round];
  int get qi => q.a[0];

  void _tap(int tile) {
    if (roundOver || revealed.contains(tile) || wrong.contains(tile)) return;
    final isAns = tile < 5;
    setState(() {
      if (isAns) {
        revealed.add(tile);
        revealedTotal++;
        bank += kSvPts[qi][tile];
        widget.ctx.sfx(Sfx.coin);
        if (stealing) {
          scores[1 - team] += bank;
          bank = 0;
          _endRound();
        } else if (revealed.length == 5) {
          scores[team] += bank;
          bank = 0;
          _endRound();
        }
      } else {
        wrong.add(tile);
        widget.ctx.sfx(Sfx.error);
        banner = bt(lang, 'svStrike');
        if (stealing) {
          scores[team] += bank;
          bank = 0;
          _endRound();
        } else {
          strikes++;
          if (strikes >= 3) {
            if (teams == 2) {
              stealing = true;
              banner = bt(lang, 'svSteal');
            } else {
              scores[0] += bank;
              bank = 0;
              _endRound();
            }
          }
        }
      }
    });
  }

  void _endRound() {
    roundOver = true;
    // Panonun tamamı gösterilir.
    revealed = {0, 1, 2, 3, 4};
  }

  void _next() {
    if (round + 1 >= widget.level.qs.length) return _finishGame();
    setState(() {
      round++;
      if (teams == 2) team = 1 - team;
      strikes = 0;
      bank = 0;
      stealing = false;
      roundOver = false;
      revealed = {};
      wrong = {};
      banner = '';
    });
  }

  void _finishGame() {
    final n = widget.level.qs.length;
    final frac = revealedTotal / (n * 5);
    final stars = frac >= 0.85 ? 3 : (frac >= 0.6 ? 2 : 1);
    String? head;
    if (teams == 2) {
      final t = bt(lang, 'svTeam');
      head = scores[0] == scores[1] ? bt(lang, 'draw') : bt(lang, 'wins', {'p': '$t ${scores[0] > scores[1] ? 'A' : 'B'}'});
    }
    _finish(widget.ctx, won: teams == 2 || frac >= 0.4, stars: stars, score: scores[0] + scores[1], seconds: watch.elapsed.inSeconds, right: revealedTotal, headline: head);
  }

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    if (teams == null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('📊', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(bt(lang, 'svTitle'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text(bt(lang, 'svNote'), textAlign: TextAlign.center, style: const TextStyle(color: kStudioSubtle)),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: _bigBtn(context, bt(lang, 'svOneTeam'), look.play, () => setState(() => teams = 1), icon: Icons.person)),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: _bigBtn(context, bt(lang, 'svTwoTeams'), const Color(0xFF5C6FC4), () => setState(() => teams = 2), icon: Icons.groups)),
          ]),
        ),
      );
    }
    final ans = kSvA[qi], dec = kSvD[qi], pts = kSvPts[qi];
    String tileText(int t) => Strings.pick(t < 5 ? ans[t] : dec[t - 5], lang);
    final teamName = teams == 2 ? '${bt(lang, 'svTeam')} ${(stealing ? 1 - team : team) == 0 ? 'A' : 'B'}' : '';
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
        child: Row(children: [
          Text('${bt(lang, 'svRound')} ${round + 1}/${widget.level.qs.length}', style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (teams == 2) Text('A ${scores[0]} · B ${scores[1]}', style: TextStyle(color: look.number, fontWeight: FontWeight.w900, fontSize: 16)),
          if (teams == 1) Text('${scores[0]}', style: TextStyle(color: look.number, fontWeight: FontWeight.w900, fontSize: 16)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Text(Strings.pick(kSvQ[qi], lang), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      // Pano
      for (var i = 0; i < 5; i++)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: revealed.contains(i) ? const Color(0xFF2E5FA8) : const Color(0xFF1B2B4A),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFF2B53A), width: 1.2),
          ),
          child: Row(children: [
            Text('${i + 1}', style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(revealed.contains(i) ? tileText(i) : '•••',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            Text(revealed.contains(i) ? '${pts[i]}' : '', style: const TextStyle(color: Color(0xFFFFE08A), fontWeight: FontWeight.w900)),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
        child: Row(children: [
          Text('✗' * strikes, style: const TextStyle(color: Color(0xFFFF7A6B), fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(banner.isEmpty ? (teams == 2 ? '$teamName · ${bt(lang, 'svPick')}' : bt(lang, 'svPick')) : banner,
                maxLines: 2, style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      Expanded(
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(12),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 3.2,
          children: [
            for (final t in q.o)
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: wrong.contains(t)
                      ? const Color(0xFF7A2E25)
                      : (revealed.contains(t) && t < 5 ? const Color(0xFF2E6B47) : Color.lerp(look.card, look.accent, 0.3)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: roundOver ? null : () => _tap(t),
                child: Text(tileText(t), maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
      if (roundOver)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: SizedBox(width: double.infinity, child: _bigBtn(context, bt(lang, 'next'), look.play, _next, icon: Icons.arrow_forward_rounded)),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Text(bt(lang, 'svNote'), textAlign: TextAlign.center, style: const TextStyle(color: kStudioSubtle, fontSize: 11)),
      ),
    ]);
  }
}

// ================================================================ Bilgi Merdiveni

/// Merdivende kullanılan çoktan seçmeli şablonlar.
const List<int> kLadderTpl = [
  Tpl.cap, Tpl.cont, Tpl.area, Tpl.z2s, Tpl.s2z, Tpl.cat, Tpl.gas, Tpl.planetN, Tpl.planetBig, Tpl.unit, //
  Tpl.cls, Tpl.eggs, Tpl.sea, Tpl.biggest, Tpl.herb, Tpl.carn, Tpl.year, Tpl.first, Tpl.bigger, Tpl.dish, //
  Tpl.spOly, Tpl.spCup, Tpl.spRule, Tpl.spcFact, Tpl.spcMoon, Tpl.artPaint, Tpl.artBook, Tpl.artMove,
];

/// Basamak puanları; 5. ve 10. basamak güvenlidir.
const List<int> kLadderPts = [100, 200, 300, 400, 500, 700, 900, 1200, 1500, 2000, 2500, 3000, 4000, 5000, 7500];
const int kLadderSteps = 15, kLadderSpare = 3;

int ladderD(int d, int i) => clampI(1 + (d - 1) ~/ 3 + (i * 2) ~/ 3, 1, 10);

BLevel? _makeLadder(BilgiKind k, int d, SeededRandom r) {
  final qs = <BQ>[];
  final seen = <String>{};
  var lastT = -1;
  for (var g = 0; g < 2000 && qs.length < kLadderSteps + kLadderSpare; g++) {
    final i = qs.length < kLadderSteps ? qs.length : kLadderSteps - 3 + (qs.length - kLadderSteps);
    final t = r.pick(kLadderTpl);
    if (t == lastT) continue;
    BQ? q;
    try {
      q = kGens[t](ladderD(d, i), r);
    } catch (_) {
      q = null;
    }
    if (q == null || !checkQ(q) || q.mode != QMode.choice || q.o.length < 3 || q.ans < 0) continue;
    if (!seen.add(subjectKey(q))) continue;
    qs.add(q);
    lastT = t;
  }
  return qs.length == kLadderSteps + kLadderSpare ? BLevel(k.id, d, qs) : null;
}

bool _checkLadder(BLevel lv) {
  if (lv.qs.length != kLadderSteps + kLadderSpare) return false;
  final seen = <String>{};
  for (final q in lv.qs) {
    if (!checkQ(q) || q.mode != QMode.choice || q.o.length < 3 || q.ans < 0 || q.ans >= q.o.length) return false;
    if (!seen.add(subjectKey(q))) return false;
  }
  return true;
}

class LadderView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const LadderView({super.key, required this.ctx, required this.level});
  @override
  State<LadderView> createState() => _LadderViewState();
}

class _LadderViewState extends State<LadderView> {
  final Stopwatch watch = Stopwatch()..start();
  int step = 0, spare = 0, chosen = -1;
  late List<BQ> qs = widget.level.qs.take(kLadderSteps).toList();
  bool fifty = true, table = true, swap = true;
  Set<int> hidden = {};
  List<int>? poll;
  bool answered = false, over = false;
  int lifelines = 0;

  String get lang => widget.ctx.lang;
  BQ get q => qs[step];
  int get secured => step >= 10 ? kLadderPts[9] : (step >= 5 ? kLadderPts[4] : 0);

  void _choose(int i) {
    if (answered || over || hidden.contains(i)) return;
    setState(() {
      chosen = i;
      answered = true;
    });
    final ok = i == q.ans;
    widget.ctx.sfx(ok ? Sfx.coin : Sfx.error);
    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (!ok) return _end(secured, fell: true);
      if (step + 1 >= kLadderSteps) return _end(kLadderPts.last);
      setState(() {
        step++;
        chosen = -1;
        answered = false;
        hidden = {};
        poll = null;
      });
    });
  }

  void _end(int pts, {bool fell = false}) {
    if (over) return;
    over = true;
    final reached = fell ? (step >= 10 ? 10 : (step >= 5 ? 5 : 0)) : (pts == kLadderPts.last ? 15 : step);
    final stars = reached >= 15 ? 3 : (reached >= 10 ? 2 : 1);
    _finish(widget.ctx,
        won: reached >= 5,
        stars: stars,
        score: pts,
        seconds: watch.elapsed.inSeconds,
        right: fell ? step : step + (pts == kLadderPts.last ? 1 : 0),
        hints: lifelines,
        headline: '${bt(lang, 'ldReached')}: $reached/15 · $pts ${bt(lang, 'ldPoints')}');
  }

  void _walk() {
    if (answered || over) return;
    _end(step == 0 ? 0 : kLadderPts[step - 1]);
  }

  void _useFifty() {
    if (!fifty || answered) return;
    final wrong = [for (var i = 0; i < q.o.length; i++) if (i != q.ans) i];
    wrong.shuffle(math.Random(step * 13 + widget.ctx.spec.seed));
    setState(() {
      fifty = false;
      lifelines++;
      hidden = wrong.take(q.o.length >= 4 ? 2 : 1).toSet();
    });
  }

  void _useTable() {
    if (!table || answered) return;
    final r = math.Random(step * 31 + widget.ctx.spec.seed);
    final n = q.o.length;
    // Masa kolay basamaklarda çoğunlukla haklıdır, zorlaştıkça kararsızlaşır.
    final sure = 0.75 - step * 0.035;
    final votes = List<double>.filled(n, 0);
    for (var i = 0; i < n; i++) {
      if (hidden.contains(i)) continue;
      votes[i] = r.nextDouble() * (1 - sure);
    }
    votes[q.ans] += sure;
    final sum = votes.fold<double>(0, (a, b) => a + b);
    setState(() {
      table = false;
      lifelines++;
      poll = [for (final v in votes) (v / sum * 100).round()];
    });
  }

  void _useSwap() {
    if (!swap || answered || spare >= kLadderSpare) return;
    setState(() {
      swap = false;
      lifelines++;
      qs = [...qs]..[step] = widget.level.qs[kLadderSteps + spare];
      spare++;
      hidden = {};
      poll = null;
    });
  }

  Widget _life(String label, IconData icon, bool on, VoidCallback f) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: BorderSide(color: on ? StudioLook.gold : Colors.white24)),
            onPressed: on && !answered ? f : null,
            icon: Icon(icon, size: 18),
            label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final text = renderQ(q, lang);
    final vis = visualOf(q);
    return Column(children: [
      // Basamak şeridi
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          itemCount: kLadderSteps,
          itemBuilder: (_, i) => Container(
            width: 34,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: i == step ? StudioLook.gold : (i < step ? const Color(0xFF2E6B47) : Colors.white10),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: i == 4 || i == 9 ? StudioLook.gold : Colors.white24, width: i == 4 || i == 9 ? 2 : 1),
            ),
            child: Text('${i + 1}', style: TextStyle(color: i == step ? const Color(0xFF22303F) : Colors.white, fontWeight: FontWeight.w900)),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Text('${bt(lang, 'ldStep')} ${step + 1} · ${kLadderPts[step]} ${bt(lang, 'ldPoints')}',
              style: TextStyle(color: look.number, fontWeight: FontWeight.w900)),
          const Spacer(),
          if (secured > 0) Text('${bt(lang, 'ldSafe')}: $secured', style: const TextStyle(color: kStudioSubtle, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(text.prompt, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
      ),
      if (vis != QVisual.none) Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(6), child: QuestionVisual(q: q, lang: lang))),
      Expanded(
        flex: 4,
        child: ListView(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), children: [
          for (var i = 0; i < text.options.length; i++)
            Opacity(
              opacity: hidden.contains(i) ? 0.15 : 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Material(
                  color: answered && i == q.ans
                      ? const Color(0xFF2E6B47)
                      : (answered && i == chosen ? const Color(0xFF7A2E25) : Color.lerp(look.card, Colors.white, 0.08)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14), side: BorderSide(color: i == chosen ? StudioLook.gold : Colors.white24, width: i == chosen ? 2 : 1)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _choose(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(children: [
                        Text(String.fromCharCode(65 + i), style: const TextStyle(color: StudioLook.gold, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(text.options[i], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
                        if (poll != null) Text('${poll![i]}%', style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w800)),
                      ]),
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 4),
        child: Row(children: [
          _life('50:50', Icons.filter_2_rounded, fifty, _useFifty),
          _life(bt(lang, 'ldTable'), Icons.groups_rounded, table, _useTable),
          _life(bt(lang, 'ldSwap'), Icons.swap_horiz_rounded, swap, _useSwap),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: kStudioSubtle),
            onPressed: answered || over ? null : _walk,
            icon: const Icon(Icons.flag_rounded),
            label: Text('${bt(lang, 'ldWalk')} (${step == 0 ? 0 : kLadderPts[step - 1]})'),
          ),
        ),
      ),
    ]);
  }
}

// ================================================================ Ülke Silüeti

bool hasShape(int c) => c >= 0 && c < kShapes.length && kShapes[c].length >= 9;

/// Silüetten tahmin edilecek aday ülkeler (zorluk arttıkça küçükler de girer).
List<int> shapePool(int d) => [
      for (var i = 0; i < kCountries.length; i++)
        if (hasShape(i) && kCountries[i].area >= (d <= 2 ? 500000 : (d <= 5 ? 100000 : (d <= 8 ? 20000 : 3000)))) i
    ];

BLevel? _makeShape(BilgiKind k, int d, SeededRandom r) {
  final pool = shapePool(d);
  if (pool.length < 6) return null;
  final target = r.pick(pool);
  final mode = d <= 3 ? 0 : 1;
  var opts = <int>[];
  var ans = -1;
  if (mode == 0) {
    // Seçenekler: hedefle aynı kıtadan olanlar önce (daha öğretici).
    final same = [for (final c in pool) if (c != target && kCountries[c].cont == kCountries[target].cont) c];
    final other = [for (final c in pool) if (c != target && kCountries[c].cont != kCountries[target].cont) c];
    r.shuffle(same);
    r.shuffle(other);
    opts = [target, ...same.take(3), ...other].take(6).toList();
    r.shuffle(opts);
    ans = opts.indexOf(target);
  }
  return BLevel(k.id, d, [BQ(TplX.shape, [target, mode, 6], opts, ans)]);
}

bool _checkShape(BLevel lv) {
  if (lv.qs.length != 1) return false;
  final q = lv.qs.first;
  if (q.t != TplX.shape || q.a.length != 3 || !hasShape(q.a[0])) return false;
  if (q.a[2] < 3 || q.a[2] > 8) return false;
  if (q.a[1] == 0) {
    return q.o.length == 6 && q.o.toSet().length == 6 && q.o.every(hasShape) && q.ans >= 0 && q.o[q.ans] == q.a[0];
  }
  return q.a[1] == 1 && q.o.isEmpty;
}

/// Pusula yönü (derece, kuzey 0, doğu 90).
double bearingDeg(double lat1, double lon1, double lat2, double lon2) {
  final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180, dl = (lon2 - lon1) * math.pi / 180;
  final y = math.sin(dl) * math.cos(p2);
  final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

class ShapePainter extends CustomPainter {
  final int country;
  final Color color;
  ShapePainter(this.country, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final f = kShapes[country];
    final s = math.min(size.width, size.height) / 1000;
    // Silüeti kutuda ortala.
    var maxX = 0, maxY = 0;
    for (var i = 0; i < f.length;) {
      final n = f[i];
      for (var k = 0; k < n; k++) {
        maxX = math.max(maxX, f[i + 1 + 2 * k]);
        maxY = math.max(maxY, f[i + 2 + 2 * k]);
      }
      i += 1 + 2 * n;
    }
    final ox = (size.width - maxX * s) / 2, oy = (size.height - maxY * s) / 2;
    final path = Path();
    for (var i = 0; i < f.length;) {
      final n = f[i];
      for (var k = 0; k < n; k++) {
        final p = Offset(ox + f[i + 1 + 2 * k] * s, oy + f[i + 2 + 2 * k] * s);
        if (k == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      i += 1 + 2 * n;
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant ShapePainter old) => old.country != country || old.color != color;
}

class ShapeView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const ShapeView({super.key, required this.ctx, required this.level});
  @override
  State<ShapeView> createState() => _ShapeViewState();
}

class _ShapeViewState extends State<ShapeView> {
  final Stopwatch watch = Stopwatch()..start();
  late final BQ spec = widget.level.qs.first;
  late final int target = spec.a[0];
  late final int maxG = spec.a[2];
  final List<int> guesses = [];
  final TextEditingController ctl = TextEditingController();
  String query = '';
  bool over = false, won = false;

  String get lang => widget.ctx.lang;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  void _guess(int c) {
    if (over || guesses.contains(c)) return;
    setState(() {
      guesses.add(c);
      ctl.clear();
      query = '';
      if (c == target) {
        over = true;
        won = true;
        widget.ctx.sfx(Sfx.win);
      } else {
        widget.ctx.sfx(Sfx.error);
        if (guesses.length >= maxG) over = true;
      }
    });
  }

  void _done() {
    final n = guesses.length;
    _finish(widget.ctx,
        won: won,
        stars: won ? (n == 1 ? 3 : (n <= 3 ? 2 : 1)) : 1,
        score: won ? (maxG - n + 1) * 100 : 0,
        seconds: watch.elapsed.inSeconds,
        right: won ? 1 : 0,
        headline: won ? null : '${bt(lang, 'slAnswer')}: ${countryName(target, lang)}');
  }

  List<int> get suggestions {
    final s = query.trim().toLowerCase();
    if (s.isEmpty) return const [];
    final out = <int>[];
    for (var i = 0; i < kCountries.length && out.length < 6; i++) {
      if (!hasShape(i) || guesses.contains(i)) continue;
      final a = countryName(i, lang).toLowerCase();
      final b = Strings.pick(kCountryNames[i], 'en').toLowerCase();
      if (a.contains(s) || b.contains(s)) out.add(i);
    }
    return out;
  }

  Widget _guessRow(int c) {
    final t = kCountries[target], g = kCountries[c];
    final ok = c == target;
    final km = haversineKm(g.lat, g.lon, t.lat, t.lon).round();
    final dir = bearingDeg(g.lat, g.lon, t.lat, t.lon);
    final prox = ok ? 100 : (100 - km / 200).clamp(0, 99).round();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: ok ? const Color(0xFF2E6B47) : Colors.white10, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(countryName(c, lang), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
        if (!ok) Text('$km km', style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        if (!ok) Transform.rotate(angle: dir * math.pi / 180, child: const Icon(Icons.north_rounded, color: StudioLook.gold, size: 22)),
        const SizedBox(width: 8),
        Text('$prox%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    final mode = spec.a[1];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
        child: Row(children: [
          Expanded(child: Text(bt(lang, 'slWhich'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900))),
          Text('${bt(lang, 'slTries')}: ${maxG - guesses.length}', style: const TextStyle(color: kStudioSubtle, fontWeight: FontWeight.w800)),
        ]),
      ),
      Expanded(
        flex: 5,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.all(16),
            child: CustomPaint(painter: ShapePainter(target, over && !won ? StudioLook.bad : Colors.white), child: const SizedBox.expand()),
          ),
        ),
      ),
      if (over)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('${bt(lang, 'slAnswer')}: ${countryName(target, lang)}',
              textAlign: TextAlign.center, style: const TextStyle(color: StudioLook.gold, fontSize: 20, fontWeight: FontWeight.w900)),
        ),
      Expanded(
        flex: 4,
        child: ListView(children: [
          for (final c in guesses) _guessRow(c),
          if (!over && mode == 1) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: TextField(
                controller: ctl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: bt(lang, 'slSearch'),
                  hintStyle: const TextStyle(color: kStudioSubtle),
                  prefixIcon: const Icon(Icons.search, color: kStudioSubtle),
                  filled: true,
                  fillColor: Colors.white10,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onChanged: (v) => setState(() => query = v),
              ),
            ),
            for (final c in suggestions)
              ListTile(
                dense: true,
                title: Text(countryName(c, lang), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                trailing: const Icon(Icons.add_circle_outline, color: kStudioSubtle),
                onTap: () => _guess(c),
              ),
          ],
          if (!over && mode == 0)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                for (final c in spec.o)
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: guesses.contains(c) ? const Color(0xFF7A2E25) : Color.lerp(look.card, look.accent, 0.3),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: guesses.contains(c) ? null : () => _guess(c),
                    child: Text(countryName(c, lang), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
              ]),
            ),
        ]),
      ),
      if (over)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: SizedBox(width: double.infinity, child: _bigBtn(context, bt(lang, 'next'), look.play, _done, icon: Icons.arrow_forward_rounded)),
        ),
    ]);
  }
}
