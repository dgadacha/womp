import '../core/games.dart';
import '../data/repo.dart';
import 'strings.dart';

/// Espace insécable avant les signes doubles, comme le veut la typographie française.
const _n = ' ';

class SFr extends S {
  const SFr();

  // ---------- Arrivée ----------
  @override
  String get tagline => 'Des mini-jeux entre potes.\nLe dernier prend le gage.';
  @override
  String get firstNameLabel => 'Ton prénom';
  @override
  String get firstNameHint => 'ex. Maya';
  @override
  String get friendInvited => "Un ami t'a invité$_n?";
  @override
  String get crewCodeLabel => 'Code de la bande';
  @override
  String get joinCrew => 'Rejoindre la bande';
  @override
  String get startCrew => 'Créer ma bande';
  @override
  String get oneSec => 'Une seconde…';
  @override
  String crewNameFor(String name) => 'La bande à $name';
  @override
  String joinProblem(JoinProblem problem) => switch (problem) {
        JoinProblem.badCode => 'Un code de bande fait 6 lettres et chiffres.',
        JoinProblem.unknownCode => "Aucune bande n'a ce code.",
        JoinProblem.fullOrRefused => 'Cette bande est complète (12 max).',
        JoinProblem.offline => 'Impossible de joindre Womp. Vérifie ta connexion.',
      };

  // ---------- Commun ----------
  @override
  String get languageTitle => 'Langue';
  @override
  String get phoneLanguage => 'Langue du téléphone';
  @override
  String get back => 'Retour';
  @override
  String get cantReach => 'Impossible de joindre Womp.\nVérifie ta connexion.';
  @override
  String get tryAgain => 'Réessayer';
  @override
  String get liveFailed => "Ça n'est pas passé. Réessaie.";
  @override
  String get partyBadge => 'Soirée · 18+';
  @override
  String get waterCounts => "L'eau compte. Ne pousse jamais personne à boire.";

  // ---------- Salon de la bande ----------
  @override
  String get everyoneHere => 'Tout le monde est là$_n?';
  @override
  String lobbyIntro(int seconds) => 'Des parties de $seconds secondes, à la suite, chacun sur son téléphone. '
      'Le dernier prend un gage tout de suite.';
  @override
  String inTheCrew(int n) => 'Dans la bande · $n';
  @override
  String get shareCode => 'Tes amis rejoignent avec ce code.';
  @override
  String get inviteFriends => 'Inviter des amis';
  @override
  String inviteText(String code) => 'Rejoins ma bande sur Womp$_n: des mini-jeux, le dernier prend le gage.\n'
      'Code de la bande$_n: $code';
  @override
  String get inviteCopied => 'Invitation copiée. Colle-la dans le groupe de ta bande.';
  @override
  String get daresTitle => 'Gages';
  @override
  String get classicOn => 'Gages classiques activés.';
  @override
  String get partyOn => 'Gages à boire activés$_n: de petites gorgées, et un jeu sur cinq est une pause eau.';
  @override
  String get switchToParty => 'Passer aux gages à boire (18+)';
  @override
  String get backToClassic => 'Revenir aux gages classiques';
  @override
  String get partyTitle => "Les gages à boire, c'est pour les adultes";
  @override
  String get partyBody => "Ces gages font boire de l'alcool. Ne les active que si tout le monde dans ta bande "
      "a l'âge légal pour boire là où il vit.\n\n"
      "Les gorgées sont petites et plafonnées, et l'eau compte toujours.";
  @override
  String get keepClassic => 'Garder les classiques';
  @override
  String get allAdults => 'On est tous majeurs';
  @override
  String get switchFailed => 'Impossible de changer les gages. Réessaie plus tard.';
  @override
  String get startGames => "C'est parti";
  @override
  String get leave => 'Quitter';
  @override
  String get leaveTitle => 'Quitter cette bande$_n?';
  @override
  String get leaveBody => 'Tu pourras rejoindre une autre bande avec son code. '
      'Pour revenir ici, il te faudra le code de cette bande.';
  @override
  String get stay => 'Rester';

