import 'package:flutter/material.dart';

import '../config.dart';
import '../core/game.dart';
import '../data/repo.dart';
import '../ui/kit.dart';

/// Avant de jouer : le jeu du jour et où en est la bande.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.crew,
    required this.scores,
    required this.day,
    required this.streak,
    required this.onPlay,
  });

  final Crew crew;
  final Map<String, int> scores;
  final String day;
  final int streak;
  final VoidCallback onPlay;

  String get _nudge {
    if (crew.members.length == 1) return "It's just you so far. Play, then invite your crew.";
    if (scores.isEmpty) return 'Nobody has played yet. Go first.';
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return '${crew.nameOf(best.key)} scored ${best.value}. Beat that.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Logo(name: appName),
                          InkPill(label: 'Streak $streak', color: Tone.ink, textColor: Colors.white),
                        ],
                      ),
                      const SizedBox(height: 20),
                      InkBox(
                        color: Tone.sun,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Overline(
                              '${crew.name} · ${scores.length} of ${crew.members.length} played',
                              color: Tone.ink,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _nudge,
                              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.2),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkBox(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Overline("Today's game · ${prettyDay(day)}"),
                            const SizedBox(height: 6),
                            const Text(
                              gameName,
                              style: TextStyle(
                                fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: -1.5, height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${roundMs ~/ 1000} seconds. One try. Everyone gets the exact same round.',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 14),
                            const _Rule(color: Tone.mint, text: 'Green: +1'),
                            const _Rule(color: Tone.sun, text: 'Yellow: +3, gone in a blink'),
                            const _Rule(color: Tone.tomato, text: "Red: −3, don't touch"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              InkButton(label: 'Play', onTap: onPlay),
            ],
          ),
        ),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: inkDecoration(color: color, shape: BoxShape.circle, drop: 0),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
