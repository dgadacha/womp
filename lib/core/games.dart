import 'game.dart';

/// Les mini-jeux. Ils tournent de manche en manche, le même pour toute la bande.
enum GameId { snap, spot, stop, stash }

/// Ordre de rotation. Attention : y ajouter un jeu change l'enchaînement, et deux
/// versions de l'app ne joueraient plus au même jeu à la même manche.
const rotation = [GameId.snap, GameId.spot, GameId.stop, GameId.stash];

String gameTitle(GameId g) => switch (g) {
      GameId.snap => 'Snap',
      GameId.spot => 'Spot',
      GameId.stop => 'Stop',
      GameId.stash => 'Stash',
    };

GameId? gameNamed(String name) {
  for (final g in GameId.values) {
    if (g.name == name.toLowerCase()) return g;
  }
  return null;
}

/// Les règles Firestore n'acceptent qu'un score entre -150 et 150 : hors bornes,
/// il serait refusé sans bruit. Tout score passe donc par ici avant d'être envoyé.
const scoreMin = -99;
const scoreMax = 150;
int clampScore(int s) => s < scoreMin ? scoreMin : (s > scoreMax ? scoreMax : s);

// ---------- Spot : une flèche pointe dans le mauvais sens ----------

class SpotPuzzle {
  const SpotPuzzle(this.cols, this.odd, this.turn, this.oddTurn, this.tints);
  final int cols; // grille cols x cols
  final int odd; // index de la tuile à trouver
  final int turn; // quarts de tour des flèches (0..3)
  final int oddTurn; // quarts de tour de l'intruse
  final List<int> tints; // couleur de chaque tuile (0..3), pour brouiller l'oeil

  int get count => cols * cols;
}

/// Nombre de grilles préparées. C'est aussi le score maximal, sous la borne des règles.
const spotCount = 120;

List<SpotPuzzle> buildSpotPlan(String day) {
  final r = Rng(hashText('spot-$day'));
  return [
    for (var i = 0; i < spotCount; i++)
      () {
        final cols = i < 3 ? 2 : (i < 8 ? 3 : (i < 18 ? 4 : 5));
        final turn = (r.next() * 4).floor();
        // D'abord l'intruse est à l'envers (facile), puis seulement tournée d'un quart.
        final shift = i < 10 ? 2 : (r.next() < 0.5 ? 1 : 3);
        final odd = (r.next() * cols * cols).floor();
        final tints = [
          for (var t = 0; t < cols * cols; t++) i < 5 ? 0 : (r.next() * 4).floor(),
        ];
        return SpotPuzzle(cols, odd, turn, (turn + shift) % 4, tints);
      }(),
  ];
}

// ---------- Stop : arrêter la barre dans la zone ----------

class StopRound {
  const StopRound(this.speed, this.zoneStart, this.zoneWidth, this.phase);
  final double speed; // traversées de piste par seconde
  final double zoneStart; // 0..1
  final double zoneWidth; // 0..1
  final double phase; // point de départ de la barre (0..2)
}

const stopRounds = 30;

List<StopRound> buildStopPlan(String day) {
  final r = Rng(hashText('stop-$day'));
  return [
    for (var i = 0; i < stopRounds; i++)
      () {
        final width = (0.30 - 0.006 * i).clamp(0.12, 0.30);
        final start = 0.05 + r.next() * (0.90 - width);
        return StopRound(0.9 + 0.05 * i + r.next() * 0.2, start, width, r.next() * 2);
      }(),
  ];
}

/// Position de la barre (0..1) après [ms] millisecondes : un aller-retour régulier.
double stopPosition(StopRound round, int ms) {
  final x = (round.phase + round.speed * ms / 1000) % 2;
  return x <= 1 ? x : 2 - x;
}

/// +3 dans le tiers central de la zone, +1 dans la zone, -1 en dehors.
int stopPoints(StopRound round, double pos) {
  final rel = (pos - round.zoneStart) / round.zoneWidth;
  if (rel < 0 || rel > 1) return -1;
  return (rel - 0.5).abs() <= 1 / 6 ? 3 : 1;
}

// ---------- Stash : retenir les cases allumées ----------

class StashPattern {
  const StashPattern(this.cols, this.cells, this.showMs);
  final int cols; // grille cols x cols
  final List<int> cells; // cases à retenir, toutes différentes
  final int showMs; // durée d'affichage avant de cacher

  int get count => cols * cols;
}

/// 24 grilles au plus. Chaque case retrouvée vaut 1 point : le total possible (142)
/// reste sous la borne des règles sans avoir à écrêter, donc sans égalité forcée.
const stashCount = 24;

int _stashTiles(int i) {
  final n = 3 + (i + 1) ~/ 3;
  return n > 7 ? 7 : n;
}

List<StashPattern> buildStashPlan(String day) {
  final r = Rng(hashText('stash-$day'));
  return [
    for (var i = 0; i < stashCount; i++)
      () {
        final cols = i < 5 ? 3 : (i < 11 ? 4 : 5);
        // Tirage sans remise : on pioche dans la liste des cases encore libres.
        final free = [for (var c = 0; c < cols * cols; c++) c];
        final cells = [
          for (var k = 0; k < _stashTiles(i); k++) free.removeAt((r.next() * free.length).floor()),
        ];
        final show = 1100 - 25 * i;
        return StashPattern(cols, cells, show < 700 ? 700 : show);
      }(),
  ];
}

int stashMaxScore(List<StashPattern> plan) => plan.fold(0, (s, p) => s + p.cells.length);
