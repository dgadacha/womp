import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../core/game.dart';
import '../core/games.dart';
import '../core/live.dart';
import '../data/pass.dart';
import '../data/repo.dart';
import '../l10n/strings.dart';
import '../ui/kit.dart';
import 'language.dart';
import 'pass.dart';
import 'play.dart';

/// Délai entre l'ouverture d'une manche et son départ, le temps de lire les règles.
const autoStartMs = shortRound ? 1500 : 4000;

/// Le salon de la bande. Chacun joue sur son téléphone : un joueur lance, tout le
/// monde reçoit le même jeu au même moment, et le dernier prend son gage tout de suite.
class RoomScreen extends StatefulWidget {
  const RoomScreen({
    super.key,
    required this.repo,
    required this.crew,
    required this.onLeft,
    required this.locale,
    required this.onLocale,
    required this.pass,
    this.forcedGame,
  });

  final Repo repo;
  final Crew crew; // tenu à jour par l'app : membres, type de gages
  final VoidCallback onLeft;

  /// Langue choisie ('' = celle du téléphone) et de quoi la changer.
  final String locale;
  final ValueChanged<String> onLocale;

  /// Le Womp Pass : rien n'en apparaît tant que l'interrupteur du serveur est éteint.
  final PassController pass;

  /// Jeu imposé pour les essais sur l'émulateur.
  final GameId? forcedGame;

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  StreamSubscription<LiveState?>? _liveSub;
  StreamSubscription<Map<String, int>>? _scoreSub;

  bool _loaded = false;
  LiveState? _live;
  Map<String, int> _scores = {};
  int? _playingRound; // manche en train d'être jouée sur ce téléphone
  int? _pendingRound; // manche dont mon score n'est pas encore revenu du serveur
  int _pendingScore = 0;
  bool _busy = false;

  Timer? _autoTimer;
  Timer? _autoTick;
  DateTime? _autoAt; // départ automatique de la manche en cours

  Repo get _repo => widget.repo;
  Crew get _crew => widget.crew;
  bool get _party => _crew.darePack == packParty;

  GameId _gameOf(int round) => widget.forcedGame ?? liveGame(_crew.id, round);

  @override
  void initState() {
    super.initState();
    _liveSub = _repo.watchLive(_crew.id).listen(_onLive, onError: (_) {});
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _scoreSub?.cancel();
    _cancelAuto();
    super.dispose();
  }

  void _onLive(LiveState? live) {
    final wasLoaded = _loaded;
    final changed = live?.round != _live?.round;
    if (changed) {
      // Nouvelle manche : on suit ses scores, ceux de l'ancienne ne comptent plus.
      _scoreSub?.cancel();
      _scoreSub = live == null
          ? null
          : _repo.watchLiveScores(_crew.id, live.round).listen((s) {
              setState(() => _scores = s);
              if (s[_repo.uid] != null) _cancelAuto();
            }, onError: (_) {});
    }
    if (changed || live?.open != true) _cancelAuto();
    setState(() {
      _loaded = true;
      _live = live;
      if (changed) _scores = {};
    });
    // Une manche qui s'ouvre pendant qu'on est dans le salon démarre seule, sur chaque
    // téléphone. Celui qui arrive en cours de manche lance la sienne lui-même.
    if (wasLoaded && changed && live != null && live.open) _scheduleAuto(live.round);
  }

  bool _hasPlayed(int round) => _scores[_repo.uid] != null || _pendingRound == round;

  void _scheduleAuto(int round) {
    _cancelAuto();
    _autoAt = DateTime.now().add(const Duration(milliseconds: autoStartMs));
    _autoTick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
    _autoTimer = Timer(const Duration(milliseconds: autoStartMs), () {
      _cancelAuto();
      final live = _live;
      if (!mounted || live == null || !live.open || live.round != round || _hasPlayed(round)) return;
      setState(() => _playingRound = round);
    });
  }

