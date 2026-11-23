import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womp/app.dart';
import 'package:womp/core/game.dart';
import 'package:womp/core/games.dart';
import 'package:womp/core/live.dart';
import 'package:womp/core/store.dart';
import 'package:womp/data/memory_repo.dart';
import 'package:womp/data/repo.dart';
import 'package:womp/l10n/en.dart';
import 'package:womp/l10n/es.dart';
import 'package:womp/l10n/fr.dart';
import 'package:womp/l10n/strings.dart';

void main() {
  const langs = <String, S>{'en': SEn(), 'fr': SFr(), 'es': SEs()};

  test('every language has the same dare lists, rules and problems', () {
    for (final e in langs.entries) {
      final s = e.value;
      // Listes alignées : le gage n°i est le même partout.
      for (final list in [s.dares, s.partyDares, s.truthDares, s.chaosDares]) {
        expect(list.length, dareCount, reason: e.key);
        expect(list.toSet().length, dareCount, reason: '${e.key}: doublon');
      }
      expect(s.passPerks.length, const SEn().passPerks.length, reason: e.key);
      expect({for (final p in darePacks) s.packName(p)}.length, darePacks.length, reason: e.key);
      for (final g in GameId.values) {
        expect(s.rules(g).length, const SEn().rules(g).length, reason: '${e.key} ${g.name}');
      }
      for (final p in JoinProblem.values) {
        expect(s.joinProblem(p), isNotEmpty);
      }
      // Le nom de bande le plus long reste sous la limite des règles (24).
      expect(s.crewNameFor('Abcdefghijkl').length, lessThanOrEqualTo(24), reason: e.key);
      for (final p in [3, 1, -1]) {
        expect(s.stopFeedback(p), startsWith(p > 0 ? '+$p' : '−1'));
      }
    }
  });

  test('a dare is the same index in every language', () {
    for (var round = 1; round <= 10; round++) {
      final i = liveDareIndex('crew-a', round);
      for (final s in langs.values) {
        expect(s.dareFor(crewId: 'crew-a', round: round, number: 1, pack: packClassic), s.dares[i]);
        expect(s.dareFor(crewId: 'crew-a', round: round, number: 1, pack: packParty), s.partyDares[i]);
        expect(s.dareFor(crewId: 'crew-a', round: round, number: 5, pack: packParty), s.waterRound);
        expect(s.dareFor(crewId: 'crew-a', round: round, number: 5, pack: packTruth), s.truthDares[i]);
        expect(s.dareFor(crewId: 'crew-a', round: round, number: 2, pack: packChaos), s.chaosDares[i]);
      }
    }
  });

  Future<void> start(WidgetTester tester, MemoryRepo repo, Locale locale) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WompApp(store: Store(), repo: repo, locale: locale));
    await tester.pumpAndSettle();
  }

  for (final e in langs.entries) {
    testWidgets('the app speaks ${e.key} from arrival to the first game', (tester) async {
      final s = e.value;
      final repo = MemoryRepo();
      await start(tester, repo, Locale(e.key));
      expect(find.text(s.startCrew), findsOneWidget);
      expect(find.text(s.tagline), findsOneWidget);

      // Un code inconnu : le message d'erreur est dans la bonne langue.
      await tester.enterText(find.byType(TextField).first, 'Al');
      await tester.enterText(find.byType(TextField).last, 'ZZZZ99');
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.joinCrew));
      await tester.pumpAndSettle();
      expect(find.text(s.joinProblem(JoinProblem.unknownCode)), findsOneWidget);

      // La bande créée : le salon, dans la bonne langue.
      await tester.tap(find.text(s.startCrew));
      await tester.pumpAndSettle();
      final crew = repo.crews.values.single;
      expect(crew.name, s.crewNameFor('Al'));
      expect(find.text(s.everyoneHere), findsOneWidget);
      expect(find.text(s.classicOn), findsOneWidget);
      expect(find.text(s.leave), findsOneWidget);

      // La première manche, avec ses règles.
      await tester.ensureVisible(find.text(s.startGames));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.startGames));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      for (final rule in s.rules(liveGame(crew.id, 1))) {
        expect(find.text(rule), findsOneWidget);
      }
      expect(find.text(s.playNow), findsOneWidget);
      // Un score posté annule le départ automatique, pour finir le test proprement.
      await repo.postLiveScore(crewId: crew.id, round: 1, name: 'Al', score: 5);
      await tester.pumpAndSettle();
      expect(find.text(s.waitingOthers), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the language screen switches the whole app, and back to the phone language', (tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = Store();
    await tester.pumpWidget(WompApp(store: store, repo: MemoryRepo()));
    await tester.pumpAndSettle();
    expect(find.text(const SEn().tagline), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Phone language'), findsOneWidget);
    await tester.tap(find.text('Français'));
    await tester.pumpAndSettle();
    expect(store.locale, 'fr');
    expect(find.text(const SFr().tagline), findsOneWidget);
    expect(find.text('FR'), findsOneWidget);

    // L'écran de langue suit la langue choisie, et marque le choix en cours.
    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();
    expect(find.text('Langue'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.text('Español'));
    await tester.pumpAndSettle();
    expect(find.text(const SEs().tagline), findsOneWidget);

    await tester.tap(find.text('ES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Idioma del teléfono'));
    await tester.pumpAndSettle();
    expect(store.locale, '');
    expect(find.text(const SEn().tagline), findsOneWidget);
  });

  test('the chosen language is kept between launches', () async {
    SharedPreferences.setMockInitialValues({});
    final first = Store();
    await first.load();
    first
      ..name = 'Maya'
      ..locale = 'es'
      ..save();
    final second = Store();
    await second.load();
    expect([second.name, second.locale], ['Maya', 'es']);
  });
}
