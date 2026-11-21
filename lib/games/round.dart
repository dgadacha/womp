import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../config.dart';
import '../core/games.dart';
import '../ui/kit.dart';

/// Décompte avant le début d'une manche.
const countdownMs = shortRound ? 600 : 2100;

/// L'horloge commune aux mini-jeux : décompte, temps de jeu, fin de manche.
/// Tout part du temps écoulé, jamais d'un compteur d'images.
mixin RoundClock<T extends StatefulWidget> on SingleTickerProviderStateMixin<T> {
  late final Ticker _ticker;
  final Stopwatch _sinceFrame = Stopwatch();

  /// Temps de jeu en ms, négatif pendant le décompte.
  int ms = -countdownMs;
  int score = 0;
  bool done = false;

  int get durationMs;
  ValueChanged<int> get onDone;

  /// Appelé à chaque image, dans le setState de l'horloge.
  void onTick() {}

  /// Vrai quand le jeu est fini avant la fin du temps.
  bool get isOver => false;

  /// L'instant précis d'un toucher : l'image courante plus le temps passé depuis.
  int get nowMs => ms + min(_sinceFrame.elapsedMilliseconds, 34);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      if (done) return;
      _sinceFrame
        ..reset()
        ..start();
      setState(() {
        ms = elapsed.inMilliseconds - countdownMs;
        onTick();
      });
      if (ms >= durationMs || isOver) finish();
    })
      ..start();
  }

  void finish() {
    if (done) return;
    done = true;
    _ticker.stop();
    onDone(clampScore(score));
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

/// Le cadre commun : score, barre de temps, et l'arène où le jeu se dessine.
class RoundFrame extends StatelessWidget {
  const RoundFrame({
    super.key,
    required this.score,
    required this.ms,
    required this.durationMs,
    required this.builder,
  });

  final int score;
  final int ms;
  final int durationMs;
  final Widget Function(BuildContext context, Size arena) builder;

  @override
  Widget build(BuildContext context) {
    final left = (1 - ms / durationMs).clamp(0.0, 1.0);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 84,
                    child: Text(
                      '$score',
                      style: const TextStyle(
                        fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 18,
                      clipBehavior: Clip.antiAlias,
                      decoration: inkDecoration(color: Tone.paper, radius: 999, drop: 0),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: ms < 0 ? 1 : left,
                        heightFactor: 1,
                        child: const ColoredBox(color: Tone.mint),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: InkBox(
                  padding: const EdgeInsets.all(6),
                  radius: 24,
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (ms < 0) {
                        return Center(
                          child: Text(
                            '${(-ms / (countdownMs / 3)).ceil().clamp(1, 3)}',
                            style: const TextStyle(fontSize: 110, fontWeight: FontWeight.w900),
                          ),
                        );
                      }
                      return builder(context, Size(box.maxWidth, box.maxHeight));
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