  void _cancelAuto() {
    _autoTimer?.cancel();
    _autoTick?.cancel();
    _autoTimer = null;
    _autoTick = null;
    _autoAt = null;
  }

  void _play(int round) {
    _cancelAuto();
    setState(() => _playingRound = round);
  }

  void _finish(int round, int score) {
    _cancelAuto();
    setState(() {
      _playingRound = null;
      _pendingRound = round;
      _pendingScore = score;
    });
    _repo
        .postLiveScore(crewId: _crew.id, round: round, name: _crew.nameOf(_repo.uid), score: score)
        .catchError((_) {});
  }

  Future<void> _set(LiveState state) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final failed = S.of(context).liveFailed;
    try {
      await _repo.setLive(crewId: _crew.id, state: state);
    } catch (_) {
      // Quelqu'un d'autre a déjà changé de manche, ou le serveur refuse.
      messenger.showSnackBar(SnackBar(content: Text(failed)));
    }
    if (mounted) setState(() => _busy = false);
  }

  /// Ouvre la feuille de partage. Si elle échoue, le message part dans le presse-papiers.
  Future<void> _share(BuildContext btn) async {
    final messenger = ScaffoldMessenger.of(btn);
    final s = S.of(btn);
    final text = s.inviteText(_crew.code);
    final box = btn.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin));
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      messenger.showSnackBar(SnackBar(content: Text(s.inviteCopied)));
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String body,
    required String no,
    required String yes,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Tone.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Tone.radius),
          side: const BorderSide(color: Tone.ink, width: Tone.stroke),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(no, style: const TextStyle(color: Tone.ink, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(yes, style: const TextStyle(color: Tone.tomato, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  /// Le passage aux gages à boire demande une confirmation : la bande doit être adulte.
  /// Un pack du Pass sur une bande pas encore débloquée ouvre l'écran du Pass.
  Future<void> _pickPack(String pack) async {
    if (pack == _crew.darePack) return;
    if (passPacks.contains(pack) && !_crew.unlocked) return _openPass();
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (pack == packParty) {
      final yes = await _confirm(title: s.partyTitle, body: s.partyBody, no: s.keepClassic, yes: s.allAdults);
      if (yes != true) return;
    }
    try {
      await _repo.setDarePack(crewId: _crew.id, pack: pack);
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.switchFailed)));
    }
  }

  void _openPass() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PassScreen(pass: widget.pass)));
  }

  Future<void> _leave() async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final yes = await _confirm(title: s.leaveTitle, body: s.leaveBody, no: s.stay, yes: s.leave);
    if (yes != true) return;
    try {
      await _repo.leaveCrew(_crew.id);
      widget.onLeft();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s.liveFailed)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final live = _live;
    if (_playingRound != null) {
      final round = _playingRound!;
      return PlayScreen(
        key: ValueKey('live-$round'),
        game: _gameOf(round),
        day: liveSeed(_crew.id, round),
        durationMs: liveMs,
        onDone: (score) => _finish(round, score),
      );
    }

    final Widget body;
    if (!_loaded) {
      body = const SizedBox(height: 200);
    } else if (live == null || !live.open) {
      body = _lobby(live);
    } else {
      final uid = _repo.uid;
      final mine = _scores[uid] ?? (_pendingRound == live.round ? _pendingScore : null);
      body = mine == null ? _ready(live) : _results(live, {..._scores, uid: mine});
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
                Row(
                  children: [
                    LanguageButton(current: widget.locale, onPick: widget.onLocale),
                    const SizedBox(width: 8),
                    InkPill(label: S.of(context).leave, onTap: _leave),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            body,
          ],
        ),
      ),
    );
  }

  // ---------- Le salon, avant de jouer ----------

  Widget _lobby(LiveState? previous) {
    final s = S.of(context);
    final uid = _repo.uid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Overline(_crew.name),
              const SizedBox(height: 6),
              Text(
                s.everyoneHere,
                style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.05),
              ),
              const SizedBox(height: 10),
              Text(s.lobbyIntro(liveMs ~/ 1000), style: const TextStyle(fontSize: 16, height: 1.35)),
              const SizedBox(height: 16),
              Overline(s.inTheCrew(_crew.members.length)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _crew.members)
                    InkPill(
                      label: _crew.nameOf(m),
                      color: m == uid ? Tone.tomato : Tone.paper,
                      textColor: m == uid ? Colors.white : Tone.ink,
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkBox(
          color: Tone.sun,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Overline(s.crewCodeLabel, color: Tone.ink),
                    const SizedBox(height: 4),
                    Text(s.shareCode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SelectableText(
                _crew.code,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 3),
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
              Row(
                children: [
                  Expanded(child: Overline(s.daresTitle, color: Tone.tomato)),
                  if (_party) InkPill(label: s.partyBadge, color: Tone.tomato, textColor: Colors.white),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                s.packOn(_crew.darePack),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
              ),
              if (_party)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    s.waterCounts,
                    style: const TextStyle(color: Tone.ink, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              if (_crew.createdBy == uid && widget.pass.visible) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in darePacks)
                      InkPill(
                        label: passPacks.contains(p) && !_crew.unlocked ? '${s.packName(p)} · Pass' : s.packName(p),
                        color: p == _crew.darePack ? Tone.sun : Tone.paper,
                        onTap: () => _pickPack(p),
                      ),
                  ],
                ),
              ] else if (_crew.createdBy == uid)
                TextButton(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
                  onPressed: () => _pickPack(_party ? packClassic : packParty),
                  child: Text(
                    _party ? s.backToClassic : s.switchToParty,
                    style: const TextStyle(
                      color: Tone.ink,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.pass.visible) ...[
          const SizedBox(height: 12),
          _passCard(s, uid),
        ],
        const SizedBox(height: 16),
        Builder(
          builder: (btn) => InkButton(
            label: s.inviteFriends,
            color: Tone.paper,
            textColor: Tone.ink,
            onTap: () => _share(btn),
          ),
        ),
        const SizedBox(height: 10),
        InkButton(
          label: s.startGames,
          onTap: _busy ? null : () => _set(LiveState.start(previous)),
        ),
      ],
    );
  }

  /// Le Pass dans le salon : de quoi l'acheter, ou qui a débloqué la bande.
  Widget _passCard(S s, String uid) {
    if (_crew.unlocked) {
      return InkBox(
        color: Tone.mint,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Overline(passName, color: Tone.ink),
            const SizedBox(height: 6),
            Text(
              _crew.passBy == uid ? s.passUnlockedByYou : s.passUnlockedBy(_crew.nameOf(_crew.passBy)),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3),
            ),
            if (_crew.createdBy != uid)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s.passCreatorPicks(_crew.nameOf(_crew.createdBy)),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      );
    }
    return InkBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Overline(passName, color: Tone.tomato),
          const SizedBox(height: 6),
          Text(s.passPitch, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.3)),
          const SizedBox(height: 12),
          InkButton(label: s.passSee, color: Tone.sun, textColor: Tone.ink, onTap: _openPass),
        ],
      ),
    );
  }

  // ---------- Manche ouverte, pas encore jouée ----------

  Widget _ready(LiveState live) {
    final s = S.of(context);
    final played = _scores.length;
    final game = _gameOf(live.round);
    final rules = s.rules(game);
    final colors = _ruleColors[game]!;
    final at = _autoAt;
    final left = at == null ? null : (at.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(1, 9);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Overline(s.gameNumber(live.number)),
              const SizedBox(height: 6),
              Text(
                gameTitle(game),
                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900, letterSpacing: -2, height: 1.05),
              ),
              const SizedBox(height: 6),
              Text(s.roundIntro(liveMs ~/ 1000), style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              for (var i = 0; i < rules.length; i++) _Rule(color: colors[i], text: rules[i]),
              const SizedBox(height: 8),
              Text(
                played == 0 ? s.nobodyPlayedThis : s.alreadyPlayed(played, _crew.members.length),
                style: const TextStyle(color: Tone.soft, fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        if (left != null) ...[
          const SizedBox(height: 14),
          Center(
            child: Text(
              s.startsIn(left),
              style: const TextStyle(color: Tone.tomato, fontSize: 26, fontWeight: FontWeight.w900),
            ),
          ),
        ],
        const SizedBox(height: 16),
        InkButton(label: s.playNow, onTap: () => _play(live.round)),
        const SizedBox(height: 10),
        InkButton(
          label: s.endGames,
          color: Tone.paper,
          textColor: Tone.ink,
          onTap: _busy ? null : () => _set(live.end()),
        ),
      ],
    );
  }

  // ---------- Manche jouée : classement et gage immédiat ----------

  Widget _results(LiveState live, Map<String, int> scores) {
    final s = S.of(context);
    final uid = _repo.uid;
    final played = [for (final m in _crew.members) if (scores[m] != null) m]
      ..sort((a, b) => scores[b]!.compareTo(scores[a]!));
    final waiting = [for (final m in _crew.members) if (scores[m] == null) m];
    final enough = played.length >= 2;
    final last = played.isEmpty ? uid : played.last;
    final water = isWaterRound(_crew.darePack, live.number);
    final dare = s.dareFor(crewId: _crew.id, round: live.round, number: live.number, pack: _crew.darePack);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkBox(
          color: Tone.blush,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Overline(s.gameDare(live.number), color: Tone.tomato)),
                  if (_party) InkPill(label: s.partyBadge, color: Tone.tomato, textColor: Colors.white),
                ],
              ),
              const SizedBox(height: 8),
              if (!enough)
                Text(s.waitingOthers, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))
              else ...[
                if (!water)
                  Text(
                    last == uid ? s.itsOnYou : s.itsOn(_crew.nameOf(last)),
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -1),
                  ),
                const SizedBox(height: 4),
                Text(dare, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, height: 1.25)),
                if (_party && !water)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.waterCounts,
                      style: const TextStyle(color: Tone.ink, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                if (waiting.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      s.stillPlaying(waiting.map(_crew.nameOf).join(', ')),
                      style: const TextStyle(color: Tone.soft, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        InkBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gameTitle(_gameOf(live.round)),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 4),
              for (var i = 0; i < played.length; i++)
                _row('${i + 1}', _crew.nameOf(played[i]), '${scores[played[i]]}', me: played[i] == uid),
              for (final m in waiting) _row('·', _crew.nameOf(m), '–', faded: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkButton(label: s.nextGame, onTap: enough && !_busy ? () => _set(live.next()) : null),
        const SizedBox(height: 10),
        InkButton(
          label: s.endGames,
          color: Tone.paper,
          textColor: Tone.ink,
          onTap: _busy ? null : () => _set(live.end()),
        ),
      ],
    );
  }

  Widget _row(String rank, String name, String score, {bool me = false, bool faded = false}) {
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(rank, style: const TextStyle(color: Tone.soft, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: me ? Tone.tomato : Tone.ink),
              ),
            ),
            Text(score, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

/// Couleur de la pastille devant chaque règle, dans l'ordre des textes de [S.rules].
const _ruleColors = {
  GameId.snap: [Tone.mint, Tone.sun, Tone.tomato],
  GameId.spot: [Tone.ink, Tone.mint, Tone.tomato],
  GameId.stop: [Tone.ink, Tone.tomato, Tone.sun, Tone.paper],
  GameId.stash: [Tone.sun, Tone.mint, Tone.tomato],
};

class _Rule extends StatelessWidget {
  const _Rule({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: inkDecoration(color: color, shape: BoxShape.circle, drop: 0),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
