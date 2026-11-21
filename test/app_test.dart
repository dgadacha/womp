import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womp/app.dart';
import 'package:womp/core/game.dart';
import 'package:womp/core/store.dart';
import 'package:womp/data/memory_repo.dart';
import 'package:womp/data/repo.dart';

void main() {
  final today = dayKey();

  Future<void> start(WidgetTester tester, MemoryRepo repo) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WompApp(store: Store(), repo: repo));
    await tester.pumpAndSettle();
  }

  testWidgets('a new player starts a crew and lands on the game', (tester) async {
    final repo = MemoryRepo();
    await start(tester, repo);
    expect(find.text('Start a new crew'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start a new crew'));
    await tester.pumpAndSettle();

    expect(repo.crews.values.single.names, {'me': 'Al'});
    expect(find.text('Play'), findsOneWidget);
    expect(find.textContaining("It's just you so far"), findsOneWidget);
  });

  testWidgets('a wrong crew code shows why, a good one joins', (tester) async {
    final repo = MemoryRepo()..seedCrew(name: 'The Owls', names: {'maya': 'Maya'}, code: 'OWLS22');
    await start(tester, repo);
    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.enterText(find.byType(TextField).last, 'ZZZZ99');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join the crew'));
    await tester.pumpAndSettle();
    expect(find.text('No crew has that code.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'owls22');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Join the crew'));
    await tester.pumpAndSettle();
    expect(repo.crews.values.single.members, ['maya', 'me']);
    expect(find.textContaining('Nobody has played yet'), findsOneWidget);
  });

  testWidgets('the board follows the crew live', (tester) async {
    final repo = MemoryRepo();
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya', 'leo': 'Leo'});
    repo.scoreAs('maya', crew.id, today, 12);
    await start(tester, repo);
    expect(find.text('Maya scored 12. Beat that.'), findsOneWidget);
    expect(find.textContaining('1 of 3 played'.toUpperCase()), findsOneWidget);

    // Mon score arrive : je passe au classement, Leo n'a pas encore joué.
    await repo.postScore(crewId: crew.id, day: today, name: 'Al', score: 5);
    await tester.pumpAndSettle();
    expect(find.text('Last so far. Pray someone does worse.'), findsOneWidget);
    expect(find.text('Not played yet'), findsOneWidget);

    // Leo joue pendant que je regarde : la ligne apparaît sans rien toucher.
    repo.scoreAs('leo', crew.id, today, 1);
    await tester.pumpAndSettle();
    expect(find.text('2nd of 3 so far.'), findsOneWidget);
    expect(find.text('Not played yet'), findsNothing);
    expect(find.text("Right now it's on Leo."), findsOneWidget);
  });

  test('one score per day, twelve members at most', () async {
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
    repo.scoreAs('u0', crew.id, today, 9);
    repo.scoreAs('u0', crew.id, today, 99);
    expect(await repo.watchScores(crew.id, today).first, {'u0': 9});
    expect(normalizeCode(' owl-s22 '), 'OWLS22');
    expect(normalizeCode('OWL'), isNull);
    expect(normalizeCode('OWLS01'), isNull);
  });
}
