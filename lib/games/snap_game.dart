import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/game.dart';
import '../ui/kit.dart';
import 'round.dart';

const double _size = 72;

class _Pop {
  _Pop(this.x, this.y, this.points, this.at);
  final double x, y;
  final int points;
  final int at;
}

/// Snap : des pastilles apparaissent et rétrécissent, on touche les bonnes.
class SnapGame extends StatefulWidget {
  const SnapGame({super.key, required this.plan, required this.durationMs, required this.onDone});

  final List<Spawn> plan;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  State<SnapGame> createState() => _SnapGameState();
}

class _SnapGameState extends State<SnapGame>
    with SingleTickerProviderStateMixin<SnapGame>, RoundClock<SnapGame> {
  final Set<int> _hit = {};
  final List<_Pop> _pops = [];

  @override
  int get durationMs => widget.durationMs;
  @override
  ValueChanged<int> get onDone => widget.onDone;

  @override
  void onTick() => _pops.removeWhere((p) => ms - p.at > 600);

  void _tap(int i) {
    if (done || _hit.contains(i)) return;
    final s = widget.plan[i];
    final pts = pointsFor(s.kind);
    if (pts > 0) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _hit.add(i);
      score += pts;
      _pops.add(_Pop(s.x, s.y, pts, ms));
    });
  }

  bool _visible(int i) {
    final s = widget.plan[i];
    return !_hit.contains(i) && ms >= s.t && ms < s.t + s.life;
  }

  @override
  Widget build(BuildContext context) {
    return RoundFrame(
      score: score,
      ms: ms,
      durationMs: durationMs,
      builder: (context, arena) {
        final w = arena.width - _size, h = arena.height - _size;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const SizedBox.expand(),
            for (var i = 0; i < widget.plan.length; i++)
              if (_visible(i))
                Positioned(
                  left: w * widget.plan[i].x,
                  top: h * widget.plan[i].y,
                  child: Listener(
                    onPointerDown: (_) => _tap(i),
                    child: Transform.scale(
                      scale: 1 - 0.5 * (ms - widget.plan[i].t) / widget.plan[i].life,
                      child: _Target(widget.plan[i].kind),
                    ),
                  ),
                ),
            for (final p in _pops)
              Positioned(
                left: w * p.x + 18,
                top: h * p.y - 40 * ((ms - p.at) / 600),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: (1 - (ms - p.at) / 600).clamp(0.0, 1.0),
                    child: Text(
                      p.points > 0 ? '+${p.points}' : '−${-p.points}',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: p.points > 0 ? Tone.mint : Tone.tomato,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Target extends StatelessWidget {
  const _Target(this.kind);
  final Kind kind;

  @override
  Widget build(BuildContext context) {
    final color = switch (kind) { Kind.good => Tone.mint, Kind.gold => Tone.sun, Kind.trap => Tone.tomato };
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: inkDecoration(color: color, shape: BoxShape.circle, drop: Tone.dropSmall),
      child: switch (kind) {
        Kind.trap => const Icon(Icons.close_rounded, color: Colors.white, size: 36),
        Kind.gold => const Icon(Icons.bolt_rounded, color: Tone.ink, size: 34),
        Kind.good => null,
      },
    );
  }
}
