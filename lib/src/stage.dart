import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'core.dart';
import 'data/countries.dart';
import 'data/elements.dart';
import 'data/events.dart';
import 'data/animals.dart';
import 'data/provinces.dart';
import 'maps.dart';
import 'quiz.dart';
import 'quiz_ext.dart';
import 'data/extra.dart';
import 'texts.dart';
import 'studio_chrome.dart';

/// Yanıt sonrası durum.
class _Outcome {
  final bool right;
  final bool timeUp;

  /// Tahminde tam isabet.
  final bool perfect;

  /// Haritada dokunulan nokta ve uzaklık.
  final double? lat, lon, km;
  const _Outcome(this.right, {this.timeUp = false, this.perfect = false, this.lat, this.lon, this.km});
}

/// Tek kişilik bilgi yarışması ekranı: süre, can, seri, joker ve açıklama.
class QuizView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  final double timeScale;
  const QuizView({super.key, required this.ctx, required this.level, this.timeScale = 1.0});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int idx = 0, lives = 3, score = 0, streak = 0, best = 0, right = 0, mistakes = 0, streak5 = 0;
  int fifty = 1, skips = 1, times = 1, lifelinesUsed = 0;
  double left = 0, total = 1;
  Set<int> hidden = {};
  int? chosen;
  double estT = 0.5;
  double? estGuess;
  final List<int> picks = [];
  _Outcome? outcome;
  Timer? _tick;
  final Stopwatch _watch = Stopwatch()..start();
  bool finished = false;

  PlayContext get ctx => widget.ctx;
  String get lang => ctx.lang;
  BQ get q => widget.level.qs[idx];
  int get d => widget.level.d;

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  double _limitFor(BQ q) {
    final base = 24.0 - d;
    final extra = switch (q.mode) {
      QMode.mapWorld || QMode.mapTurkey => 8.0,
      QMode.order => 6.0 + q.o.length * 3,
      QMode.choice => q.longOptions ? 6.0 : 0.0,
      QMode.estimate => 6.0,
    };
    return math.max<double>(8.0, (base + extra) * widget.timeScale);
  }

  void _startQuestion() {
    hidden = {};
    chosen = null;
    estT = 0.5;
    estGuess = null;
    picks.clear();
    outcome = null;
    total = _limitFor(q);
    left = total;
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted || outcome != null) return;
      setState(() {
        left -= 0.1;
        if (left <= 0) {
          left = 0;
          _resolve(const _Outcome(false, timeUp: true));
        }
      });
    });
  }

  void _resolve(_Outcome o) {
    if (outcome != null) return;
    outcome = o;
    _tick?.cancel();
    if (o.right) {
      right++;
      streak++;
      best = math.max<int>(best, streak);
      if (streak == 5) streak5++;
      final bonus = (left / total * 50).round();
      score += ((100 + bonus) * (1 + math.min<int>(streak - 1, 9) / 10)).round();
      ctx.sfx(streak >= 3 ? Sfx.combo : Sfx.coin);
    } else {
      mistakes++;
      lives--;
      streak = 0;
      ctx.sfx(Sfx.error);
    }
  }

  void _choose(int i) {
    if (outcome != null || hidden.contains(i)) return;
    setState(() {
      chosen = i;
      _resolve(_Outcome(i == q.ans));
    });
  }

  void _tapMap(double lat, double lon) {
    if (outcome != null) return;
    final qq = q;
    setState(() {
      if (qq.t == Tpl.tapCountry) {
        final c = kCountries[qq.a[0]];
        final km = haversineKm(lat, lon, c.lat, c.lon);
        _resolve(_Outcome(km <= tapToleranceKm(qq.a[0], d), lat: lat, lon: lon, km: km));
      } else {
        final p = kProvinces[qq.a[0]];
        final km = haversineKm(lat, lon, p.lat, p.lon);
        // En yakın il merkezi hedefse ya da yeterince yakınsa doğru.
        var nearest = 0;
        var nd = double.infinity;
        for (var i = 0; i < kProvinces.length; i++) {
          final dd = haversineKm(lat, lon, kProvinces[i].lat, kProvinces[i].lon);
          if (dd < nd) {
            nd = dd;
            nearest = i;
          }
        }
        _resolve(_Outcome(nearest == qq.a[0] || km <= tapProvToleranceKm(d), lat: lat, lon: lon, km: km));
      }
    });
  }

  void _tapOrder(int i) {
    if (outcome != null) return;
    setState(() {
      final at = picks.indexOf(i);
      if (at >= 0) {
        picks.removeRange(at, picks.length);
      } else {
        picks.add(i);
        ctx.sfx(Sfx.tap);
        if (picks.length == q.o.length) _resolve(_Outcome(orderCorrect(q, picks)));
      }
    });
  }

  void _confirmEstimate() {
    if (outcome != null || q.mode != QMode.estimate) return;
    setState(() {
      final spec = estSpec(q);
      final g = spec.round(spec.at(estT));
      estGuess = g;
      final err = spec.error(g);
      _resolve(_Outcome(err <= spec.tol, perfect: err <= spec.tol / 3));
    });
  }

  Future<bool> _spend(int have) async {
    if (have > 0) return true;
    return ctx.requestHint();
  }

  Future<void> _useFifty() async {
    if (outcome != null || q.mode != QMode.choice || q.o.length < 3 || hidden.isNotEmpty) return;
    if (!await _spend(fifty)) return;
    if (!mounted) return;
    setState(() {
      if (fifty > 0) fifty--;
      lifelinesUsed++;
      final wrong = [for (var i = 0; i < q.o.length; i++) if (i != q.ans) i];
      wrong.shuffle(math.Random(idx * 31 + q.t));
      hidden = wrong.take(q.o.length >= 4 ? 2 : 1).toSet();
      ctx.sfx(Sfx.unlock);
    });
  }

  Future<void> _useSkip() async {
    if (outcome != null) return;
    if (!await _spend(skips)) return;
    if (!mounted) return;
    setState(() {
      if (skips > 0) skips--;
      lifelinesUsed++;
      _tick?.cancel();
      ctx.sfx(Sfx.unlock);
    });
    _next();
  }

  Future<void> _useTime() async {
    if (outcome != null) return;
    if (!await _spend(times)) return;
    if (!mounted) return;
    setState(() {
      if (times > 0) times--;
      lifelinesUsed++;
      left += 12;
      total = math.max<double>(total, left);
      ctx.sfx(Sfx.unlock);
    });
  }

  void _next() {
    if (finished) return;
    if (lives <= 0) {
      finished = true;
      ctx.finish(RoundResult(
        won: false,
        score: score,
        seconds: _watch.elapsed.inSeconds,
        gameStats: {'answers_right': right, if (streak5 > 0) 'streak_5': streak5},
      ));
      return;
    }
    if (idx + 1 >= widget.level.qs.length) {
      finished = true;
      final stars = mistakes == 0 && lifelinesUsed == 0 ? 3 : (mistakes <= 1 ? 2 : 1);
      ctx.finish(RoundResult(
        won: true,
        score: score + lives * 50,
        stars: stars,
        seconds: _watch.elapsed.inSeconds,
        hintsUsed: lifelinesUsed,
        gameStats: {
          'rounds_won': 1,
          'answers_right': right,
          if (mistakes == 0) 'perfect': 1,
          if (streak5 > 0) 'streak_5': streak5,
        },
      ));
      return;
    }
    setState(() {
      idx++;
      _startQuestion();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = renderQ(q, lang);
    final o = outcome;
    return Column(children: [
      _topBar(scheme),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: total <= 0 ? 0 : clampD(left / total, 0, 1),
            minHeight: 6,
            color: left / total < 0.25 ? StudioLook.bad : scheme.primary,
            backgroundColor: Colors.white.withValues(alpha: 0.15),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Text(text.prompt,
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      Expanded(child: _body(context, text)),
      if (o != null) _explainPanel(context, o) else _lifelines(scheme),
    ]);
  }

  Widget _topBar(ColorScheme scheme) {
    final n = widget.level.qs.length;
    final look = StudioLook.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: look.accent.withValues(alpha: 0.45), width: 1.2),
      ),
      child: Row(children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 2),
            child: Icon(i < lives ? Icons.favorite : Icons.favorite_border, size: 20, color: StudioLook.bad),
          ),
        const SizedBox(width: 10),
        Flexible(
          child: Text('${bt(lang, 'question')} ${idx + 1}/$n',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
        const Spacer(),
        if (streak >= 2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: StudioLook.gold.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StudioLook.gold.withValues(alpha: 0.7)),
            ),
            child: Text('${bt(lang, 'streak')} ×$streak', style: const TextStyle(fontWeight: FontWeight.w800, color: StudioLook.gold)),
          ),
        const SizedBox(width: 8),
        StudioStatChip(icon: Icons.star_rounded, color: StudioLook.gold, compact: true, text: '$score'),
      ]),
    );
  }

  Widget _body(BuildContext context, QText text) {
    switch (q.mode) {
      case QMode.mapWorld:
      case QMode.mapTurkey:
        return Padding(padding: const EdgeInsets.all(10), child: _mapAnswer());
      case QMode.order:
        return _orderList(context, text);
      case QMode.estimate:
        return _estimate(context);
      case QMode.choice:
        final vis = visualOf(q);
        return Column(children: [
          if (vis != QVisual.none)
            Expanded(
                flex: vis == QVisual.worldPin || vis == QVisual.turkeyPin ? 5 : 3,
                child: Padding(padding: const EdgeInsets.all(8), child: QuestionVisual(q: q, lang: lang))),
          Expanded(flex: vis == QVisual.none ? 1 : 4, child: _options(context, text)),
        ]);
    }
  }

  Widget _mapAnswer() {
    final qq = q;
    final o = outcome;
    final world = qq.mode == QMode.mapWorld;
    final marks = <MapMark>[];
    if (o != null) {
      final ol = o.lat, olon = o.lon;
      if (ol != null && olon != null) marks.add(MapMark(ol, olon, o.right ? StudioLook.good : StudioLook.bad));
      if (world) {
        final c = kCountries[qq.a[0]];
        final ring = tapToleranceKm(qq.a[0], d) / 111 * WorldProjection.k;
        marks.add(MapMark(c.lat, c.lon, const Color(0xFF3E6FB0), ring: ring, pin: false));
      } else {
        final p = kProvinces[qq.a[0]];
        marks.add(MapMark(p.lat, p.lon, const Color(0xFF3E6FB0), pin: false));
      }
    }
    return GeoMap(
      turkey: !world,
      marks: marks,
      onTap: o == null ? _tapMap : null,
      semantics: bt(lang, 'tapMap'),
    );
  }

  Widget _orderList(BuildContext context, QText text) {
    final scheme = Theme.of(context).colorScheme;
    final o = outcome;
    final sorted = [for (var i = 0; i < q.o.length; i++) i]..sort((a, b) => orderKey(q, a).compareTo(orderKey(q, b)));
    return ListView(padding: const EdgeInsets.fromLTRB(14, 6, 14, 6), children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(bt(lang, q.t == Tpl.order ? 'tapOrder' : 'tapInOrder'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
      ),
      for (var i = 0; i < q.o.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _OptionCard(
            selected: picks.contains(i),
            state: o == null ? 0 : (sorted.indexOf(i) == picks.indexOf(i) ? 1 : 2),
            onTap: () => _tapOrder(i),
            child: Row(children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: picks.contains(i) ? scheme.primary : scheme.surfaceContainerHighest,
                child: Text(picks.contains(i) ? '${picks.indexOf(i) + 1}' : '',
                    style: TextStyle(color: picks.contains(i) ? scheme.onPrimary : Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(text.options[i])),
              if (o != null) Text(' ${orderValue(q, i)}', style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
    ]);
  }

  Widget _estimate(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = estSpec(q);
    final o = outcome;
    final g = spec.round(spec.at(estT));
    final unit = spec.unit.isEmpty ? '' : ' ${spec.unit}';
    final truthPos = _clamp01(spec.posOf(spec.value));
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(
            child: Text('${spec.format(g)}$unit',
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, color: scheme.primary)),
          ),
          const SizedBox(height: 6),
          Slider(
            value: estT,
            onChanged: o == null ? (v) => setState(() => estT = v) : null,
          ),
          if (o != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: LayoutBuilder(builder: (context, box) {
                return SizedBox(
                  height: 18,
                  child: Stack(children: [
                    Positioned(
                      left: clampD(truthPos * box.maxWidth - 9, 0, math.max<double>(0, box.maxWidth - 18)),
                      child: const Icon(Icons.arrow_drop_up, size: 18, color: Color(0xFF4F9A6E)),
                    ),
                  ]),
                );
              }),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(children: [
              Text(spec.format(spec.round(spec.lo)), style: TextStyle(color: scheme.onSurfaceVariant)),
              const Spacer(),
              Text(spec.format(spec.round(spec.hi)), style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: o == null ? _confirmEstimate : null, child: Text(bt(lang, 'confirm'))),
          const SizedBox(height: 6),
          Text(bt(lang, 'estHint'), textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }

  Widget _options(BuildContext context, QText text) {
    final o = outcome;
    final n = text.options.length;
    int stateOf(int i) {
      if (o == null) return 0;
      if (i == q.ans) return 1;
      if (i == chosen) return 2;
      return 0;
    }

    Widget card(int i) {
      final label = text.options[i];
      Widget child;
      if (q.emojiOptions) {
        child = FittedBox(child: Text(label, style: const TextStyle(fontSize: 44)));
      } else if (q.elementOptions) {
        child = ElementTile(sym: label, compact: true);
      } else {
        child = Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600));
      }
      return Opacity(
        opacity: hidden.contains(i) ? 0.15 : 1,
        child: _OptionCard(
          state: stateOf(i),
          selected: chosen == i,
          onTap: hidden.contains(i) ? null : () => _choose(i),
          center: true,
          child: child,
        ),
      );
    }

    if (q.longOptions) {
      return ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 4), children: [
        for (var i = 0; i < n; i++) Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: SizedBox(height: 74, child: card(i))),
      ]);
    }
    return LayoutBuilder(builder: (context, box) {
      final cols = n <= 2 ? 2 : (n == 3 ? 3 : 2);
      final rows = (n / cols).ceil();
      final h = clampD((box.maxHeight - 16) / rows - 10, 52, 120);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < n; i++)
              SizedBox(width: (box.maxWidth - 24 - (cols - 1) * 10) / cols, height: h, child: card(i)),
          ],
        ),
      );
    });
  }

  Widget _lifelines(ColorScheme scheme) {
    final choice = q.mode == QMode.choice && q.o.length >= 3;
    Widget btn(String label, int count, VoidCallback? on) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: on,
              child: FittedBox(
                child: Row(children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (count == 0) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.play_circle_outline, size: 16)),
                ]),
              ),
            ),
          ),
        );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        child: Row(children: [
          btn(bt(lang, 'fifty'), fifty, choice && hidden.isEmpty ? _useFifty : null),
          btn(bt(lang, 'skip'), skips, _useSkip),
          btn(bt(lang, 'moreTime'), times, _useTime),
        ]),
      ),
    );
  }

  Widget _explainPanel(BuildContext context, _Outcome o) {
    final scheme = Theme.of(context).colorScheme;
    final good = o.right;
    final km = o.km;
    final head = good
        ? ((km != null && km < 60) || o.perfect ? bt(lang, 'perfectHit') : bt(lang, 'correct'))
        : (o.timeUp ? bt(lang, 'timeUp') : bt(lang, 'wrong'));
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: (good ? StudioLook.good : StudioLook.bad).withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: good ? StudioLook.good : StudioLook.bad),
        ),
        child: Row(children: [
          Icon(good ? Icons.check_circle : Icons.cancel, color: good ? StudioLook.good : StudioLook.bad),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(head, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (km != null) Text(bt(lang, 'away', {'d': km.round()}), style: TextStyle(color: scheme.onSurfaceVariant)),
              if (estGuess != null)
                Text(bt(lang, 'yourGuess', {'g': estSpec(q).format(estGuess!)}), style: TextStyle(color: scheme.onSurfaceVariant)),
              Text(explain(q, lang), maxLines: 6, overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 6),
          FilledButton(onPressed: _next, child: Text(bt(lang, 'next'))),
        ]),
      ),
    );
  }
}

