import 'dart:async';

import '../core/game.dart';
import 'repo.dart';

/// Version en mémoire du serveur, pour les tests. Elle applique les mêmes règles
/// que Firestore : 12 membres au plus, une manche qui ne fait qu'avancer.
class MemoryRepo implements Repo {
  MemoryRepo({this.uid = 'me', this.passOn = false});

  @override
  final String uid;

  /// L'interrupteur du Pass côté serveur.
  bool passOn;

  final Map<String, Crew> crews = {};
  final Map<String, String> crewOfUser = {};
  final _changed = StreamController<void>.broadcast();
  int _next = 1;

  void _bump() => _changed.add(null);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changed.stream) {
      yield read();
    }
  }

  @override
  Future<void> init() async {}

  @override
  Future<Crew?> myCrew() async => crews[crewOfUser[uid]];

  /// Ajoute une bande toute faite (pour préparer un test).
  Crew seedCrew({
    required String name,
    required Map<String, String> names,
    String code = 'ABC234',
    String passBy = '',
  }) {
    final crew = Crew(
      id: 'crew${_next++}',
      name: name,
      code: code,
      members: names.keys.toList(),
      names: Map.of(names),
      createdBy: names.keys.first,
      passBy: passBy,
    );
    crews[crew.id] = crew;
    for (final u in names.keys) {
      crewOfUser[u] = crew.id;
    }
    return crew;
  }

  /// Change une bande comme le ferait un autre joueur (pour un test).
  void updateCrew(String crewId, Crew Function(Crew) change) {
    crews[crewId] = change(crews[crewId]!);
    _bump();
  }

  @override
  Future<Crew> createCrew({required String crewName, required String myName}) async {
    final crew = seedCrew(name: crewName, names: {uid: myName}, code: newCrewCode());
    _bump();
    return crew;
  }

  @override
  Future<Crew> joinCrew({required String code, required String myName}) async {
    final clean = normalizeCode(code);
    if (clean == null) throw const JoinFailure(JoinProblem.badCode);
    final crew = crews.values.where((c) => c.code == clean).firstOrNull;
    if (crew == null) throw const JoinFailure(JoinProblem.unknownCode);
    if (!crew.members.contains(uid) && crew.members.length >= maxCrewSize) {
      throw const JoinFailure(JoinProblem.fullOrRefused);
    }
    final joined = crew.copyWith(
      members: [...crew.members, if (!crew.members.contains(uid)) uid],
      names: {...crew.names, uid: myName},
    );
    crews[crew.id] = joined;
    crewOfUser[uid] = crew.id;
    _bump();
    return joined;
  }

  @override
  Stream<Crew> watchCrew(String crewId) => _watch(() => crews[crewId]!);

  @override
  Future<void> leaveCrew(String crewId) async {
    final crew = crews[crewId]!;
    crews[crewId] = crew.copyWith(members: [for (final m in crew.members) if (m != uid) m]);
    crewOfUser.remove(uid);
    _bump();
  }

  @override
  Future<void> setDarePack({required String crewId, required String pack}) async {
    final crew = crews[crewId]!;
    if (crew.createdBy != uid || !darePacks.contains(pack) || (passPacks.contains(pack) && !crew.unlocked)) {
      throw StateError('permission-denied');
    }
    crews[crewId] = crew.copyWith(darePack: pack);
    _bump();
  }

  @override
  Future<bool> passSwitch() async => passOn;

  @override
  Future<void> unlockCrew(String crewId) async {
    final crew = crews[crewId]!;
    if (!crew.members.contains(uid) || crew.unlocked) throw StateError('permission-denied');
    crews[crewId] = crew.copyWith(passBy: uid);
    _bump();
  }

  final Map<String, LiveState> _live = {};
  final Map<String, Map<String, int>> _liveScores = {};

  @override
  Stream<LiveState?> watchLive(String crewId) => _watch(() => _live[crewId]);

  @override
  Future<void> setLive({required String crewId, required LiveState state}) async {
    final old = _live[crewId];
    final ok = old == null
        ? state.round == 1 && state.base == 1 && state.open
        : old.open
            ? state.base == old.base &&
                ((state.open && state.round == old.round + 1) || (!state.open && state.round == old.round))
            : state.open && state.round == old.round + 1 && state.base == state.round;
    if (!ok) throw StateError('permission-denied');
    _live[crewId] = state;
    _bump();
  }

  @override
  Stream<Map<String, int>> watchLiveScores(String crewId, int round) =>
      _watch(() => Map.of(_liveScores['$crewId/$round'] ?? const {}));

  /// Scores d'une manche, pour vérifier un test.
  Map<String, int> liveScores(String crewId, int round) => Map.of(_liveScores['$crewId/$round'] ?? const {});

  /// Score de manche posé par un autre joueur (pour un test).
  void liveScoreAs(String who, String crewId, int round, int score) {
    final live = _live[crewId];
    if (live == null || !live.open || live.round != round) return;
    _liveScores.putIfAbsent('$crewId/$round', () => {}).putIfAbsent(who, () => score);
    _bump();
  }

  @override
  Future<void> postLiveScore({
    required String crewId,
    required int round,
    required String name,
    required int score,
  }) async =>
      liveScoreAs(uid, crewId, round, score);
}
