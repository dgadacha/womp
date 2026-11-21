import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/games.dart';
import '../ui/kit.dart';
import 'round.dart';

const _pauseMs = 500; // on montre le résultat avant la barre suivante
const double _trackHeight = 96;

/// Stop : une barre va et vient, on touche l'écran pour l'arrêter dans la zone.
class StopGame extends StatefulWidget {
  const StopGame({super.key, required this.plan, required this.durationMs, required this.onDone});

  final List<StopRound> plan;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  State<StopGame> createState() => _StopGameState();
}

class _StopGameState extends State<StopGame>
    with SingleTickerProviderStateMixin<StopGame>, RoundClock<StopGame> {
  int _round = 0;
  int _roundStart = 0;
  double? _frozen; // position de la barre arrêtée
  int _lastPoints = 0;
  int _resumeAt = 0;

  @override
  int get durationMs => widget.durationMs;
  @override
  ValueChanged<int> get onDone => widget.onDone;
  @override
  bool get isOver => _round >= widget.plan.length;

  @override
  void onTick() {
    if (_frozen != null && ms >= _resumeAt) {
      _frozen = null;
      _round += 1;
      _roundStart = ms;
    }
  }

  void _tap() {
    if (done || isOver || ms < 0 || _frozen != null) return;
    final round = widget.plan[_round];
    // L'instant du toucher, pas celui de la dernière image : c'est un jeu de précision.
    final at = nowMs;
    final pos = stopPosition(round, at - _roundStart);
    final pts = stopPoints(round, pos);
    if (pts > 0) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      score += pts;
      _frozen = pos;
      _lastPoints = pts;
      _resumeAt = at + _pauseMs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return RoundFrame(
      score: score,
      ms: ms,
      durationMs: durationMs,
      builder: (context, arena) {
        if (isOver) return const SizedBox.expand();
        final round = widget.plan[_round];
        final pos = _frozen ?? stopPosition(round, ms - _roundStart);
        final width = arena.width - 24;
        final feedback = _frozen == null
            ? ''
            : switch (_lastPoints) { 3 => '+3  Perfect', 1 => '+1  Nice', _ => '−1  Miss' };
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (_) => _tap(),
          child: SizedBox.expand(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Overline('Bar ${_round + 1} of ${widget.plan.length}'),
                const SizedBox(height: 18),
                SizedBox(
                  width: width,
                  height: _trackHeight + 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 12,
                        height: _trackHeight,
                        child: DecoratedBox(
                          decoration: inkDecoration(color: Tone.bg, radius: 18, drop: Tone.drop),
                        ),
                      ),
                      Positioned(
                        left: width * round.zoneStart,
                        width: width * round.zoneWidth,
                        top: 12,
                        height: _trackHeight,
                        child: DecoratedBox(
                          decoration: inkDecoration(color: Tone.sun, radius: 10, drop: 0),
                        ),
                      ),
                      Positioned(
                        left: width * (round.zoneStart + round.zoneWidth / 3),
                        width: width * round.zoneWidth / 3,
                        top: 12 + Tone.stroke,
                        height: _trackHeight - 2 * Tone.stroke,
                        child: const ColoredBox(color: Tone.tomato),
                      ),
                      Positioned(
                        key: const ValueKey('stop-marker'),
                        left: width * pos - 7,
                        width: 14,
                        top: 0,
                        height: _trackHeight + 24,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Tone.ink,
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  height: 40,
                  child: Text(
                    feedback,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: _lastPoints > 0 ? Tone.mint : Tone.tomato,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap anywhere to stop the bar',
                  style: TextStyle(color: Tone.soft, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
