import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/games.dart';
import '../ui/kit.dart';
import 'round.dart';

const _tints = [Tone.paper, Tone.sun, Tone.mint, Tone.blush];
const _lockMs = 350; // pause après une erreur, pour ne pas gagner en tapotant partout

/// Spot : toutes les flèches pointent du même côté, sauf une. On la touche.
class SpotGame extends StatefulWidget {
  const SpotGame({super.key, required this.plan, required this.durationMs, required this.onDone});

  final List<SpotPuzzle> plan;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  State<SpotGame> createState() => _SpotGameState();
}

class _SpotGameState extends State<SpotGame>
    with SingleTickerProviderStateMixin<SpotGame>, RoundClock<SpotGame> {
  int _index = 0;
  int _lockedUntil = -1;
  int _wrong = -1;

  @override
  int get durationMs => widget.durationMs;
  @override
  ValueChanged<int> get onDone => widget.onDone;
  @override
  bool get isOver => _index >= widget.plan.length;

  @override
  void onTick() {
    if (_wrong >= 0 && ms >= _lockedUntil) _wrong = -1;
  }

  void _tap(int tile) {
    if (done || isOver || ms < _lockedUntil) return;
    final right = tile == widget.plan[_index].odd;
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      if (right) {
        score += 1;
        _index += 1;
      } else {
        score -= 1;
        _wrong = tile;
        _lockedUntil = ms + _lockMs;
      }
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
        final p = widget.plan[_index];
        const gap = 10.0;
        final side = min(arena.width, arena.height) - 12;
        final tile = min((side - gap * (p.cols - 1)) / p.cols, 120.0);
        return Center(
          child: SizedBox(
            width: tile * p.cols + gap * (p.cols - 1),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var t = 0; t < p.count; t++)
                  Listener(
                    key: ValueKey('spot-$t'),
                    onPointerDown: (_) => _tap(t),
                    child: Container(
                      width: tile,
                      height: tile - Tone.dropSmall,
                      margin: const EdgeInsets.only(bottom: Tone.dropSmall),
                      alignment: Alignment.center,
                      decoration: inkDecoration(
                        color: t == _wrong ? Tone.tomato : _tints[p.tints[t]],
                        radius: tile * 0.24,
                        drop: Tone.dropSmall,
                      ),
                      child: Transform.rotate(
                        angle: (t == p.odd ? p.oddTurn : p.turn) * pi / 2,
                        child: Icon(Icons.arrow_upward_rounded, size: tile * 0.62, color: Tone.ink),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
