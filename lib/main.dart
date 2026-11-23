import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config.dart';
import 'core/store.dart';
import 'data/firestore_repo.dart';
import 'data/pass.dart';
import 'data/revenuecat_pass_store.dart';
import 'firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = Store();
  await store.load();
  try {
    await initFirebase();
  } catch (_) {
    // L'app démarre quand même : l'écran d'erreur prend le relais, pas un écran blanc.
  }
  runApp(WompApp(store: store, repo: FirestoreRepo(), pass: PassController(store: _passStore())));
}

/// RevenueCat dès qu'une clé est fournie. Sur l'émulateur sans clé, un magasin factice.
PassStore? _passStore() {
  final key = Platform.isIOS ? revenueCatAppleKey : revenueCatGoogleKey;
  if (key.isNotEmpty) return RevenueCatPassStore(key);
  return useEmulator ? FakePassStore() : null;
}
