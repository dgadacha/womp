import '../config.dart';
import 'game.dart';
import 'games.dart';

/// Mode instantané : la bande est réunie, les jeux s'enchaînent, et le dernier de
/// chaque jeu reçoit son gage tout de suite.

/// Une manche du mode instantané est plus courte que le jeu du jour.
const int liveMs = shortRound ? 6000 : 20000;

/// Le jeu d'une manche se déduit de la bande et du numéro : rien à stocker.
GameId liveGame(String crewId, int round) => rotation[(hashText(crewId) + round) % rotation.length];

/// Graine de la partie : la même pour toute la bande, différente à chaque manche.
String liveSeed(String crewId, int round) => 'live-$crewId-$round';

// Les textes des gages instantanés sont dans lib/l10n. Ils restent courts, et en
// version à boire jamais plus de trois gorgées.

/// Les jeux s'enchaînent, les gorgées aussi : une manche sur cinq, tout le monde boit de l'eau.
const waterEvery = 5;

/// [number] est le rang du jeu dans la session en cours (1, 2, 3...).
bool isWaterRound(String pack, int number) => pack == packParty && number % waterEvery == 0;

/// Le gage d'une manche : le même pour toute la bande.
int liveDareIndex(String crewId, int round) => (hashText(crewId) + round) % dareCount;
