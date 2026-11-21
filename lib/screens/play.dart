import 'package:flutter/material.dart';

import '../core/game.dart';
import '../core/games.dart';
import '../games/snap_game.dart';
import '../games/spot_game.dart';
import '../games/stop_game.dart';

/// Lance le mini-jeu du jour. La partie est tirée de la date : la même pour tous.
class PlayScreen extends StatelessWidget {
  const PlayScreen({
    super.key,
    required this.game,
    required this.day,
    required this.durationMs,
    required this.onDone,
  });

  final GameId game;
  final String day;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  Widget build(BuildContext context) {
    return switch (game) {
      GameId.snap => SnapGame(plan: buildPlan(day, durationMs), durationMs: durationMs, onDone: onDone),
      GameId.spot => SpotGame(plan: buildSpotPlan(day), durationMs: durationMs, onDone: onDone),
      GameId.stop => StopGame(plan: buildStopPlan(day), durationMs: durationMs, onDone: onDone),
    };
  }
}
