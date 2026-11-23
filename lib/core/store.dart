import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Ce que le téléphone garde entre deux lancements : le prénom et la langue choisie.
class Store {
  static const _key = 'womp.v1';

  SharedPreferences? _prefs;
  String name = '';

  /// Langue choisie dans l'app : 'en', 'fr', 'es', ou '' pour suivre le téléphone.
  String locale = '';

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return;
      if (j['name'] is String) name = j['name'] as String;
      if (j['locale'] is String) locale = j['locale'] as String;
    } catch (_) {
      // Stockage illisible : on repart de zéro plutôt que de planter.
    }
  }

  void save() => _prefs?.setString(_key, jsonEncode({'name': name, 'locale': locale}));
}
