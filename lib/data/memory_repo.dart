import 'dart:async';

import 'repo.dart';

/// Version en mémoire du serveur, pour les tests. Elle applique les mêmes règles
/// que Firestore : un score par jour, 12 membres au plus.
class MemoryRepo implements Repo {
  MemoryRepo({this.uid = 'me'});

  @override
  final String uid;

  final Map<String, Crew> crews = {};
  final Map<String, String> crewOfUser = {};
  final Map<String, Map<String, int>> _scores = {};
  final Map<String, Map<String, Set<String>>> _reacts = {};
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
  Crew seedCrew({required String name, required Map<String, String> names, String code = 'ABC234'}) {
    final crew = Crew(
      id: 'crew${_next++}',
      name: name,
      code: code,
      members: names.keys.toList(),
      names: Map.of(names),
    );
    crews[crew.id] = crew;
    for (final u in names.keys) {
      crewOfUser[u] = crew.id;
    }
    return crew;
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
    final joined = Crew(
      id: crew.id,
      name: crew.name,
      code: crew.code,
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
  Stream<Map<String, int>> watchScores(String crewId, String day) =>
      _watch(() => Map.of(_scores['$crewId/$day'] ?? const {}));

  /// Score posé par un autre joueur (pour un test).
  void scoreAs(String who, String crewId, String day, int score) {
    _scores.putIfAbsent('$crewId/$day', () => {}).putIfAbsent(who, () => score);
    _bump();
  }

  @override
  Future<void> postScore({
    required String crewId,
    required String day,
    required String name,
    required int score,
  }) async =>
      scoreAs(uid, crewId, day, score);

  @override
  Stream<Map<String, Set<String>>> watchReactions(String crewId, String day) =>
      _watch(() => Map.of(_reacts['$crewId/$day'] ?? const {}));

  @override
  Future<void> setReactions({
    required String crewId,
    required String day,
    required Set<String> picks,
  }) async {
    _reacts.putIfAbsent('$crewId/$day', () => {})[uid] = Set.of(picks);
    _bump();
  }
}
