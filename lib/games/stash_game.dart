import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/games.dart';
import '../l10n/strings.dart';
import '../ui/kit.dart';
import 'round.dart';

const _resultMs = 450; // on montre la grille complète avant la suivante

enum _Phase { show, recall, result }

/// Stash : des cases s'allument un instant, puis s'éteignent. On les retrouve de mémoire.
class StashGame extends StatefulWidget {
  const StashGame({super.key, required this.plan, required this.durationMs, required this.onDone});

  final List<StashPattern> plan;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  State<StashGame> createState() => _StashGameState();
}

class _StashGameState extends State<StashGame>
    with SingleTickerProviderStateMixin<StashGame>, RoundClock<StashGame> {
  int _index = 0;
  int _phaseStart = 0; // la première grille s'affiche dès la fin du décompte
  _Phase _phase = _Phase.show;
  final Set<int> _found = {};
  int _wrong = -1;

  @override
  int get durationMs => widget.durationMs;
  @override
  ValueChanged<int> get onDone => widget.onDone;
  @override
  bool get isOver => _index >= widget.plan.length;

  // Les phases suivent l'horloge de la manche : affichage, rappel, résultat.
  @override
  void onTick() {
    if (isOver || ms < 0) return;
    if (_phase == _Phase.show && ms - _phaseStart >= widget.plan[_index].showMs) {
      _phase = _Phase.recall;
    } else if (_phase == _Phase.result && ms - _phaseStart >= _resultMs) {
      _index += 1;
      _phase = _Phase.show;
      _phaseStart = ms;
      _found.clear();
      _wrong = -1;
    }
  }

  void _tap(int cell) {
    if (done || isOver || _phase != _Phase.recall || _found.contains(cell)) return;
    final pattern = widget.plan[_index];
    final right = pattern.cells.contains(cell);
    if (right) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      if (right) {
        score += 1;
        _found.add(cell);
        if (_found.length < pattern.cells.length) return;
      } else {
        score -= 1;
        _wrong = cell;
      }
      // Grille finie ou ratée : on montre la solution, puis la suivante.
      _phase = _Phase.result;
      _phaseStart = ms;
    });
  }

  Color _tint(StashPattern p, int cell) {
    if (cell == _wrong) return Tone.tomato;
    if (_found.contains(cell)) return Tone.mint;
    final lit = p.cells.contains(cell);
    if (_phase == _Phase.show && lit) return Tone.sun;
    if (_phase == _Phase.result && lit) return Tone.sun;
    return Tone.paper;
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
        final side = min(arena.width, arena.height - 70) - 12;
        final tile = min((side - gap * (p.cols - 1)) / p.cols, 110.0);
        final s = S.of(context);
        final hint = switch (_phase) {
          _Phase.show => s.stashShow,
          _Phase.recall => s.stashRecall(_found.length, p.cells.length),
          _Phase.result => _wrong >= 0 ? s.stashMissed : s.stashAllFound,
        };
        return SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hint,
                style: const TextStyle(color: Tone.soft, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: tile * p.cols + gap * (p.cols - 1),
                child: Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var c = 0; c < p.count; c++)
                      Listener(
                        key: ValueKey('stash-$c'),
                        onPointerDown: (_) => _tap(c),
                        child: Container(
                          width: tile,
                          height: tile - Tone.dropSmall,
                          margin: const EdgeInsets.only(bottom: Tone.dropSmall),
                          decoration: inkDecoration(
                            color: _tint(p, c),
                            radius: tile * 0.24,
                            drop: Tone.dropSmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