  // ---------- Manche ----------
  @override
  String gameNumber(int n) => 'Jeu $n';
  @override
  String roundIntro(int seconds) => '$seconds secondes. Le dernier prend le gage.';
  @override
  List<String> rules(GameId game) => switch (game) {
        GameId.snap => ['Vert$_n: +1', 'Jaune$_n: +3, il file vite', "Rouge$_n: −3, n'y touche pas"],
        GameId.spot => [
            'Une flèche pointe dans le mauvais sens. Touche-la.',
            'Bonne tuile$_n: +1',
            'Mauvaise tuile$_n: −1',
          ],
        GameId.stop => [
            'Touche pour arrêter la barre.',
            'Centre rouge$_n: +3',
            'Zone jaune$_n: +1',
            'En dehors$_n: −1',
          ],
        GameId.stash => [
            "Des cases s'allument puis s'éteignent. Retiens-les.",
            'Chaque case retrouvée$_n: +1',
            'Mauvaise case$_n: −1, grille suivante',
          ],
      };
  @override
  String startsIn(int seconds) => 'Ça commence dans $seconds…';
  @override
  String get nobodyPlayedThis => "Personne n'a encore joué à celui-ci.";
  @override
  String alreadyPlayed(int played, int total) => '$played sur $total ont déjà joué.';
  @override
  String get playNow => 'Jouer maintenant';
  @override
  String get endGames => 'Arrêter de jouer';

  // ---------- Gage de la manche ----------
  @override
  String gameDare(int n) => 'Jeu $n · le gage';
  @override
  String get waitingOthers => "On attend qu'un autre joueur finisse.";
  @override
  String get itsOnYou => "C'est pour toi.";
  @override
  String itsOn(String name) => "C'est pour $name.";
  @override
  String stillPlaying(String names) => 'Encore en train de jouer$_n: $names. Ça peut encore changer.';
  @override
  String get nextGame => 'Jeu suivant';

  // ---------- Dans les jeux ----------
  @override
  String stopFeedback(int points) => switch (points) { 3 => '+3  Parfait', 1 => '+1  Bien', _ => '−1  Raté' };
  @override
  String stopBar(int i, int n) => 'Barre $i sur $n';
  @override
  String get stopHint => "Touche l'écran pour arrêter la barre";
  @override
  String get stashShow => 'Retiens les cases jaunes';
  @override
  String stashRecall(int found, int total) => 'Touche-les$_n: $found sur $total';
  @override
  String get stashMissed => 'Raté';
  @override
  String get stashAllFound => 'Tout trouvé';

  // ---------- Gages ----------
  @override
  List<String> get dares => const [
        'Dix squats, tout de suite.',
        "Parle comme un robot jusqu'au prochain jeu.",
        'Chante le refrain choisi par le gagnant.',
        'Fais un compliment à chaque joueur, un par un.',
        'Fais ta meilleure imitation du gagnant.',
        'Tiens la planche vingt secondes.',
        'Joue le prochain jeu sur une jambe.',
        'Avoue à la bande la chanson la plus gênante que tu adores.',
      ];
  @override
  List<String> get partyDares => const [
        'Deux gorgées.',
        'Trois gorgées, et le gagnant choisit la boisson.',
        'Une gorgée, et le gagnant boit avec toi.',
        'Deux gorgées de la mauvaise main.',
        'Porte un toast au gagnant à voix haute, puis une gorgée.',
        'Une gorgée par point de retard sur le gagnant. Trois max.',
        'Vérité ou gorgée$_n: le gagnant demande. Esquive et prends deux gorgées.',
        'Pas de gorgée$_n: raconte un secret à la bande à la place.',
      ];
  @override
  String get waterRound => "Pause eau$_n: tout le monde boit un verre d'eau. Pas de gage.";
}
