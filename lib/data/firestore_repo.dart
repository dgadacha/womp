import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../firebase_config.dart';
import 'repo.dart';

class FirestoreRepo implements Repo {
  FirebaseFirestore get _db => firestore;
  FirebaseAuth get _auth => auth;

  @override
  String get uid => _auth.currentUser!.uid;

  @override
  Future<void> init() async {
    final user = _auth.currentUser;
    if (user != null) {
      // Le téléphone garde le compte même après une réinstallation. S'il n'existe
      // plus côté serveur, on repart d'un compte neuf au lieu de rester bloqué.
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (e.code == 'network-request-failed') return; // hors ligne : on garde le compte
        await _auth.signOut();
      }
    }
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  DocumentReference<Map<String, dynamic>> _crew(String id) => _db.collection('crews').doc(id);
  DocumentReference<Map<String, dynamic>> get _me => _db.collection('users').doc(uid);

  @override
  Future<Crew?> myCrew() async {
    final me = await _me.get();
    final crewId = me.data()?['crewId'];
    if (crewId is! String || crewId.isEmpty) return null;
    try {
      final doc = await _crew(crewId).get();
      return doc.exists ? Crew.fromMap(doc.id, doc.data()!) : null;
    } on FirebaseException catch (e) {
      // Plus membre de cette bande : on repart de l'accueil.
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  @override
  Future<Crew> createCrew({required String crewName, required String myName}) async {
    FirebaseException? last;
    // Un code déjà pris fait échouer l'écriture : on retente avec un autre.
    for (var attempt = 0; attempt < 4; attempt++) {
      final code = newCrewCode();
      final ref = _db.collection('crews').doc();
      final data = {
        'name': crewName,
        'code': code,
        'members': [uid],
        'names': {uid: myName},
        'createdBy': uid,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final batch = _db.batch()
        ..set(ref, data)
        ..set(_db.collection('invites').doc(code), {'crewId': ref.id})
        ..set(_me, {'crewId': ref.id, 'name': myName});
      try {
        await batch.commit();
        return Crew(
          id: ref.id,
          name: crewName,
          code: code,
          members: [uid],
          names: {uid: myName},
          createdBy: uid,
        );
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') rethrow;
        last = e;
      }
    }
    throw last!;
  }

  @override
  Future<Crew> joinCrew({required String code, required String myName}) async {
    final clean = normalizeCode(code);
    if (clean == null) throw const JoinFailure(JoinProblem.badCode);
    try {
      final invite = await _db.collection('invites').doc(clean).get();
      final crewId = invite.data()?['crewId'];
      if (crewId is! String) throw const JoinFailure(JoinProblem.unknownCode);
      // On ne peut pas lire la bande avant d'en être membre : on s'y ajoute à l'aveugle,
      // et les règles refusent si elle est pleine.
      await _crew(crewId).update({
        'members': FieldValue.arrayUnion([uid]),
        'names.$uid': myName,
      });
      await _me.set({'crewId': crewId, 'name': myName});
      final doc = await _crew(crewId).get();
      return Crew.fromMap(doc.id, doc.data()!);
    } on FirebaseException catch (e) {
      throw JoinFailure(
        e.code == 'permission-denied' ? JoinProblem.fullOrRefused : JoinProblem.offline,
      );
    }
  }

  @override
  Stream<Crew> watchCrew(String crewId) => _crew(crewId)
      .snapshots()
      .where((d) => d.exists)
      .map((d) => Crew.fromMap(d.id, d.data()!));

  @override
  Future<void> leaveCrew(String crewId) async {
    await _crew(crewId).update({'members': FieldValue.arrayRemove([uid])});
    await _me.update({'crewId': ''});
  }

  @override
  Future<void> setDarePack({required String crewId, required String pack}) =>
      _crew(crewId).update({'dares': pack});

  @override
  Future<bool> passSwitch() async {
    try {
      final doc = await _db.collection('config').doc('app').get();
      return doc.data()?['pass'] == true;
    } catch (_) {
      return false; // document absent, règles pas encore déployées, hors ligne : Pass caché
    }
  }

  @override
  Future<void> unlockCrew(String crewId) => _crew(crewId).update({'passBy': uid});

  DocumentReference<Map<String, dynamic>> _live(String crewId) =>
      _crew(crewId).collection('live').doc('state');

  CollectionReference<Map<String, dynamic>> _liveScores(String crewId, int round) =>
      _live(crewId).collection('rounds').doc('$round').collection('scores');

  @override
  Stream<LiveState?> watchLive(String crewId) => _live(crewId).snapshots().map((d) {
        final data = d.data();
        if (data == null || data['round'] is! int) return null;
        return LiveState(
          round: data['round'] as int,
          base: data['base'] is int ? data['base'] as int : data['round'] as int,
          open: data['open'] == true,
        );
      });

  @override
  Future<void> setLive({required String crewId, required LiveState state}) => _live(crewId).set({
        'round': state.round,
        'base': state.base,
        'open': state.open,
        'by': uid,
        'at': FieldValue.serverTimestamp(),
      });

  @override
  Stream<Map<String, int>> watchLiveScores(String crewId, int round) =>
      _liveScores(crewId, round).snapshots().map((snap) => {
            for (final d in snap.docs)
              if (d.data()['score'] is int) d.id: d.data()['score'] as int,
          });

  @override
  Future<void> postLiveScore({
    required String crewId,
    required int round,
    required String name,
    required int score,
  }) async {
    try {
      await _liveScores(crewId, round).doc(uid).set({
        'name': name,
        'score': score,
        'at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Manche déjà passée ou score déjà posté : on laisse tomber.
      if (e.code != 'permission-denied') rethrow;
    }
  }
}
