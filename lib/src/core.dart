import 'package:flutter/material.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/rng.dart';
import 'package:studio_core/core/stats.dart';

import 'duel.dart';
import 'quiz.dart';
import 'stage.dart';

/// Bir bilgi yarışması türü: hangi soru şablonlarından, kaç soru sorulacağı.
class BilgiKind {
  final String id;

  /// (şablon, ağırlık) çiftleri.
  final List<(int, int)> mix;

  /// Soru sayısı = [base] + zorluk / [per].
  final int base;
  final int per;

  /// İki kişilik düello ekranı mı?
  final bool duel;

  /// Soru başına süre çarpanı (hızlı turlar için < 1).
  final double timeScale;
  const BilgiKind(this.id, this.mix, {this.base = 6, this.per = 2, this.duel = false, this.timeScale = 1.0});

  int count(int d) => base + d ~/ per;
}

class BLevel {
  final String kind;
  final int d;
  final List<BQ> qs;
  const BLevel(this.kind, this.d, this.qs);
}

int clampI(int v, int lo, int hi) => v < lo ? lo : (v > hi ? hi : v);
double clampD(double v, double lo, double hi) => v < lo ? lo : (v > hi ? hi : v);

/// Bölüm kurulumu: karışımdan soru çeker, her soruyu denetler, konu tekrarını önler.
BLevel? makeLevel(BilgiKind k, int d, int seed) {
  final r = SeededRandom(mixSeed([seed, d, 4401]));
  final n = k.count(d);
  final weights = [for (final m in k.mix) m.$2];
  final qs = <BQ>[];
  final seen = <String>{};
  for (var g = 0; g < n * 60 && qs.length < n; g++) {
    final t = k.mix[r.weighted(weights)].$1;
    if (k.mix.length > 2 && qs.isNotEmpty && qs.last.t == t) continue;
    BQ? q;
    try {
      q = kGens[t](d, r);
    } catch (_) {
      q = null;
    }
    if (q == null || !checkQ(q)) continue;
    if (!seen.add(subjectKey(q))) continue;
    qs.add(q);
  }
  return qs.length == n ? BLevel(k.id, d, qs) : null;
}

BLevel realizeBilgi(BilgiKind k, int d, int seed) {
  for (var dd = d; dd >= 1; dd--) {
    for (var a = 0; a < 20; a++) {
      final lv = makeLevel(k, dd, mixSeed([seed, a]));
      if (lv != null) return lv;
    }
  }
  throw StateError('bilgi bölümü kurulamadı: ${k.id} $d');
}

class BilgiRules extends GameRules<BLevel> {
  @override
  final String gameId;
  final BilgiKind kind;
  final int levels;
  BilgiRules({required this.gameId, required this.kind, this.levels = 100000});

  @override
  int get levelCount => levels;

  /// Düello türünde 2: merkez "Bilgisayara karşı" ve "Çevrimiçi masa" sunar.
  @override
  int get localPlayers => kind.duel ? 2 : 0;

  @override
  List<String> get optionalMechanics => const [];

  @override
  List<GameModeId> get modes => kind.duel
      ? const [GameModeId.campaign]
      : const [GameModeId.campaign, GameModeId.daily, GameModeId.weekly, GameModeId.challenge];

  @override
  List<GameStat> get gameStats => const [
        GameStat('rounds_won', 'Kazanılan tur', 'Rounds won', scale: 10),
        GameStat('answers_right', 'Doğru yanıt', 'Correct answers', scale: 50),
        GameStat('perfect', 'Kusursuz tur', 'Perfect rounds', scale: 10),
        GameStat('streak_5', '5 doğru üst üste', '5 in a row', scale: 10),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('win', 'rounds_won', [3, 10, 25]),
        MissionTemplate('right', 'answers_right', [20, 60, 150]),
        MissionTemplate('streak', 'streak_5', [1, 5, 15]),
        MissionTemplate('perfect', 'perfect', [1, 5, 15]),
      ];

  @override
  BLevel generate(LevelSpec spec) {
    final d = clampI(spec.difficulty, 1, 10);
    return realizeBilgi(kind, d, spec.seed);
  }

  @override
  Validation validate(BLevel puzzle, LevelSpec spec) {
    final ok = puzzle.kind == kind.id && puzzle.qs.length == kind.count(puzzle.d) && puzzle.qs.every(checkQ);
    return ok ? const Validation.ok() : const Validation.fail('invalid');
  }
}

/// Bilgi oyunlarının ortak sahnesi.
class BilgiStage extends StatelessWidget {
  final PlayContext ctx;
  final BilgiRules rules;
  const BilgiStage({super.key, required this.ctx, required this.rules});

  @override
  Widget build(BuildContext context) {
    final lv = ctx.generated.puzzle as BLevel;
    return rules.kind.duel
        ? DuelView(ctx: ctx, level: lv)
        : QuizView(ctx: ctx, level: lv, timeScale: rules.kind.timeScale);
  }
}

BilgiRules bilgiRules(String gameId, BilgiKind kind) => BilgiRules(gameId: gameId, kind: kind);
