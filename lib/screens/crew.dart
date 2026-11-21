import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../core/game.dart';
import '../data/repo.dart';
import '../ui/kit.dart';

const _reactions = ['😂', '🔥', '💀'];

/// Après avoir joué : le classement de la bande, en direct.
class CrewScreen extends StatelessWidget {
  const CrewScreen({
    super.key,
    required this.crew,
    required this.uid,
    required this.scores,
    required this.reactions,
    required this.day,
    required this.streak,
    required this.onReact,
  });

  final Crew crew;
  final String uid;
  final Map<String, int> scores; // uid -> score du jour
  final Map<String, Set<String>> reactions; // uid -> « uidCible|emoji »
  final String day;
  final int streak;
  final ValueChanged<Set<String>> onReact;

  String get _inviteText => 'Join my crew on $appName: one tiny game a day, last place takes the dare.\n'
      'Crew code: ${crew.code}';

  /// Ouvre la feuille de partage. Si elle échoue, le message part dans le presse-papiers.
  Future<void> _share(BuildContext btn) async {
    final messenger = ScaffoldMessenger.of(btn);
    final box = btn.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(ShareParams(text: _inviteText, sharePositionOrigin: origin));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: _inviteText));
      messenger.showSnackBar(
        const SnackBar(content: Text('Invite copied. Paste it in your crew chat.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final played = [for (final m in crew.members) if (scores[m] != null) m]
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final waiting = [for (final m in crew.members) if (scores[m] == null) m];
    final rank = 1 + played.indexOf(uid);
    final mine = reactions[uid] ?? const <String>{};
    final alone = crew.members.length == 1;

    final String verdict;
    if (alone) {
      verdict = 'First score on the board.';
    } else if (played.length == 1) {
      verdict = "You're first in. Now make them sweat.";
    } else if (rank == 1) {
      verdict = 'Top of the crew.';
    } else if (rank == played.length && waiting.isEmpty) {
      verdict = 'Last place. The dare is coming for you.';
    } else if (rank == played.length) {
      verdict = 'Last so far. Pray someone does worse.';
    } else {
      verdict = '${ordinal(rank)} of ${played.length} so far.';
    }

    final String dareOn;
    if (played.length < 2) {
      dareOn = 'It lands on whoever is last on Sunday.';
    } else {
      final last = played.last;
      dareOn = "Right now it's on ${last == uid ? 'you' : crew.nameOf(last)}.";
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 20 + MediaQuery.of(context).padding.bottom),
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
              color: Tone.tomato,
              child: Column(
                children: [
                  Overline("Today's game · ${prettyDay(day)}", color: Colors.white),
                  Text(
                    '${scores[uid]}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 84,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -3,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    verdict,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    crew.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < played.length; i++)
                    _PlayerRow(
                      rank: '${i + 1}',
                      name: crew.nameOf(played[i]),
                      score: '${scores[played[i]]}',
                      isMe: played[i] == uid,
                      divider: i > 0,
                      pills: [
                        for (final emoji in _reactions) _reaction(played[i], emoji, mine),
                      ],
                    ),
                  for (final m in waiting)
                    _PlayerRow(
                      rank: '·',
                      name: crew.nameOf(m),
                      score: '–',
                      isMe: false,
                      divider: true,
                      faded: true,
                    ),
                  if (alone)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'A crew of one is just a diary. Invite your friends.',
                        style: TextStyle(color: Tone.soft, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkBox(
              color: Tone.blush,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Overline("Sunday's dare", color: Tone.tomato),
                  const SizedBox(height: 6),
                  Text(
                    dareOfWeek(day),
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, height: 1.25),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    dareOn,
                    style: const TextStyle(color: Tone.soft, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            InkBox(
              color: Tone.sun,
              child: Row(
                children: [
                  const Expanded(child: Overline('Crew code', color: Tone.ink)),
                  SelectableText(
                    crew.code,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (btn) => InkButton(label: 'Invite my crew', onTap: () => _share(btn)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reaction(String target, String emoji, Set<String> mine) {
    final key = '$target|$emoji';
    final count = reactions.values.where((picks) => picks.contains(key)).length;
    final on = mine.contains(key);
    return InkPill(
      label: count > 0 ? '$emoji $count' : emoji,
      color: on ? Tone.sun : Tone.paper,
      onTap: () => onReact(on ? ({...mine}..remove(key)) : {...mine, key}),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.rank,
    required this.name,
    required this.score,
    required this.isMe,
    required this.divider,
    this.pills = const [],
    this.faded = false,
  });

  final String rank;
  final String name;
  final String score;
  final bool isMe;
  final bool divider;
  final List<Widget> pills;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: divider ? const Border(top: BorderSide(color: Color(0xFFECDFC6), width: 2)) : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                rank,
                style: const TextStyle(color: Tone.soft, fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isMe ? Tone.tomato : Tone.ink,
                    ),
                  ),
                  if (faded)
                    const Text(
                      'Not played yet',
                      style: TextStyle(color: Tone.soft, fontSize: 13, fontWeight: FontWeight.w600),
                    )
                  else ...[
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, children: pills),
                  ],
                ],
              ),
            ),
            Text(
              score,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
    );
  }
}
