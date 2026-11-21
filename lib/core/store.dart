import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'game.dart';

class DayData {
  int? me;
  final Map<String, int> friends = {};
  final Set<String> reacts = {};

  Map<String, dynamic> toJson() => {'me': me, 'friends': friends, 'reacts': reacts.toList()};

  static DayData fromJson(Map<String, dynamic> j) {
    final d = DayData()..me = j['me'] is int ? j['me'] as int : null;
    final f = j['friends'];
    if (f is Map) {
      f.forEach((k, v) {
        if (k is String && v is int) d.friends[k] = v;
      });
    }
    final r = j['reacts'];
    if (r is List) d.reacts.addAll(r.whereType<String>());
    return d;
  }
}

/// État local de l'app : prénom, scores par jour, réactions. Pas de serveur.
class Store extends ChangeNotifier {
  static const _key = 'womp.v1';

  SharedPreferences? _prefs;
  String name = '';
  final Map<String, DayData> days = {};

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map<String, dynamic>) return;
      if (j['name'] is String) name = j['name'] as String;
      final d = j['days'];
      if (d is Map<String, dynamic>) {
        d.forEach((k, v) {
          if (isDayKey(k) && v is Map<String, dynamic>) days[k] = DayData.fromJson(v);
        });
      }
    } catch (_) {
      // Stockage illisible : on repart de zéro plutôt que de planter.
    }
  }

  void save() {
    notifyListeners();
    _prefs?.setString(
      _key,
      jsonEncode({'name': name, 'days': days.map((k, v) => MapEntry(k, v.toJson()))}),
    );
  }

  DayData day(String key) => days.putIfAbsent(key, DayData.new);

  void mergeChallenge(Challenge c) {
    final d = day(c.day);
    c.scores.forEach((n, s) {
      if (n != name) d.friends[n] = s;
    });
    save();
  }

  /// Nombre de jours joués d'affilée, en remontant depuis aujourd'hui.
  int streak() {
    var d = DateTime.now();
    if (days[dayKey(d)]?.me == null) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (days[dayKey(d)]?.me != null) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }
}
