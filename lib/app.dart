import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'config.dart';
import 'core/game.dart';
import 'core/games.dart';
import 'core/store.dart';
import 'data/repo.dart';
import 'firebase_config.dart' show useEmulator;
import 'l10n/strings.dart';
import 'screens/onboarding.dart';
import 'screens/room.dart';
import 'ui/kit.dart';

/// Racine de l'app : connecte l'appareil, retrouve la bande et la suit en direct.
/// Sans bande, on arrive sur l'accueil ; avec une bande, dans son salon de jeu.
class WompApp extends StatefulWidget {
  const WompApp({super.key, required this.store, required this.repo, this.locale});
  final Store store;
  final Repo repo;

  /// Langue imposée (tests, --dart-define=LOCALE=fr). Sinon, celle du téléphone.
  final Locale? locale;

  @override
  State<WompApp> createState() => _WompAppState();
}

class _WompAppState extends State<WompApp> {
  // Forcer un jeu fausserait une vraie partie : seulement sur l'émulateur.
  final GameId? _forcedGame = useEmulator ? gameNamed(forcedGame) : null;
  StreamSubscription<Crew>? _crewSub;

  bool _booting = true;
  bool _bootFailed = false;
  Crew? _crew;

  Store get _store => widget.store;
  Repo get _repo => widget.repo;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  @override
  void dispose() {
    _crewSub?.cancel();
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
    _crewSub?.cancel();
    _crewSub = _repo.watchCrew(crew.id).listen((c) => setState(() => _crew = c), onError: (_) {});
    setState(() {
      _crew = crew;
      _booting = false;
    });
  }

  void _left() {
    _crewSub?.cancel();
    _crewSub = null;
    setState(() => _crew = null);
  }

  void _setLocale(String code) {
    _store.locale = code;
    _store.save();
    setState(() {});
  }

  Future<JoinProblem?> _join(Future<Crew> Function() action, String name) async {
    try {
      final crew = await action();
      _store.name = name;
      _store.save();
      if (mounted) _enter(crew);
      return null;
    } on JoinFailure catch (e) {
      return e.problem;
    } catch (_) {
      return JoinProblem.offline;
    }
  }

  Widget _screen() {
    if (_bootFailed) return _Message(failed: true, onRetry: _boot);
    if (_booting) return const _Message();
    final crew = _crew;
    if (crew == null) {
      return OnboardingScreen(
        name: _store.name.isNotEmpty ? _store.name : cleanName(initialName),
        onCreate: (name, crewName) => _join(
          () => _repo.createCrew(crewName: crewName, myName: name),
          name,
        ),
        onJoin: (name, code) => _join(() => _repo.joinCrew(code: code, myName: name), name),
        locale: _store.locale,
        onLocale: _setLocale,
      );
    }
    return RoomScreen(
      key: ValueKey(crew.id),
      repo: _repo,
      crew: crew,
      onLeft: _left,
      locale: _store.locale,
      onLocale: _setLocale,
      forcedGame: _forcedGame,
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
      // Ordre : langue imposée par un test, choix fait dans l'app, option de compilation, téléphone.
      locale: widget.locale ??
          (_store.locale.isNotEmpty
              ? Locale(_store.locale)
              : (forcedLocale.isEmpty ? null : Locale(forcedLocale))),
      supportedLocales: S.supportedLocales,
      localizationsDelegates: const [
        SDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _screen(),
    );
  }
}

/// Écran d'attente, ou d'erreur avec un bouton pour réessayer.
class _Message extends StatelessWidget {
  const _Message({this.failed = false, this.onRetry});
  final bool failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SafeArea(
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Logo(name: appName),
              if (failed) ...[
                const SizedBox(height: 20),
                Text(
                  s.cantReach,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 20),
                InkButton(label: s.tryAgain, onTap: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
