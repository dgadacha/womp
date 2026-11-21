import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../config.dart';
import '../core/game.dart';
import '../ui/kit.dart';

const double _size = 72;

class _Pop {
  _Pop(this.x, this.y, this.points, this.at);
  final double x, y;
  final int points;
  final int at;
}

class PlayScreen extends StatefulWidget {
  const PlayScreen({
    super.key,
    required this.plan,
    required this.durationMs,
    required this.onDone,
  });

  final List<Spawn> plan;
  final int durationMs;
  final ValueChanged<int> onDone;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> with SingleTickerProviderStateMixin {
  static const _countMs = shortRound ? 600 : 2100;

  late final Ticker _ticker;
  final Set<int> _hit = {};
  final List<_Pop> _pops = [];
  int _ms = -_countMs; // temps de jeu ; négatif pendant le décompte
  int _score = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // Tout part du temps écoulé, jamais d'un compteur d'images.
    _ticker = createTicker((elapsed) {
      if (_done) return;
      setState(() {
        _ms = elapsed.inMilliseconds - _countMs;
        _pops.removeWhere((p) => _ms - p.at > 600);
      });
      if (_ms >= widget.durationMs) {
        _done = true;
        _ticker.stop();
        widget.onDone(_score);
      }
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tap(int i) {
    if (_done || _hit.contains(i)) return;
    final s = widget.plan[i];
    final pts = pointsFor(s.kind);
    if (pts > 0) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _hit.add(i);
      _score += pts;
      _pops.add(_Pop(s.x, s.y, pts, _ms));
    });
  }

  @override
  Widget build(BuildContext context) {
    final left = (1 - _ms / widget.durationMs).clamp(0.0, 1.0);
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
                      '$_score',
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
                        widthFactor: _ms < 0 ? 1 : left,
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
                      final w = box.maxWidth - _size, h = box.maxHeight - _size;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const SizedBox.expand(),
                          if (_ms < 0)
                            Center(
                              child: Text(
                                '${(-_ms / (_countMs / 3)).ceil().clamp(1, 3)}',
                                style: const TextStyle(fontSize: 110, fontWeight: FontWeight.w900),
                              ),
                            ),
                          for (var i = 0; i < widget.plan.length; i++)
                            if (_visible(i))
                              Positioned(
                                left: w * widget.plan[i].x,
                                top: h * widget.plan[i].y,
                                child: Listener(
                                  onPointerDown: (_) => _tap(i),
                                  child: Transform.scale(
                                    scale: 1 - 0.5 * (_ms - widget.plan[i].t) / widget.plan[i].life,
                                    child: _Target(widget.plan[i].kind),
                                  ),
                                ),
                              ),
                          for (final p in _pops)
                            Positioned(
                              left: w * p.x + 18,
                              top: h * p.y - 40 * ((_ms - p.at) / 600),
                              child: IgnorePointer(
                                child: Opacity(
                                  opacity: (1 - (_ms - p.at) / 600).clamp(0.0, 1.0),
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
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _visible(int i) {
    final s = widget.plan[i];
    return !_hit.contains(i) && _ms >= s.t && _ms < s.t + s.life;
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
