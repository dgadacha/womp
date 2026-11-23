import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/game.dart';
import '../core/games.dart';
import '../core/live.dart';
import '../data/repo.dart';
import 'en.dart';
import 'es.dart';
import 'fr.dart';

/// Tous les textes affichés. Une classe par langue : en.dart, fr.dart, es.dart.
/// Une langue à laquelle il manque un texte ne compile pas.
///
/// Les noms des jeux (Snap, Spot, Stop, Stash) et de l'app restent les mêmes partout.
/// Les listes de gages sont alignées : le gage n°3 est le même dans les trois langues,
/// pour que deux amis qui ne parlent pas la même langue lisent le même gage.
abstract class S {
  const S();

  static const supportedLocales = [Locale('en'), Locale('fr'), Locale('es')];

  static S forLanguage(String code) => switch (code) {
        'fr' => const SFr(),
        'es' => const SEs(),
        _ => const SEn(),
      };

  /// Anglais si aucune langue n'est fournie (par exemple dans un test isolé).
  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? const SEn();

  // ---------- Arrivée ----------
  String get tagline;
  String get firstNameLabel;
  String get firstNameHint;
  String get friendInvited;
  String get crewCodeLabel;
  String get joinCrew;
  String get startCrew;
  String get oneSec;

  /// Nom donné à une nouvelle bande. Les règles du serveur le limitent à 24 caractères.
  String crewNameFor(String name);
  String joinProblem(JoinProblem problem);

  // ---------- Commun ----------
  String get languageTitle;
  String get phoneLanguage;
  String get back;
  String get cantReach;
  String get tryAgain;
  String get liveFailed;
  String get partyBadge;
  String get waterCounts;

  // ---------- Salon de la bande ----------
  String get everyoneHere;
  String lobbyIntro(int seconds);
  String inTheCrew(int n);
  String get shareCode;
  String get inviteFriends;
  String inviteText(String code);
  String get inviteCopied;
  String get daresTitle;
  String get classicOn;
  String get partyOn;
  String get switchToParty;
  String get backToClassic;
  String get partyTitle;
  String get partyBody;
  String get keepClassic;
  String get allAdults;
  String get switchFailed;
  String get startGames;
  String get leave;
  String get leaveTitle;
  String get leaveBody;
  String get stay;

  // ---------- Manche ----------
  String gameNumber(int n);
  String roundIntro(int seconds);

  /// Règles affichées avant de jouer, dans l'ordre des pastilles de couleur.
  List<String> rules(GameId game);
  String startsIn(int seconds);
  String get nobodyPlayedThis;
  String alreadyPlayed(int played, int total);
  String get playNow;
  String get endGames;

  // ---------- Gage de la manche ----------
  String gameDare(int n);
  String get waitingOthers;
  String get itsOnYou;
  String itsOn(String name);
  String stillPlaying(String names);
  String get nextGame;

  // ---------- Dans les jeux ----------
  String stopFeedback(int points);
  String stopBar(int i, int n);
  String get stopHint;
  String get stashShow;
  String stashRecall(int found, int total);
  String get stashMissed;
  String get stashAllFound;

  // ---------- Womp Pass ----------
  String packName(String pack);
  String get truthOn;
  String get chaosOn;
  String get passPitch;
  String get passSee;
  String passUnlockedBy(String name);
  String get passUnlockedByYou;
  String passCreatorPicks(String name);
  String get passHeadline;

  /// Ce que le Pass apporte, affiché avant l'achat.
  List<String> get passPerks;
  String passBuy(String price);
  String get passUnavailable;
  String get passOwned;
  String get passRestore;
  String get passBought;
  String get passPending;
  String get passFailed;
  String get passRestored;
  String get passNothingToRestore;

  /// Phrase sous le titre « Gages » du salon, selon le pack choisi.
  String packOn(String pack) => switch (pack) {
        packParty => partyOn,
        packTruth => truthOn,
        packChaos => chaosOn,
        _ => classicOn,
      };

  // ---------- Gages ----------
  // Listes fermées, toutes de [dareCount] éléments, dans le même ordre.
  List<String> get dares;
  List<String> get partyDares;
  String get waterRound;

  /// Packs du Womp Pass. Restent dans la pièce, sans alcool.
  List<String> get truthDares;
  List<String> get chaosDares;

  /// Gage d'une manche : le même pour toute la bande.
  String dareFor({
    required String crewId,
    required int round,
    required int number,
    required String pack,
  }) {
    if (isWaterRound(pack, number)) return waterRound;
    final list = switch (pack) {
      packParty => partyDares,
      packTruth => truthDares,
      packChaos => chaosDares,
      _ => dares,
    };
    return list[liveDareIndex(crewId, round)];
  }
}

class SDelegate extends LocalizationsDelegate<S> {
  const SDelegate();

  @override
  bool isSupported(Locale locale) =>
      S.supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  Future<S> load(Locale locale) => SynchronousFuture(S.forLanguage(locale.languageCode));

  @override
  bool shouldReload(SDelegate old) => false;
}
