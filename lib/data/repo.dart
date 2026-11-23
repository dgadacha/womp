import 'dart:math';

import '../core/game.dart';

/// Une bande d'amis.
class Crew {
  const Crew({
    required this.id,
    required this.name,
    required this.code,
    required this.members,
    required this.names,
    this.createdBy = '',
    this.darePack = packClassic,
    this.passBy = '',
  });

  final String id;
  final String name;
  final String code; // code d'invitation à 6 caractères
  final List<String> members; // uid, dans l'ordre d'arrivée
  final Map<String, String> names; // uid -> prénom
  final String createdBy; // seul le créateur choisit le type de gages
  final String darePack; // un de [darePacks] ; absent côté serveur = classic

  /// uid du membre qui a débloqué la bande avec son Womp Pass, '' sinon.
  final String passBy;

  bool get unlocked => passBy.isNotEmpty;

  String nameOf(String uid) => names[uid] ?? '?';

  Crew copyWith({List<String>? members, Map<String, String>? names, String? darePack, String? passBy}) => Crew(
        id: id,
        name: name,
        code: code,
        members: members ?? this.members,
        names: names ?? this.names,
        createdBy: createdBy,
        darePack: darePack ?? this.darePack,
        passBy: passBy ?? this.passBy,
      );

  static Crew fromMap(String id, Map<String, dynamic> d) => Crew(
        id: id,
        name: d['name'] is String ? d['name'] as String : 'Crew',
        code: d['code'] is String ? d['code'] as String : '',
        members: [
          for (final m in (d['members'] is List ? d['members'] as List : const [])) if (m is String) m,
        ],
        createdBy: d['createdBy'] is String ? d['createdBy'] as String : '',
        darePack: darePacks.contains(d['dares']) ? d['dares'] as String : packClassic,
        passBy: d['passBy'] is String ? d['passBy'] as String : '',
        names: {
          if (d['names'] is Map)
            for (final e in (d['names'] as Map).entries)
              if (e.key is String && e.value is String) e.key as String: e.value as String,
        },
      );
}

/// État du mode instantané d'une bande. Le numéro de manche ne redescend jamais :
/// [base] est la première manche de la session en cours.
class LiveState {
  const LiveState({required this.round, required this.base, required this.open});
  final int round;
  final int base;
  final bool open;

  /// Rang du jeu dans la session : 1, 2, 3...
  int get number => round - base + 1;

  /// Première manche d'une nouvelle session.
  static LiveState start(LiveState? previous) {
    final round = (previous?.round ?? 0) + 1;
    return LiveState(round: round, base: round, open: true);
  }

  LiveState next() => LiveState(round: round + 1, base: base, open: true);
  LiveState end() => LiveState(round: round, base: base, open: false);
}

enum JoinProblem { badCode, unknownCode, fullOrRefused, offline }

class JoinFailure implements Exception {
  const JoinFailure(this.problem);
  final JoinProblem problem;

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

  /// Quitte la bande : on n'en est plus membre, et l'app repart de l'accueil.
  Future<void> leaveCrew(String crewId);

  /// Change le type de gages de la bande. Réservé à son créateur : lance une
  /// exception si le serveur refuse. Les packs du Pass demandent une bande débloquée.
  Future<void> setDarePack({required String crewId, required String pack});

  // ---------- Womp Pass ----------

  /// L'interrupteur du Pass, réglé à la main sur le serveur. Faux en cas de doute.
  Future<bool> passSwitch();

  /// Débloque la bande au nom de ce joueur, qui a le Pass. Une seule fois par bande.
  Future<void> unlockCrew(String crewId);

  // ---------- Mode instantané ----------

  /// null tant que la bande n'a jamais lancé le mode instantané.
  Stream<LiveState?> watchLive(String crewId);

  /// Démarre une session, passe au jeu suivant ou termine. Le serveur vérifie
  /// que la transition est permise et lance une exception sinon.
  Future<void> setLive({required String crewId, required LiveState state});

  /// uid -> score de la manche.
  Stream<Map<String, int>> watchLiveScores(String crewId, int round);

  /// Un seul score par joueur et par manche. Ignoré si la manche est déjà passée.
  Future<void> postLiveScore({
    required String crewId,
    required int round,
    required String name,
    required int score,
  });
}
