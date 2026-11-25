import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/rng.dart';

import 'core.dart';
import 'quiz.dart';
import 'stage.dart';
import 'texts.dart';

/// Çevrimiçi düello bağlantısı: her koltuğun soru yanıtları.
///
/// Hamle biçimi "A<soru>:<seçim>:<ms>" (seçim -1: süre doldu). Soru dizisi
/// maçın ortak tohumundan üretildiği için iki cihazda aynıdır; soru metni her
/// cihazda oyuncunun kendi dilinde gösterilir (bütün içerik 33 dilde).
class DuelNet {
  final MatchLink link;
  final int me;
  final int opp;
  final Map<int, (int, int)> mine = {};
  final Map<int, (int, int)> theirs = {};
  final List<VoidCallback> _ls = [];
  StreamSubscription<(int, String)>? _sub;

  DuelNet(this.link)
      : me = link.mySeat,
        opp = link.mySeat == 0 ? 1 : 0;

  /// Gerçek bir rakip varsa bağlantı; bot rakipte ya da çevrimdışında null.
  static DuelNet? of(PlayContext ctx) {
    final m = ctx.match;
    if (m == null) return null;
    final opp = m.mySeat == 0 ? 1 : 0;
    if (ctx.role(opp) != SeatRole.remote) return null;
    return DuelNet(m).._start();
  }

  /// "A<soru>:<seçim>:<ms>" → (soru, seçim, ms).
  static (int, int, int)? parse(String mv) {
    if (!mv.startsWith('A')) return null;
    final p = mv.substring(1).split(':');
    if (p.length != 3) return null;
    final q = int.tryParse(p[0]);
    final c = int.tryParse(p[1]);
    final ms = int.tryParse(p[2]);
    if (q == null || c == null || ms == null || q < 0 || ms < 0) return null;
    return (q, c, ms);
  }

  void _take(int seat, String mv) {
    final a = parse(mv);
    if (a == null) return;
    final target = seat == me ? mine : (seat == opp ? theirs : null);
    target?.putIfAbsent(a.$1, () => (a.$2, a.$3));
  }

  void _start() {
    for (final (s, mv) in link.history) {
      _take(s, mv);
    }
    _sub = link.moves.listen((e) {
      if (e.$1 == me) return;
      _take(e.$1, e.$2);
      for (final l in List.of(_ls)) {
        l();
      }
    });
  }

  /// Rakip bağlantıyı kopardı mı (artık bilgisayar yanıtlar).
  bool get oppGone => link.dropped.contains(opp);

  void answer(int q, int choice, int ms) {
    if (mine.containsKey(q)) return;
    mine[q] = (choice, ms);
    unawaited(link.send('A$q:$choice:$ms').catchError((Object _) {}));
  }

  void listen(VoidCallback f) => _ls.add(f);
  void unlisten(VoidCallback f) => _ls.remove(f);
  void finish(int winner) => unawaited(link.finish(winner, iWon: winner == me).catchError((Object _) {}));

  void dispose() {
    _sub?.cancel();
    _ls.clear();
  }
}

/// Bilgisayar rakibin bir soruya yanıtı (seçim, ms): tohumdan, iki cihazda aynı.
(int, int) duelBotAnswer(BQ q, int index, int d, int seed) {
  final r = SeededRandom(mixSeed([seed, index, 7717]));
  final n = renderQ(q, 'en').options.length;
  final right = r.chance(clampD(0.45 + d * 0.04, 0.3, 0.9));
  var c = q.ans;
  if (!right && n > 1) {
    c = r.nextInt(n - 1);
    if (c >= q.ans) c++;
  }
  final ms = 2500 + r.nextInt(6500 - d * 300);
  return (c, ms);
}

/// Bir sorunun kazananı: en erken doğru yanıt (eşitlikte küçük koltuk), yoksa -1.
int duelWinner(BQ q, (int, int) a0, (int, int) a1) {
  final ok0 = a0.$1 == q.ans, ok1 = a1.$1 == q.ans;
  if (ok0 && ok1) return a0.$2 <= a1.$2 ? 0 : 1;
  if (ok0) return 0;
  if (ok1) return 1;
  return -1;
}

enum _Mode { face, bot, online }

