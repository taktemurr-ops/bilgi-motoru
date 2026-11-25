import 'dart:async';

import 'package:bilgi_motoru/bilgi_motoru.dart';
import 'package:bilgi_motoru/src/duel.dart';
import 'package:bilgi_motoru/src/quiz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';

/// Ağ yerine bellek içi maç bağlantısı.
class FakeLink implements MatchLink {
  @override
  final int mySeat;
  @override
  final int seed;
  final StreamController<(int, String)> ctrl = StreamController.broadcast();
  final List<String> sent = [];
  @override
  final List<(int, String)> history;
  @override
  final Set<int> dropped = {};
  int? winner;
  FakeLink(this.mySeat, {this.seed = 42, this.history = const []});

  @override
  List<String> get names => const ['A', 'B'];
  @override
  bool get isHost => mySeat == 0;
  @override
  Stream<(int, String)> get moves => ctrl.stream;
  @override
  Future<void> send(String move, {int? asSeat}) async => sent.add(move);
  @override
  Future<void> finish(int winner, {bool? iWon}) async => this.winner = winner;
  int get oppSeat => mySeat == 0 ? 1 : 0;
  void opp(String m) => ctrl.add((oppSeat, m));
}

PlayContext onlineCtx(GeneratedLevel gl, FakeLink link, List<RoundResult> results, {String lang = 'tr'}) => PlayContext(
      spec: gl.spec,
      generated: gl,
      resume: const {},
      pieceColors: const [Color(0xFF3E6FB0), Color(0xFFC8553D), Color(0xFF4F9A6E)],
      background: const [Color(0xFF203040), Color(0xFF304050)],
      colorBlind: false,
      reducedMotion: false,
      leftHanded: false,
      lang: lang,
      t: (k, [p = const {}]) => k,
      finish: results.add,
      saveResume: (_) {},
      requestHint: () async => true,
      requestBooster: () async => true,
      requestContinue: () async => false,
      sfx: (_) {},
      seats: [for (var i = 0; i < 2; i++) i == link.mySeat ? SeatRole.local : SeatRole.remote],
      match: link,
    );

BilgiRules duelRules() => bilgiRulesFor('oyun-bilgi-duellosu', 'duello');

GeneratedLevel onlineLevel(int seed) {
  final rules = duelRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
  return rules.build(planner.run(GameModeId.online, seed, difficulty: 4));
}

Future<void> pumpDuel(WidgetTester tester, GeneratedLevel gl, FakeLink link, List<RoundResult> results, {String lang = 'tr'}) async {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SafeArea(child: BilgiStage(ctx: onlineCtx(gl, link, results, lang: lang), rules: duelRules()))),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Maç bitene kadar: her soruda ilk seçeneğe dokun, istenirse rakip yanıtlasın.
Future<void> playOut(WidgetTester tester, FakeLink link, List<RoundResult> results, {required bool oppAnswers}) async {
  for (var step = 0; step < 400 && results.isEmpty; step++) {
    final opts = find.byType(InkWell);
    if (opts.evaluate().isNotEmpty) {
      await tester.tap(opts.first, warnIfMissed: false);
    }
    await tester.pump(const Duration(milliseconds: 200));
    if (oppAnswers) {
      final q = link.sent.where((m) => m.startsWith('A')).length - 1;
      if (q >= 0) link.opp('A$q:0:99999');
    }
    await tester.pump(const Duration(seconds: 2));
    final next = find.byType(FilledButton);
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first);
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
  }
}

