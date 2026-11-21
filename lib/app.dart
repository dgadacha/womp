import 'dart:async';

import 'package:flutter/material.dart';

import 'config.dart';
import 'core/game.dart';
import 'core/games.dart';
import 'core/store.dart';
import 'data/repo.dart';
import 'firebase_config.dart' show useEmulator;
import 'screens/crew.dart';
import 'screens/home.dart';
import 'screens/onboarding.dart';
import 'screens/play.dart';
import 'ui/kit.dart';

/// Racine de l'app : connecte l'appareil, retrouve la bande, puis suit en direct
/// la bande, les scores du jour et les réactions.
class WompApp extends StatefulWidget {
  const WompApp({super.key, required this.store, required this.repo});
  final Store store;
  final Repo repo;

  @override
  State<WompApp> createState() => _WompAppState();
}

class _WompAppState extends State<WompApp> {
  final String _day = dayKey();
  // Forcer un jeu fausserait le classement d'une vraie bande : seulement sur l'émulateur.
  late final GameId _game = (useEmulator ? gameNamed(forcedGame) : null) ?? gameOfDay(_day);
  final List<StreamSubscription<void>> _subs = [];

  bool _booting = true;
  bool _bootFailed = false;
  Crew? _crew;
  Map<String, int>? _scores; // null tant que le premier relevé n'est pas arrivé
  Map<String, Set<String>> _reactions = {};
  int? _pending; // mon score, affiché avant que le serveur ne le renvoie
  bool _playing = false;

  Store get _store => widget.store;
  Repo get _repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _boot() async {
    setState(() {
      _booting = true;
      _bootFailed = false;
    });
    try {
      await _repo.init();
      final crew = await _repo.myCrew();
      if (!mounted) return;
      if (crew != null) {
        _enter(crew);
      } else {
        setState(() => _booting = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _booting = false;
          _bootFailed = true;
        });
      }
    }
  }

  void _enter(Crew crew) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs
      ..clear()
      ..add(_repo.watchCrew(crew.id).listen((c) => setState(() => _crew = c), onError: (_) {}))
      ..add(_repo.watchScores(crew.id, _day).listen((s) => setState(() => _scores = s), onError: (_) {}))
      ..add(_repo
          .watchReactions(crew.id, _day)
          .listen((r) => setState(() => _reactions = r), onError: (_) {}));
    setState(() {
      _crew = crew;
      _scores = null;
      _booting = false;
    });
  }

  Future<String?> _join(Future<Crew> Function() action, String name) async {
    try {
      final crew = await action();
      _store.name = name;
      _store.save();
      if (mounted) _enter(crew);
      return null;
    } on JoinFailure catch (e) {
      return e.message;
    } catch (_) {
      return const JoinFailure(JoinProblem.offline).message;
    }
  }

  void _finishRound(int score) {
    final crew = _crew!;
    _store.day(_day).me = score;
    _store.save();
    setState(() {
      _pending = score;
      _playing = false;
    });
    _repo
        .postScore(crewId: crew.id, day: _day, name: crew.nameOf(_repo.uid), score: score)
        .catchError((_) {});
  }

  void _react(Set<String> picks) {
    setState(() => _reactions = {..._reactions, _repo.uid: picks});
    _repo.setReactions(crewId: _crew!.id, day: _day, picks: picks).catchError((_) {});
  }

  Widget _screen() {
    if (_bootFailed) return _Message(text: "Can't reach $appName.\nCheck your connection.", onRetry: _boot);
    final crew = _crew;
    if (_booting || (crew != null && _scores == null)) return const _Message();
    if (crew == null) {
      return OnboardingScreen(
        name: _store.name.isNotEmpty ? _store.name : cleanName(initialName),
        onCreate: (name) => _join(
          () => _repo.createCrew(crewName: "$name's crew", myName: name),
          name,
        ),
        onJoin: (name, code) => _join(() => _repo.joinCrew(code: code, myName: name), name),
      );
    }
    if (_playing) {
      return PlayScreen(game: _game, day: _day, durationMs: roundMs, onDone: _finishRound);
    }
    final uid = _repo.uid;
    // Le score du serveur fait foi : c'est le premier posté qui compte.
    final mine = _scores![uid] ?? _pending;
    if (mine == null) {
      return HomeScreen(
        crew: crew,
        game: _game,
        scores: _scores!,
        day: _day,
        streak: _store.streak(),
        onPlay: () => setState(() => _playing = true),
      );
    }
    return CrewScreen(
      crew: crew,
      uid: uid,
      scores: {..._scores!, uid: mine},
      reactions: _reactions,
      day: _day,
      streak: _store.streak(),
      onReact: _react,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: Tone.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: Tone.tomato, surface: Tone.bg),
        textTheme: ThemeData.light().textTheme.apply(bodyColor: Tone.ink, displayColor: Tone.ink),
      ),
      home: _screen(),
    );
  }
}

/// Écran d'attente, ou d'erreur avec un bouton pour réessayer.
class _Message extends StatelessWidget {
  const _Message({this.text, this.onRetry});
  final String? text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Logo(name: appName),
              if (text != null) ...[
                const SizedBox(height: 20),
                Text(
                  text!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                InkButton(label: 'Try again', onTap: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
