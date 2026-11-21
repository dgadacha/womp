import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

/// Par défaut l'app parle au vrai projet Firebase (womp-crew).
/// Avec --dart-define=EMULATOR=true elle parle à l'émulateur local
/// (`firebase emulators:start --project demo-womp --only auth,firestore`),
/// sous un identifiant de projet « demo- » qui ne peut rien écrire en ligne.
const bool useEmulator = bool.fromEnvironment('EMULATOR');
const int authPort = 9199;
const int firestorePort = 8180;

FirebaseOptions get _demoOptions => FirebaseOptions(
      apiKey: 'demo-key-not-a-secret',
      appId: Platform.isIOS
          ? '1:123456789012:ios:0a1b2c3d4e5f6a7b8c9d0e'
          : '1:123456789012:android:0a1b2c3d4e5f6a7b8c9d0e',
      messagingSenderId: '123456789012',
      projectId: 'demo-womp',
    );

/// L'app Firebase utilisée par tout le code. Ne jamais passer par `.instance` :
/// en mode émulateur ce n'est pas l'app par défaut.
late final FirebaseApp firebaseApp;

FirebaseAuth get auth => FirebaseAuth.instanceFor(app: firebaseApp);
FirebaseFirestore get firestore => FirebaseFirestore.instanceFor(app: firebaseApp);

Future<void> initFirebase() async {
  if (!useEmulator) {
    firebaseApp = await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    return;
  }
  // Les fichiers natifs configurent déjà l'app par défaut sur le vrai projet.
  // L'émulateur passe donc par une app à part, sous un nom à elle.
  firebaseApp = await Firebase.initializeApp(name: 'emulator', options: _demoOptions);
  await auth.useAuthEmulator('localhost', authPort);
  firestore.useFirestoreEmulator('localhost', firestorePort);
}
