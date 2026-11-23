import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womp/app.dart';
import 'package:womp/config.dart';
import 'package:womp/core/game.dart';
import 'package:womp/core/store.dart';
import 'package:womp/data/memory_repo.dart';
import 'package:womp/data/pass.dart';
import 'package:womp/l10n/en.dart';

void main() {
  const en = SEn();

  Future<void> start(WidgetTester tester, MemoryRepo repo, PassController pass) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WompApp(store: Store(), repo: repo, pass: pass));
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('while the remote switch is off, nothing shows and the store is never called', (tester) async {
    final repo = MemoryRepo();
    repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya'});
    final store = FakePassStore();
    await start(tester, repo, PassController(store: store));

    expect(find.text(passName.toUpperCase()), findsNothing);
    expect(find.text(en.passSee), findsNothing);
    expect(find.text(en.packName(packTruth)), findsNothing);
    expect(find.textContaining(en.packName(packTruth)), findsNothing);
    expect(find.text(en.switchToParty), findsOneWidget); // le salon d'avant, à l'identique
    expect(store.initCalls, 0);
  });

  testWidgets('without a store in the build, the switch alone shows nothing', (tester) async {
    final repo = MemoryRepo(passOn: true);
    repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya'});
    await start(tester, repo, PassController());
    expect(find.text(en.passSee), findsNothing);
  });

  testWidgets('a guest buys the Pass and the whole crew is unlocked', (tester) async {
    final repo = MemoryRepo(passOn: true);
    final crew = repo.seedCrew(name: 'The Owls', names: {'maya': 'Maya', 'me': 'Al'});
    final store = FakePassStore(price: r'$3.99');
    await start(tester, repo, PassController(store: store));

    expect(find.text(en.passPitch), findsOneWidget);
    expect(find.text(en.packName(packTruth)), findsNothing); // seule Maya choisit les gages

    await tapText(tester, en.passSee);
    expect(find.text(en.passHeadline), findsOneWidget);
    for (final perk in en.passPerks) {
      expect(find.text(perk), findsOneWidget);
    }

    // Annulé : rien ne change.
    store.nextResult = PassResult.cancelled;
    await tapText(tester, en.passBuy(r'$3.99'));
    expect(repo.crews[crew.id]!.unlocked, isFalse);
    expect(find.text(en.passHeadline), findsOneWidget);

    store.nextResult = PassResult.bought;
    await tapText(tester, en.passBuy(r'$3.99'));
    expect(find.text(en.passBought), findsOneWidget);
    expect(repo.crews[crew.id]!.passBy, 'me');
    expect(find.text(en.passUnlockedByYou), findsOneWidget);
    expect(find.text(en.passCreatorPicks('Maya')), findsOneWidget);
  });

  testWidgets('the creator picks a Pass pack once the crew is unlocked, and its dares come up', (tester) async {
    final repo = MemoryRepo(passOn: true);
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al', 'maya': 'Maya'});
    await start(tester, repo, PassController(store: FakePassStore()));

    // Bande pas débloquée : le pack mène à l'écran du Pass.
    await expectLater(repo.setDarePack(crewId: crew.id, pack: packTruth), throwsStateError);
    await tapText(tester, '${en.packName(packTruth)} · Pass');
    expect(find.text(en.passHeadline), findsOneWidget);
    await tapText(tester, en.back);

    // Maya achète le Pass sur son téléphone.
    repo.updateCrew(crew.id, (c) => c.copyWith(passBy: 'maya'));
    await tester.pumpAndSettle();
    expect(find.text(en.passUnlockedBy('Maya')), findsOneWidget);

    await tapText(tester, en.packName(packTruth));
    expect(repo.crews[crew.id]!.darePack, packTruth);
    expect(find.text(en.truthOn), findsOneWidget);
    await tapText(tester, en.packName(packChaos));
    expect(find.text(en.chaosOn), findsOneWidget);

    // Gages à boire : toujours la confirmation d'âge.
    await tapText(tester, en.packName(packParty));
    expect(find.text(en.partyTitle), findsOneWidget);
    await tester.tap(find.text(en.allAdults));
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.darePack, packParty);
  });

  testWidgets('a Pass owner unlocks the crew they join', (tester) async {
    final repo = MemoryRepo(passOn: true);
    final crew = repo.seedCrew(name: 'The Owls', names: {'maya': 'Maya'}, code: 'OWLS22');
    await start(tester, repo, PassController(store: FakePassStore(ownedAtStart: true)));

    await tester.enterText(find.byType(TextField).first, 'Al');
    await tester.enterText(find.byType(TextField).last, 'OWLS22');
    await tester.pumpAndSettle();
    await tester.tap(find.text(en.joinCrew));
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.passBy, 'me');
    expect(find.text(en.passUnlockedByYou), findsOneWidget);
  });

  testWidgets('restore finds a Pass bought before, and says so when there is none', (tester) async {
    final repo = MemoryRepo(passOn: true);
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al'});
    final store = FakePassStore();
    await start(tester, repo, PassController(store: store));

    await tapText(tester, en.passSee);
    await tapText(tester, en.passRestore);
    expect(find.text(en.passNothingToRestore), findsOneWidget);
    expect(repo.crews[crew.id]!.unlocked, isFalse);

    store.boughtBefore = true;
    await tapText(tester, en.passRestore);
    expect(find.text(en.passRestored), findsOneWidget);
    expect(repo.crews[crew.id]!.passBy, 'me');
  });

  testWidgets('a pending payment unlocks the crew once it goes through', (tester) async {
    final repo = MemoryRepo(passOn: true);
    final crew = repo.seedCrew(name: 'The Owls', names: {'me': 'Al'});
    final store = FakePassStore()..nextResult = PassResult.pending;
    await start(tester, repo, PassController(store: store));

    await tapText(tester, en.passSee);
    await tapText(tester, en.passBuy(r'$4.99'));
    expect(find.text(en.passPending), findsOneWidget);
    expect(repo.crews[crew.id]!.unlocked, isFalse);

    store.approvePending();
    await tester.pumpAndSettle();
    expect(repo.crews[crew.id]!.passBy, 'me');
  });

  testWidgets('a Pass that is not on sale yet cannot be bought', (tester) async {
    final repo = MemoryRepo(passOn: true);
    repo.seedCrew(name: 'The Owls', names: {'me': 'Al'});
    await start(tester, repo, PassController(store: FakePassStore(forSale: false)));
    await tapText(tester, en.passSee);
    expect(find.text(en.passUnavailable), findsOneWidget);
    expect(find.textContaining('Get it for'), findsNothing);
  });

  test('a crew is unlocked once, by a member, in their own name', () async {
    final repo = MemoryRepo(uid: 'leo');
    final crew = repo.seedCrew(name: 'The Owls', names: {'maya': 'Maya', 'al': 'Al'});
    await expectLater(repo.unlockCrew(crew.id), throwsStateError); // Leo n'est pas membre
    final mine = repo.seedCrew(name: 'Mine', names: {'leo': 'Leo'}, passBy: 'maya');
    await expectLater(repo.unlockCrew(mine.id), throwsStateError); // déjà débloquée
    expect(en.dareFor(crewId: 'c1', round: 3, number: 5, pack: packTruth), isNot(en.waterRound));
    expect(en.truthDares, contains(en.dareFor(crewId: 'c1', round: 3, number: 5, pack: packTruth)));
    expect(en.chaosDares, contains(en.dareFor(crewId: 'c1', round: 3, number: 1, pack: packChaos)));
  });
}
