import 'dart:math';

/// Une bande d'amis.
class Crew {
  const Crew({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
    required this.names,
  });

  final String id;
  final String name;
  final String code; // code d'invitation à 6 caractères
  final List<String> members; // uid, dans l'ordre d'arrivée
  final Map<String, String> names; // uid -> prénom

  String nameOf(String uid) => names[uid] ?? '?';

  static Crew fromMap(String id, Map<String, dynamic> d) => Crew(
        id: id,
        name: d['name'] is String ? d['name'] as String : 'Crew',
        code: d['code'] is String ? d['code'] as String : '',
        members: [
          for (final m in (d['members'] is List ? d['members'] as List : const [])) if (m is String) m,
        ],
        names: {
          if (d['names'] is Map)
            for (final e in (d['names'] as Map).entries)
              if (e.key is String && e.value is String) e.key as String: e.value as String,
        },
      );
}

enum JoinProblem { badCode, unknownCode, fullOrRefused, offline }

class JoinFailure implements Exception {
  const JoinFailure(this.problem);
  final JoinProblem problem;

  String get message => switch (problem) {
        JoinProblem.badCode => 'A crew code is 6 letters and digits.',
        JoinProblem.unknownCode => 'No crew has that code.',
        JoinProblem.fullOrRefused => "That crew is full (12 max).",
        JoinProblem.offline => "Can't reach Womp. Check your connection.",
      };
}

const maxCrewSize = 12;

/// Sans I, O, 0 ni 1 : un code se dicte et se recopie sans erreur.
const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
final _codeRe = RegExp(r'^[A-Z2-9]{6}$');

String newCrewCode([Random? random]) {
  final r = random ?? Random.secure();
  return [for (var i = 0; i < 6; i++) _codeAlphabet[r.nextInt(_codeAlphabet.length)]].join();
}

/// Nettoie ce que l'utilisateur a tapé. Retourne null si ce n'est pas un code.
String? normalizeCode(String raw) {
  final c = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return _codeRe.hasMatch(c) ? c : null;
}

/// Tout ce que les écrans demandent au serveur. Deux versions :
/// Firestore pour l'app, mémoire pour les tests.
abstract class Repo {
  String get uid;

  /// Connecte l'appareil (compte anonyme).
  Future<void> init();

  /// La bande de l'utilisateur, ou null s'il n'en a pas encore.
  Future<Crew?> myCrew();

  Future<Crew> createCrew({required String crewName, required String myName});

  /// Lance [JoinFailure] si le code est faux ou la bande pleine.
  Future<Crew> joinCrew({required String code, required String myName});

  Stream<Crew> watchCrew(String crewId);

  /// uid -> score du jour.
  Stream<Map<String, int>> watchScores(String crewId, String day);

  /// Un seul score par joueur et par jour : un second envoi est ignoré.
  Future<void> postScore({
    required String crewId,
    required String day,
    required String name,
    required int score,
  });

  /// uid de celui qui réagit -> ses réactions, sous la forme « uidCible|emoji ».
  Stream<Map<String, Set<String>>> watchReactions(String crewId, String day);

  Future<void> setReactions({
    required String crewId,
    required String day,
    required Set<String> picks,
  });
}