/// İki kişilik düello. Üç biçim: yüz yüze (telefon ortada, üst yarı ters),
/// bilgisayara karşı ve çevrimiçi. İlk doğru yanıtlayan puanı alır.
class DuelView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const DuelView({super.key, required this.ctx, required this.level});

  @override
  State<DuelView> createState() => _DuelViewState();
}

class _DuelViewState extends State<DuelView> {
  static const _limitSec = 20;
  bool started = false, over = false, sent = false;
  _Mode mode = _Mode.face;
  int idx = 0;
  final List<int> pts = [0, 0];
  final List<int?> tapped = [null, null];

  /// Soruyu kim aldı: 0/1 koltuk, -1 kimse, null henüz değil.
  int? winner;
  Timer? _t;
  Timer? _limit;
  Timer? _bot;
  Timer? _tick;
  final Stopwatch _watch = Stopwatch()..start();
  final Stopwatch _q = Stopwatch();

  /// Tek ekranlı biçimlerde (bot, çevrimiçi) koltukların yanıtları.
  final Map<int, (int, int)> _a0 = {}, _a1 = {};
  DuelNet? net;
  int me = 0;
  int get opp => 1 - me;

  PlayContext get ctx => widget.ctx;
  String get lang => ctx.lang;
  BQ get q => widget.level.qs[idx];
  int get total => widget.level.qs.length;
  Map<int, (int, int)> _ans(int seat) => seat == 0 ? _a0 : _a1;

