import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womp/app.dart';
import 'package:womp/core/game.dart';
import 'package:womp/core/games.dart';
import 'package:womp/core/live.dart';
import 'package:womp/core/store.dart';
import 'package:womp/data/memory_repo.dart';
import 'package:womp/data/repo.dart';
import 'package:womp/l10n/en.dart';
import 'package:womp/screens/room.dart';
import 'package:womp/ui/kit.dart';

void main() {
  const en = SEn();

  Future<void> start(WidgetTester tester, MemoryRepo repo) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WompApp(store: Store(), repo: repo));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
  }

  testWidgets('a new player starts a crew and lands in the room', (tester) async {
    final repo = MemoryRepo();
    await start(tester, repo);
    expect(find.text(en.startCrew), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.startCrew));
    await tester.pumpAndSettle();

    final crew = repo.crews.values.single;
    expect(crew.names, {'me': 'Al'});
    expect(find.text(en.everyoneHere), findsOneWidget);
    expect(find.text(crew.code), findsOneWidget);
    expect(find.text(en.inTheCrew(1).toUpperCase()), findsOneWidget);
    expect(find.text(en.startGames), findsOneWidget);
    expect(find.text(en.classicOn), findsOneWidget);
  });

  testWidgets('a wrong crew code shows why, a good one joins the room', (tester) async {
    final repo = MemoryRepo()..seedCrew(name: 'The Owls', names: {'maya': 'Maya'}, code: 'OWLS22');
    await start(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.enterText(find.byType(TextField).last, 'ZZZZ99');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.joinCrew));
    await tester.pumpAndSettle();
    expect(find.text(en.joinProblem(JoinProblem.unknownCode)), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'owls22');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.joinCrew));
    await tester.pumpAndSettle();
    expect(repo.crews.values.single.members, ['maya', 'me']);
    expect(find.text('THE OWLS'), findsOneWidget);
    expect(find.text('Maya'), findsOneWidget);
    // Celui qui rejoint ne choisit pas le type de gages.
    expect(find.text(en.switchToParty), findsNothing);
  });

  testWidgets('games start on their own, chain, and the last one gets the dare at once', (tester) async {
    final repo = MemoryRepo();
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya', 'leo': 'Leo'});
    await start(tester, repo);

    await tapText(tester, en.startGames);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.gameNumber(1).toUpperCase()), findsOneWidget);
    expect(find.text(gameTitle(liveGame(crew.id, 1))), findsOneWidget);
    for (final rule in en.rules(liveGame(crew.id, 1))) {
      expect(find.text(rule), findsOneWidget);
    }
    expect(find.text(en.startsIn(4)), findsOneWidget);

    // Sans rien toucher, le jeu démarre seul, puis se termine.
    await tester.pump(const Duration(milliseconds: autoStartMs));
    await tester.pump();
    expect(find.text(en.playNow), findsNothing);
    await tester.pump(const Duration(milliseconds: liveMs + 2200));
    await tester.pump();
    await tester.pumpAndSettle();

    // Seul à avoir joué : pas encore de gage.
    expect(repo.liveScores(crew.id, 1).keys, ['me']);
    expect(find.text(en.waitingOthers), findsOneWidget);
    expect(tester.widget<InkButton>(find.widgetWithText(InkButton, en.nextGame)).onTap, isNull);

    // Maya et Leo finissent avec plus : le gage tombe sur moi, tout de suite.
    repo.liveScoreAs('maya', crew.id, 1, 50);
    await tester.pumpAndSettle();
    expect(find.text(en.itsOnYou), findsOneWidget);
    expect(find.text(en.dareFor(crewId: crew.id, round: 1, number: 1, pack: packClassic)), findsOneWidget);
    expect(find.textContaining('Still playing: Leo'), findsOneWidget);
    repo.liveScoreAs('leo', crew.id, 1, 40);
    await tester.pumpAndSettle();
    expect(find.text(en.itsOnYou), findsOneWidget);

    // Jeu suivant : il s'affiche avec son compte à rebours ; je peux lancer tout de suite.
    await tapText(tester, en.nextGame);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(en.gameNumber(2).toUpperCase()), findsOneWidget);
    expect(find.text(en.nobodyPlayedThis), findsOneWidget);
    repo.liveScoreAs('maya', crew.id, 1, 99); // trop tard pour la manche 1
    expect(repo.liveScores(crew.id, 1)['maya'], 50);

    // Un score arrivé avant le départ automatique l'annule.
    await repo.postLiveScore(crewId: crew.id, round: 2, name: 'Al', score: 3);
    await tester.pump(const Duration(milliseconds: autoStartMs + 100));
    await tester.pumpAndSettle();
    expect(find.text(en.waitingOthers), findsOneWidget);

    await tapText(tester, en.endGames);
    await tester.pumpAndSettle();
    expect(find.text(en.everyoneHere), findsOneWidget);
  });

  testWidgets('only the crew creator can switch to party dares, after confirming', (tester) async {
    final repo = MemoryRepo();
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya'});
    await start(tester, repo);
    expect(find.text(en.partyBadge), findsNothing);

    await tapText(tester, en.switchToParty);
    await tester.pumpAndSettle();
    expect(find.text(en.partyTitle), findsOneWidget);
    await tester.tap(find.text(en.keepClassic));
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.darePack, packClassic);

    await tapText(tester, en.switchToParty);
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.allAdults));
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.darePack, packParty);
    expect(find.text(en.partyOn), findsOneWidget);
    expect(find.text(en.partyBadge), findsOneWidget);
    expect(find.text(en.waterCounts), findsOneWidget);
    expect(find.text(en.backToClassic), findsOneWidget);
  });

  testWidgets('a player can leave the crew and lands back on the welcome screen', (tester) async {
    final repo = MemoryRepo();
    final crew = repo.seedCrew(name: 'The Owls', names: {'maya': 'Maya', 'me': 'Al'}, code: 'OWLS22');
    await start(tester, repo);
    expect(find.text(en.switchToParty), findsNothing);
    await expectLater(repo.setDarePack(crewId: crew.id, pack: packParty), throwsStateError);

    await tester.tap(find.text(en.leave));
    await tester.pumpAndSettle();
    expect(find.text(en.leaveTitle), findsOneWidget);
    await tester.tap(find.text(en.stay));
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.members, ['maya', 'me']);

    await tester.tap(find.text(en.leave));
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.leave).last);
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.members, ['maya']);
    expect(find.text(en.startCrew), findsOneWidget);
    expect(await repo.myCrew(), isNull);
  });

  test('dares: closed lists, tiny sips, a water round every fifth game', () {
    for (var n = 1; n <= 20; n++) {
      final d = en.dareFor(crewId: 'c1', round: 40 + n, number: n, pack: packParty);
      expect(d == en.waterRound, n % waterEvery == 0, reason: 'game $n');
      expect(isWaterRound(packParty, n), n % waterEvery == 0);
      expect(isWaterRound(packClassic, n), isFalse);
      expect(d == en.waterRound || en.partyDares.contains(d), isTrue);
      expect(en.dares, contains(en.dareFor(crewId: 'c1', round: 40 + n, number: n, pack: packClassic)));
    }
    // Jamais plus de trois gorgées par gage.
    for (final d in en.partyDares) {
      expect(RegExp(r'\b(four|five|six|seven|eight|nine|ten|shot|finish|down)\b').hasMatch(d.toLowerCase()), isFalse,
          reason: d);
    }
    expect(liveSeed('c1', 3), isNot(liveSeed('c1', 4)));
    expect(LiveState.start(null).number, 1);
    expect(LiveState.start(const LiveState(round: 7, base: 5, open: false)).round, 8);
    expect(const LiveState(round: 7, base: 5, open: true).next().number, 4);
  });

  test('twelve members at most, and leaving frees a seat', () async {
    final repo = MemoryRepo();
    final crew = repo.seedCrew(
      name: 'Full',
      names: {for (var i = 0; i < maxCrewSize; i++) 'u$i': 'P$i'},
      code: 'FULL22',
    );
    await expectLater(
      repo.joinCrew(code: 'FULL22', myName: 'Al'),
      throwsA(isA<JoinFailure>().having((e) => e.problem, 'problem', JoinProblem.fullOrRefused)),
    );
    expect(normalizeCode(' owl-s22 '), 'OWLS22');
    expect(normalizeCode('OWL'), isNull);
    expect(normalizeCode('OWLS01'), isNull);
    expect(crew.members.length, maxCrewSize);
  });
}
