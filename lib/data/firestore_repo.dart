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
    if (_auth.currentUser == null) await _auth.signInAnonymously();
  }

  DocumentReference<Map<String, dynamic>> _crew(String id) => _db.collection('crews').doc(id);
  DocumentReference<Map<String, dynamic>> get _me => _db.collection('users').doc(uid);
  CollectionReference<Map<String, dynamic>> _day(String crewId, String day, String what) =>
      _crew(crewId).collection('days').doc(day).collection(what);

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
        return Crew(id: ref.id, name: crewName, code: code, members: [uid], names: {uid: myName});
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
  Stream<Map<String, int>> watchScores(String crewId, String day) =>
      _day(crewId, day, 'scores').snapshots().map((snap) => {
            for (final d in snap.docs)
              if (d.data()['score'] is int) d.id: d.data()['score'] as int,
          });

  @override
  Future<void> postScore({
    required String crewId,
    required String day,
    required String name,
    required int score,
  }) async {
    try {
      await _day(crewId, day, 'scores').doc(uid).set({
        'name': name,
        'score': score,
        'at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // Déjà un score ce jour-là : le premier reste, c'est la règle du jeu.
      if (e.code != 'permission-denied') rethrow;
    }
  }

  @override
  Stream<Map<String, Set<String>>> watchReactions(String crewId, String day) =>
      _day(crewId, day, 'reactions').snapshots().map((snap) => {
            for (final d in snap.docs)
              d.id: {
                for (final p in (d.data()['picks'] is List ? d.data()['picks'] as List : const []))
                  if (p is String) p,
              },
          });

  @override
  Future<void> setReactions({
    required String crewId,
    required String day,
    required Set<String> picks,
  }) =>
      _day(crewId, day, 'reactions').doc(uid).set({'picks': picks.take(40).toList()});
}
