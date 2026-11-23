import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womp/core/game.dart';
import 'package:womp/core/games.dart';
import 'package:womp/core/live.dart';
import 'package:womp/games/spot_game.dart';
import 'package:womp/games/stash_game.dart';
import 'package:womp/games/stop_game.dart';

void main() {
  test('games rotate round after round, the same for the whole crew', () {
    final n = rotation.length;
    final games = [for (var r = 1; r <= 2 * n; r++) liveGame('crew-a', r)];
    expect(games.sublist(0, n).toSet(), GameId.values.toSet());
    expect(games.sublist(n), games.sublist(0, n));
    expect([for (var r = 1; r <= n; r++) liveGame('crew-a', r)], games.sublist(0, n));
    expect(rotation.toSet().length, GameId.values.length);
    expect(gameNamed('SPOT'), GameId.spot);
    expect(gameNamed('stash'), GameId.stash);
    expect(gameNamed('nope'), isNull);
  });

  test('every score a game can produce fits the server rules', () {
    // Les règles Firestore refusent tout score hors de -150..150.
    for (final day in ['2026-11-21', '2026-11-22', '2026-11-23', '2027-02-28']) {
      final snap = buildPlan(day, 45000);
      expect(maxScore(snap), lessThanOrEqualTo(150));
      expect(snap.where((s) => s.kind == Kind.trap).length * -3, greaterThanOrEqualTo(-150));
      expect(buildSpotPlan(day).length, lessThanOrEqualTo(150));
      expect(buildStopPlan(day).length * 3, lessThanOrEqualTo(150));
      expect(buildStopPlan(day).length * -1, greaterThanOrEqualTo(-150));
      expect(stashMaxScore(buildStashPlan(day)), lessThanOrEqualTo(150));
      expect(buildStashPlan(day).length * -1, greaterThanOrEqualTo(-150));
    }
    expect([clampScore(-5000), clampScore(7), clampScore(5000)], [scoreMin, 7, scoreMax]);
    expect(scoreMin, greaterThanOrEqualTo(-150));
    expect(scoreMax, lessThanOrEqualTo(150));
  });

  test('spot puzzles are solvable and get harder', () {
    final plan = buildSpotPlan('2026-11-21');
    expect(plan.length, spotCount);
    for (final p in plan) {
      expect(p.odd, inInclusiveRange(0, p.count - 1));
      expect(p.oddTurn, isNot(p.turn));
      expect(p.tints.length, p.count);
    }
    expect(plan.first.cols, 2);
    expect(plan.last.cols, 5);
    final again = buildSpotPlan('2026-11-21');
    expect([for (final p in plan) p.odd], [for (final p in again) p.odd]);
    expect([plan[0].odd, plan[1].odd, plan[20].odd, plan[20].oddTurn], pinnedSpot);
  });

  test('stop rounds: position, zones and points', () {
    final plan = buildStopPlan('2026-11-21');
    expect(plan.length, stopRounds);
    for (final r in plan) {
      expect(r.zoneStart, greaterThanOrEqualTo(0));
      expect(r.zoneStart + r.zoneWidth, lessThanOrEqualTo(1));
      for (var ms = 0; ms < 5000; ms += 37) {
        expect(stopPosition(r, ms), inInclusiveRange(0, 1));
      }
    }
    expect(plan.last.speed, greaterThan(plan.first.speed));
    expect(plan.last.zoneWidth, lessThan(plan.first.zoneWidth));
    const r = StopRound(1, 0.4, 0.3, 0);
    expect(stopPoints(r, 0.55), 3);
    expect(stopPoints(r, 0.42), 1);
    expect(stopPoints(r, 0.68), 1);
    expect(stopPoints(r, 0.39), -1);
    expect(stopPoints(r, 0.71), -1);
    expect(stopPosition(r, 500), closeTo(0.5, 1e-9));
    expect(stopPosition(r, 1500), closeTo(0.5, 1e-9));
    expect(
      [(plan[0].zoneStart * 1000).round(), (plan[0].speed * 1000).round(), (plan[29].phase * 1000).round()],
      pinnedStop,
    );
  });

  test('stash patterns: distinct cells, growing, same for a given day', () {
    final plan = buildStashPlan('2026-11-21');
    expect(plan.length, stashCount);
    for (final p in plan) {
      expect(p.cells.toSet().length, p.cells.length);
      expect(p.cells.every((c) => c >= 0 && c < p.count), isTrue);
      expect(p.cells.length, lessThan(p.count));
      expect(p.showMs, greaterThanOrEqualTo(700));
    }
    expect(plan.first.cells.length, 3);
    expect(plan.last.cells.length, 7);
    expect(plan.last.cols, greaterThan(plan.first.cols));
    expect(plan.last.showMs, lessThan(plan.first.showMs));
    expect([for (final p in buildStashPlan('2026-11-21')) p.cells], [for (final p in plan) p.cells]);
    // Une manche courte laisse le temps de finir au moins une grille.
    expect(plan.first.showMs, lessThan(6000 - 2000));
    expect([...plan[0].cells, stashMaxScore(plan)], pinnedStash);
  });

  Future<void> touch(WidgetTester tester, Offset at) async {
    final g = await tester.startGesture(at, kind: PointerDeviceKind.touch);
    await tester.pump();
    await g.up();
  }

  testWidgets('spot: the odd arrow scores, a wrong one costs and locks', (tester) async {
    const plan = [
      SpotPuzzle(2, 3, 0, 2, [0, 0, 0, 0]),
      SpotPuzzle(2, 0, 1, 3, [0, 0, 0, 0]),
    ];
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: SpotGame(plan: plan, durationMs: 4000, onDone: (s) => result = s),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));

    Offset tile(int t) => tester.getCenter(find.byKey(ValueKey('spot-$t')));

    await touch(tester, tile(1)); // mauvaise tuile
    expect(find.text('-1'), findsOneWidget);
    await touch(tester, tile(3)); // la bonne, mais encore verrouillé
    expect(find.text('-1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await touch(tester, tile(3));
    expect(find.text('0'), findsOneWidget);
    await touch(tester, tile(0)); // deuxième grille
    expect(find.text('1'), findsOneWidget);
    await tester.pump();
    expect(result, 1); // plus de grille : la manche finit avant la fin du temps
  });

  testWidgets('stash: taps wait for the tiles to hide, then score from memory', (tester) async {
    const plan = [
      StashPattern(3, [0, 4], 1000),
      StashPattern(3, [8, 2], 1000),
    ];
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: StashGame(plan: plan, durationMs: 20000, onDone: (s) => result = s),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2200));
    Offset cell(int c) => tester.getCenter(find.byKey(ValueKey('stash-$c')));

    expect(find.text('Remember the yellow tiles'), findsOneWidget);
    await touch(tester, cell(0)); // trop tôt : les cases sont encore allumées
    expect(find.text('0'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Tap them: 0 of 2'), findsOneWidget);
    await touch(tester, cell(0));
    await touch(tester, cell(0)); // la même case ne compte qu'une fois
    expect(find.text('Tap them: 1 of 2'), findsOneWidget);
    await touch(tester, cell(4));
    expect(find.text('All found'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Deuxième grille : une erreur coûte 1 point et passe à la suite.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 1100));
    await touch(tester, cell(5));
    expect(find.text('Missed one'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(result, 1);
  });

  testWidgets('stop: a tap freezes the bar and scores where it is', (tester) async {
    // Vitesse 1, départ à gauche : la barre est au milieu après 0,5 s.
    const plan = [
      StopRound(1, 0.4, 0.2, 0),
      StopRound(1, 0.8, 0.15, 0),
    ];
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: StopGame(plan: plan, durationMs: 6000, onDone: (s) => result = s),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2100 + 500));
    await touch(tester, const Offset(200, 300));
    expect(find.text('+3  Perfect'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);

    // Deuxième barre : on l'arrête tout de suite, loin de la zone.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    await touch(tester, const Offset(200, 300));
    expect(find.text('−1  Miss'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(result, 2);
  });
}

// Valeurs relevées une fois : si elles bougent, la partie du jour a changé pour tout le monde.
const pinnedSpot = [0, 2, 9, 1];
const pinnedStop = [212, 982, 920];
const pinnedStash = [7, 5, 6, 142];
