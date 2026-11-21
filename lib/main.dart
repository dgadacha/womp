import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/store.dart';
import 'data/firestore_repo.dart';
import 'firebase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final store = Store();
  await store.load();
  await initFirebase();
  runApp(WompApp(store: store, repo: FirestoreRepo()));
}
