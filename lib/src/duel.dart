import 'dart:async';

import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';

import 'core.dart';
import 'quiz.dart';
import 'stage.dart';
import 'texts.dart';

/// İki kişilik yüz yüze düello: telefon ortada, üst yarı ters döner.
/// İki oyuncu aynı soruyu görür; ilk doğru dokunan puanı alır, yanlış
/// dokunan o soruda bekler.
class DuelView extends StatefulWidget {
  final PlayContext ctx;
  final BLevel level;
  const DuelView({super.key, required this.ctx, required this.level});

  @override
  State<DuelView> createState() => _DuelViewState();
}

class _DuelViewState extends State<DuelView> {
  bool started = false, over = false, sent = false;
  int idx = 0;
  final List<int> pts = [0, 0];
  final List<int?> tapped = [null, null];

  /// Soruyu kim aldı: 0/1 oyuncu, -1 kimse, null henüz değil.
  int? winner;
  Timer? _t;
  Timer? _limit;
  final Stopwatch _watch = Stopwatch()..start();

  PlayContext get ctx => widget.ctx;
  String get lang => ctx.lang;
  BQ get q => widget.level.qs[idx];

  @override
  void dispose() {
    _t?.cancel();
    _limit?.cancel();
    super.dispose();
  }

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
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1500), _advance);
  }

  /// Kimse bilemezse soru 20 saniyede kapanır.
  void _arm() {
    _limit?.cancel();
    _limit = Timer(const Duration(seconds: 20), () {
      if (!mounted || winner != null || over) return;
      setState(() => winner = -1);
      _settle();
    });
  }

  void _advance() {
    if (!mounted) return;
    setState(() {
      if (idx + 1 >= widget.level.qs.length) {
        over = true;
      } else {
        idx++;
        tapped[0] = null;
        tapped[1] = null;
        winner = null;
        _arm();
      }
    });
  }

  void _finish() {
    if (sent) return;
    sent = true;
    final a = pts[0], b = pts[1];
    final head = a == b ? bt(lang, 'draw') : bt(lang, 'wins', {'p': '${bt(lang, 'player')} ${a > b ? 1 : 2}'});
    ctx.finish(RoundResult(
      won: true,
      score: (a > b ? a : b) * 100,
      stars: 3,
      seconds: _watch.elapsed.inSeconds,
      headline: head,
      gameStats: {'rounds_won': 1, 'answers_right': a + b},
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!started) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.people_alt_outlined, size: 64),
            const SizedBox(height: 12),
            Text(bt(lang, 'ready'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: () {
                  setState(() => started = true);
                  _arm();
                },
                child: Text(bt(lang, 'start'))),
          ]),
        ),
      );
    }
    if (over) {
      final a = pts[0], b = pts[1];
      final head = a == b ? bt(lang, 'draw') : bt(lang, 'wins', {'p': '${bt(lang, 'player')} ${a > b ? 1 : 2}'});
      return Column(children: [
        Expanded(child: RotatedBox(quarterTurns: 2, child: _score(context, 1, head))),
        const Divider(height: 2, thickness: 2),
        Expanded(child: _score(context, 0, head)),
      ]);
    }
    return Column(children: [
      Expanded(child: RotatedBox(quarterTurns: 2, child: _half(context, 1))),
      Container(height: 4, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
      Expanded(child: _half(context, 0)),
    ]);
  }

  Widget _score(BuildContext context, int player, String head) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(head, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('${pts[player]} – ${pts[1 - player]}', style: Theme.of(context).textTheme.displaySmall),
        const SizedBox(height: 12),
        FilledButton(onPressed: _finish, child: Text(bt(lang, 'next'))),
      ]),
    );
  }

  Widget _half(BuildContext context, int player) {
    final text = renderQ(q, lang);
    final scheme = Theme.of(context).colorScheme;
    final mine = tapped[player];
    final n = text.options.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(children: [
        Row(children: [
          Text('${bt(lang, 'player')} ${player + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('${idx + 1}/${widget.level.qs.length}'),
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
                      onTap: () => _tap(player, i),
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