  @override
  void initState() {
    super.initState();
    final n = DuelNet.of(ctx);
    if (n != null) {
      net = n;
      me = n.me;
      mode = _Mode.online;
      started = true;
      n.listen(_onNet);
      _replay();
      if (!over) _beginQ();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) => _checkGone());
    } else if (ctx.match != null) {
      // Çevrimiçi masada bot rakip: bilgisayara karşı gibi oynanır.
      me = ctx.match!.mySeat;
      mode = _Mode.bot;
      started = true;
      _beginQ();
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    _limit?.cancel();
    _bot?.cancel();
    _tick?.cancel();
    net?.unlisten(_onNet);
    net?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- yüz yüze

  void _tap(int player, int i) {
    if (!started || over || winner != null || tapped[player] != null) return;
    setState(() {
      tapped[player] = i;
      if (i == q.ans) {
        winner = player;
        pts[player]++;
        ctx.sfx(Sfx.coin);
      } else {
        ctx.sfx(Sfx.error);
        if (tapped[1 - player] != null) winner = -1;
      }
    });
    if (winner != null) _settle();
  }

  /// Soru bitti: kısa bir an doğru yanıtı göster, sonra geç.
  void _settle() {
    _limit?.cancel();
    _bot?.cancel();
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1500), _advance);
  }

  /// Kimse bilemezse soru 20 saniyede kapanır.
  void _arm() {
    _limit?.cancel();
    _limit = Timer(const Duration(seconds: _limitSec), () {
      if (!mounted || winner != null || over) return;
      setState(() => winner = -1);
      _settle();
    });
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      if (idx + 1 >= total) {
        over = true;
        _endMatch();
      } else {
        idx++;
        tapped[0] = null;
        tapped[1] = null;
        winner = null;
        if (mode == _Mode.face) {
          _arm();
        } else {
          _beginQ();
        }
      }
    });
  }

  // ------------------------------------------------------ bot ve çevrimiçi

  /// Maça geri dönüldüyse iki tarafın da yanıtladığı soruları yeniden işle.
  void _replay() {
    final n = net;
    if (n == null) return;
    _a0.clear();
    _a1.clear();
    n.mine.forEach((k, v) => _ans(me)[k] = v);
    n.theirs.forEach((k, v) => _ans(opp)[k] = v);
    while (idx < total && _a0.containsKey(idx) && _a1.containsKey(idx)) {
      final w = duelWinner(q, _a0[idx]!, _a1[idx]!);
      if (w >= 0) pts[w]++;
      idx++;
    }
    if (idx >= total) {
      over = true;
      _endMatch();
    }
  }

  void _beginQ() {
    _q
      ..reset()
      ..start();
    final mine = _ans(me)[idx];
    if (mine != null) tapped[me] = mine.$1;
    _limit?.cancel();
    if (mine == null) {
      final i = idx;
      _limit = Timer(const Duration(seconds: _limitSec), () {
        if (mounted && idx == i && !over) _myAnswer(-1);
      });
    }
    _armBot();
    _tryResolve();
  }

  /// Bilgisayar rakip (bot biçiminde ya da çevrimiçi rakip kopunca) zamanı gelince yanıtlar.
  void _armBot() {
    _bot?.cancel();
    final botTurn = mode == _Mode.bot || (net?.oppGone ?? false);
    if (!botTurn || _ans(opp).containsKey(idx)) return;
    final i = idx;
    final b = duelBotAnswer(q, i, widget.level.d, ctx.spec.seed);
    final wait = b.$2 - _q.elapsedMilliseconds;
    _bot = Timer(Duration(milliseconds: wait < 0 ? 0 : wait), () {
      if (!mounted || idx != i || over || winner != null) return;
      setState(() {
        _ans(opp)[i] = b;
        tapped[opp] = b.$1;
        // Bilgisayar önce doğru bildiyse soru onundur (yüz yüzedeki gibi).
        if (mode == _Mode.bot && b.$1 == q.ans && !_ans(me).containsKey(i)) {
          _ans(me)[i] = (-1, b.$2 + 1);
        }
        _tryResolve();
      });
    });
  }

  void _checkGone() {
    if (!mounted || over || winner != null) return;
    if ((net?.oppGone ?? false) && !_ans(opp).containsKey(idx) && !(_bot?.isActive ?? false)) {
      _armBot();
    }
  }

  void _onNet() {
    final n = net;
    if (n == null || !mounted) return;
    setState(() {
      n.theirs.forEach((k, v) => _ans(opp).putIfAbsent(k, () => v));
      _tryResolve();
    });
  }

  void _myAnswer(int choice) {
    if (over || winner != null || _ans(me).containsKey(idx)) return;
    final ms = _q.elapsedMilliseconds;
    setState(() {
      _ans(me)[idx] = (choice, ms);
      tapped[me] = choice;
      net?.answer(idx, choice, ms);
      ctx.sfx(choice == q.ans ? Sfx.tap : Sfx.error);
      if (mode == _Mode.bot || (net?.oppGone ?? false)) {
        // Bilgisayarın yanıtı tohumdan bellidir: süre karşılaştırması hemen yapılır.
        _bot?.cancel();
        final b = duelBotAnswer(q, idx, widget.level.d, ctx.spec.seed);
        _ans(opp).putIfAbsent(idx, () => b);
        tapped[opp] = _ans(opp)[idx]!.$1;
      }
      _tryResolve();
    });
  }

  /// İki yanıt da geldiyse soruyu sonuçlandır.
  void _tryResolve() {
    if (winner != null || over) return;
    final a = _a0[idx], b = _a1[idx];
    if (a == null || b == null) return;
    tapped[0] = a.$1;
    tapped[1] = b.$1;
    final w = duelWinner(q, a, b);
    winner = w;
    if (w >= 0) pts[w]++;
    ctx.sfx(w == me ? Sfx.coin : Sfx.error);
    _settle();
  }

  void _endMatch() {
    _limit?.cancel();
    _bot?.cancel();
    final n = net;
    if (n != null) {
      final m = pts[me], o = pts[opp];
      n.finish(m > o ? me : (m < o ? opp : -1));
    }
  }

  String _headline() {
    final a = pts[0], b = pts[1];
    if (mode == _Mode.face) {
      return a == b ? bt(lang, 'draw') : bt(lang, 'wins', {'p': '${bt(lang, 'player')} ${a > b ? 1 : 2}'});
    }
    final m = pts[me], o = pts[opp];
    return m == o ? bt(lang, 'draw') : bt(lang, 'wins', {'p': m > o ? bt(lang, 'you') : _oppName});
  }

  String get _oppName {
    final m = ctx.match;
    if (m != null && opp < m.names.length && m.names[opp].isNotEmpty) return m.names[opp];
    return bt(lang, 'rival');
  }

  void _finish() {
    if (sent) return;
    sent = true;
    final face = mode == _Mode.face;
    final my = face ? (pts[0] > pts[1] ? pts[0] : pts[1]) : pts[me];
    ctx.finish(RoundResult(
      won: face || pts[me] >= pts[opp],
      score: my * 100,
      stars: face ? 3 : (pts[me] > pts[opp] ? 3 : (pts[me] == pts[opp] ? 2 : 1)),
      seconds: _watch.elapsed.inSeconds,
      headline: _headline(),
      gameStats: {'rounds_won': face || pts[me] >= pts[opp] ? 1 : 0, 'answers_right': face ? pts[0] + pts[1] : pts[me]},
    ));
  }

  // ---------------------------------------------------------------- ekran

  @override
  Widget build(BuildContext context) {
    if (!started) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_alt_outlined, size: 64),
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('duel-bot'),
              icon: const Icon(Icons.smart_toy_rounded),
              onPressed: () => setState(() {
                mode = _Mode.bot;
                started = true;
                _beginQ();
              }),
              label: Text(bt(lang, 'vsBot')),
            ),
            const SizedBox(height: 20),
            Text(bt(lang, 'ready'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('duel-face'),
              icon: const Icon(Icons.people_alt_rounded),
              onPressed: () {
                setState(() {
                  mode = _Mode.face;
                  started = true;
                });
                _arm();
              },
              label: Text(bt(lang, 'face')),
            ),
          ]),
        ),
      );
    }
    if (over) {
      final head = _headline();
      if (mode != _Mode.face) return _score(context, me, head);
      return Column(children: [
        Expanded(child: RotatedBox(quarterTurns: 2, child: _score(context, 1, head))),
        const Divider(height: 2, thickness: 2),
        Expanded(child: _score(context, 0, head)),
      ]);
    }
    if (mode != _Mode.face) return _single(context);
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: _half(context, 1))),
      Container(height: 4, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
      Expanded(child: _half(context, 0)),
    ]);
  }

  Widget _score(BuildContext context, int player, String head) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(head,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${pts[player]} – ${pts[1 - player]}', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 12),
        FilledButton(onPressed: _finish, child: Text(bt(lang, 'next'))),
      ]),
    );
  }

  /// Bilgisayara karşı ve çevrimiçi: tek kişilik ekran.
  Widget _single(BuildContext context) {
    final mine = _ans(me)[idx];
    final waiting = mine != null && winner == null;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(children: [
          Flexible(
            child: Text('${bt(lang, 'you')} ${pts[me]} – ${pts[opp]} $_oppName',
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 8),
          Text('${idx + 1}/$total'),
        ]),
      ),
      if (waiting)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(bt(lang, 'waitRival'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      Expanded(child: _half(context, me, single: true)),
    ]);
  }

  Widget _half(BuildContext context, int player, {bool single = false}) {
    final text = renderQ(q, lang);
    final scheme = Theme.of(context).colorScheme;
    final mine = tapped[player];
    final n = text.options.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(children: [
        if (!single)
          Row(children: [
            Text('${bt(lang, 'player')} ${player + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const Spacer(),
            Text('${idx + 1}/$total'),
            const SizedBox(width: 12),
            Text('${pts[player]} – ${pts[1 - player]}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ]),
        const SizedBox(height: 4),
        Text(text.prompt, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (visualOf(q) != QVisual.none)
          Expanded(flex: 2, child: Padding(padding: const EdgeInsets.all(4), child: QuestionVisual(q: q, lang: lang))),
        Expanded(
          flex: 3,
          child: LayoutBuilder(builder: (context, box) {
            final cols = n == 3 ? 3 : 2;
            final rows = (n / cols).ceil();
            final h = clampD((box.maxHeight - 8) / rows - 8, 40, 90);
            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: (box.maxWidth - (cols - 1) * 8) / cols,
                    height: h,
                    child: _DuelOption(
                      label: text.options[i],
                      emoji: q.emojiOptions,
                      color: winner != null && i == q.ans
                          ? const Color(0xFF4F9A6E)
                          : (mine == i ? const Color(0xFFC8553D) : scheme.surface),
                      dim: mine != null && mine != i && winner == null,
                      onTap: () => single ? _myAnswer(i) : _tap(player, i),
                    ),
                  ),
              ],
            );
          }),
        ),
      ]),
    );
  }
}

class _DuelOption extends StatelessWidget {
  final String label;
  final bool emoji;
  final Color color;
  final bool dim;
  final VoidCallback onTap;
  const _DuelOption({required this.label, required this.emoji, required this.color, required this.dim, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: dim ? 0.5 : 1,
      child: Material(
        color: color == scheme.surface ? color : color.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: scheme.outlineVariant)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                child: Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: emoji ? 36 : 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