void main() {
  test('düello iki kişilik, diğer türler tek kişilik', () {
    for (final e in kBilgiKinds.entries) {
      final r = bilgiRulesFor('oyun-t-${e.key}', e.key);
      expect(r.localPlayers, e.key == 'duello' ? 2 : 0, reason: e.key);
    }
  });

  test('iki cihaz aynı soruları aynı sırayla alır (dil fark etmez)', () {
    for (final seed in const [1, 42, 777, 90210]) {
      final a = onlineLevel(seed).puzzle as BLevel;
      final b = onlineLevel(seed).puzzle as BLevel;
      expect(a.qs.length, b.qs.length);
      for (var i = 0; i < a.qs.length; i++) {
        final x = a.qs[i], y = b.qs[i];
        expect([x.t, x.ans, ...x.a, ...x.o], [y.t, y.ans, ...y.a, ...y.o], reason: 'seed $seed soru $i');
        // Farklı dillerdeki oyuncular aynı seçenek sırasını görür.
        expect(renderQ(x, 'tr').options.length, renderQ(y, 'ja').options.length);
      }
    }
  });

  test('soru kazananı ve bilgisayar yanıtı belirlenimli', () {
    final lv = onlineLevel(42).puzzle as BLevel;
    final q = lv.qs.first;
    final wrong = q.ans == 0 ? 1 : 0;
    expect(duelWinner(q, (q.ans, 500), (q.ans, 900)), 0);
    expect(duelWinner(q, (q.ans, 900), (q.ans, 500)), 1);
    expect(duelWinner(q, (wrong, 100), (q.ans, 9000)), 1);
    expect(duelWinner(q, (wrong, 100), (-1, 20000)), -1);
    expect(duelBotAnswer(q, 3, 5, 99), duelBotAnswer(q, 3, 5, 99));
    expect(DuelNet.parse('A3:2:1500'), (3, 2, 1500));
    expect(DuelNet.parse('A3:x:1'), isNull);
    expect(DuelNet.parse('L:tr'), isNull);
  });

  for (final seat in const [0, 1]) {
    testWidgets('çevrimiçi düello (koltuk $seat): yanıtlar gider, rakibinkiler işlenir, maç biter', (tester) async {
      final gl = onlineLevel(42);
      final link = FakeLink(seat);
      final results = <RoundResult>[];
      await pumpDuel(tester, gl, link, results, lang: seat == 0 ? 'tr' : 'en');
      // Çevrimiçinde başlangıç seçimi yok: soru hemen gelir.
      expect(find.byKey(const ValueKey('duel-bot')), findsNothing);
      // Geçersiz rakip hamleleri güvenle yok sayılır.
      for (final m in const ['L:tr', 'Ax', 'A-1:0:5', 'R0:']) {
        link.opp(m);
        await tester.pump(const Duration(milliseconds: 100));
      }
      await playOut(tester, link, results, oppAnswers: true);
      final n = (gl.puzzle as BLevel).qs.length;
      expect(link.sent.where((m) => m.startsWith('A')).length, n);
      expect(results, isNotEmpty);
      expect(link.winner, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('maça geri dönüş: gönderilmiş yanıtlar yeniden işlenir', (tester) async {
    final gl = onlineLevel(42);
    final qs = (gl.puzzle as BLevel).qs;
    // Koltuk 0: ilk iki soruyu iki taraf da yanıtlamış, üçüncüyü yalnız ben.
    final link = FakeLink(0, history: [
      (0, 'A0:${qs[0].ans}:1000'),
      (1, 'A0:${qs[0].ans}:2000'),
      (0, 'A1:${qs[1].ans == 0 ? 1 : 0}:1000'),
      (1, 'A1:${qs[1].ans}:3000'),
      (0, 'A2:${qs[2].ans}:1500'),
    ]);
    final results = <RoundResult>[];
    await pumpDuel(tester, gl, link, results);
    // 1. soru bende, 2. soru rakipte: 1 – 1, şimdi 3. soru (yanıtım gitmiş, rakip bekleniyor).
    expect(find.text('3/${qs.length}'), findsOneWidget);
    expect(find.textContaining('1 – 1'), findsOneWidget);
    expect(link.sent, isEmpty);
    link.opp('A2:-1:20000');
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('2 – 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('rakip koparsa bilgisayar devralır ve maç biter', (tester) async {
    final gl = onlineLevel(7);
    final link = FakeLink(1);
    final results = <RoundResult>[];
    await pumpDuel(tester, gl, link, results);
    link.dropped.add(0);
    await playOut(tester, link, results, oppAnswers: false);
    expect(results, isNotEmpty);
    expect(link.winner, isNotNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('çevrimdışı: bilgisayara karşı ve aynı telefonda iki kişi', (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    final rules = duelRules();
    final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: const []);
    final gl = rules.build(planner.spec(5));
    for (final key in const ['duel-bot', 'duel-face']) {
      final results = <RoundResult>[];
      final ctx = PlayContext(
        spec: gl.spec,
        generated: gl,
        resume: const {},
        pieceColors: const [Color(0xFF3E6FB0)],
        background: const [Color(0xFF203040), Color(0xFF304050)],
        colorBlind: false,
        reducedMotion: false,
        leftHanded: false,
        lang: 'tr',
        t: (k, [p = const {}]) => k,
        finish: results.add,
        saveResume: (_) {},
        requestHint: () async => true,
        requestBooster: () async => true,
        requestContinue: () async => false,
        sfx: (_) {},
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SafeArea(child: BilgiStage(ctx: ctx, rules: rules)))));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 300));
      for (var step = 0; step < 400 && results.isEmpty; step++) {
        final opts = find.byType(InkWell);
        if (opts.evaluate().isNotEmpty) await tester.tap(opts.first, warnIfMissed: false);
        await tester.pump(const Duration(seconds: 2));
        final next = find.byType(FilledButton);
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next.first);
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(tester.takeException(), isNull);
      }
      expect(results, isNotEmpty, reason: key);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }
  });
}