/// Seçenek kartı: 0 normal, 1 doğru, 2 yanlış.
class _OptionCard extends StatelessWidget {
  final Widget child;
  final int state;
  final bool selected;
  final bool center;
  final VoidCallback? onTap;
  const _OptionCard({required this.child, this.state = 0, this.selected = false, this.center = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final look = StudioLook.of(context);
    // Onaylı tasarımın cevap kartı: yarı saydam, vurgu kenarlı; doğru yeşil,
    // yanlış kırmızı.
    final bg = switch (state) {
      1 => StudioLook.good.withValues(alpha: 0.24),
      2 => StudioLook.bad.withValues(alpha: 0.24),
      _ => selected ? look.accent.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.07),
    };
    final side = switch (state) {
      1 => StudioLook.good,
      2 => StudioLook.bad,
      _ => selected ? look.accent : look.accent.withValues(alpha: 0.45),
    };
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: side, width: state == 0 && !selected ? 1.2 : 2.4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: center ? Center(child: child) : child,
        ),
      ),
    );
  }
}

/// Periyodik tablo kutucuğu.
class ElementTile extends StatelessWidget {
  final String sym;
  final String top;
  final bool compact;
  const ElementTile({super.key, required this.sym, this.top = '', this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Color.lerp(scheme.surface, const Color(0xFF3A8D8C), 0.18),
          borderRadius: BorderRadius.circular(compact ? 10 : 16),
          border: Border.all(color: const Color(0xFF3A8D8C), width: 2),
        ),
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (top.isNotEmpty) Text(top, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(sym, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

/// Sorunun üstündeki görsel (harita, plaka, element, emoji, olay kartı...).
class QuestionVisual extends StatelessWidget {
  final BQ q;
  final String lang;
  const QuestionVisual({super.key, required this.q, required this.lang});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget card(Widget child) => Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: child,
          ),
        );
    switch (visualOf(q)) {
      case QVisual.worldPin:
        final c = kCountries[q.a[0]];
        return GeoMap(turkey: false, marks: [MapMark(c.lat, c.lon, StudioLook.bad)]);
      case QVisual.turkeyPin:
        final p = kProvinces[q.a[0]];
        return GeoMap(turkey: true, marks: [MapMark(p.lat, p.lon, StudioLook.bad)]);
      case QVisual.plate:
        return Center(child: FittedBox(child: PlateView(code: kProvinces[q.a[0]].plate)));
      case QVisual.element:
        return Center(child: ElementTile(sym: kElements[q.a[0]].sym, top: '?'));
      case QVisual.number:
        return Center(child: ElementTile(sym: '?', top: '${kElements[q.a[0]].z}'));
      case QVisual.emoji:
        return Center(child: FittedBox(child: Text(kAnimals[q.a[0]].emoji, style: const TextStyle(fontSize: 90))));
      case QVisual.event:
        return card(Text(eventText(kEvents[q.a[0]], lang),
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)));
      case QVisual.unit:
        final u = kUnits[q.a[0]];
        return card(FittedBox(child: Text('${u.$1} = ? ${u.$2}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800))));
      case QVisual.province:
        return card(Text(kProvinces[q.a[0]].name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)));
      case QVisual.dish:
        final x = kDishes[q.a[0]];
        return card(Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(child: Text(x.emoji, style: const TextStyle(fontSize: 64))),
          const SizedBox(height: 6),
          Text(dishName(q.a[0], lang), textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ]));
      case QVisual.none:
        return const SizedBox.shrink();
    }
  }
}

/// Sade bir plaka çizimi: mavi şerit ve iki haneli il kodu.
class PlateView extends StatelessWidget {
  final int code;
  const PlateView({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      height: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black87, width: 3),
      ),
      child: Row(children: [
        Container(
          width: 30,
          decoration: const BoxDecoration(
            color: Color(0xFF2E5E8C),
            borderRadius: BorderRadius.horizontal(left: Radius.circular(4)),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 6),
          child: const Text('TR', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        Expanded(
          child: Center(
            child: Text('${code.toString().padLeft(2, '0')}  ◦◦◦  ◦◦',
                style: const TextStyle(color: Colors.black, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 2)),
          ),
        ),
      ]),
    );
  }
}

double _clamp01(double v) => v.isNaN ? 0.5 : (v < 0 ? 0 : (v > 1 ? 1 : v));
