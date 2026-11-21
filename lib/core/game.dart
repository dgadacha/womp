import 'dart:convert';

import '../config.dart';

/// Générateur déterministe sur 32 bits : même graine, même partie sur tous les téléphones.
class Rng {
  Rng(int seed) : _a = seed & 0xFFFFFFFF;
  int _a;

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  double next() {
    _a = (_a + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _imul(_a ^ (_a >> 15), 1 | _a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & 0xFFFFFFFF) ^ t;
    return ((t ^ (t >> 14)) & 0xFFFFFFFF) / 4294967296;
  }
}

int hashText(String s) {
  var h = 2166136261;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return h;
}

enum Kind { good, gold, trap }

int pointsFor(Kind k) => switch (k) { Kind.good => 1, Kind.gold => 3, Kind.trap => -3 };

class Spawn {
  const Spawn(this.t, this.life, this.x, this.y, this.kind);
  final int t; // apparition, en ms depuis le début
  final int life; // durée de vie en ms
  final double x; // position 0..1
  final double y;
  final Kind kind;
}

/// Le plan de la partie ne dépend que du jour : tout le monde joue la même.
List<Spawn> buildPlan(String day, int durationMs) {
  final r = Rng(hashText('snap-$day'));
  final plan = <Spawn>[];
  final recent = <List<double>>[];
  var t = 700.0;
  while (t < durationMs - 500) {
    final p = t / durationMs;
    final roll = r.next();
    final kind = roll < 0.17 ? Kind.trap : (roll < 0.26 ? Kind.gold : Kind.good);
    final life = kind == Kind.gold ? 620 - 120 * p : 1150 - 380 * p;
    late double x, y;
    var tries = 0;
    var ok = false;
    while (!ok) {
      x = r.next();
      y = r.next();
      ok = true;
      for (final q in recent) {
        final dx = x - q[0], dy = y - q[1];
        if (dx * dx + dy * dy < 0.06) ok = false;
      }
      if (++tries >= 8) break;
    }
    recent.add([x, y]);
    if (recent.length > 2) recent.removeAt(0);
    plan.add(Spawn(t.round(), life.round(), x, y, kind));
    t += 640 - 300 * p + r.next() * 160;
  }
  return plan;
}

int maxScore(List<Spawn> plan) =>
    plan.fold(0, (s, c) => s + (c.kind == Kind.trap ? 0 : pointsFor(c.kind)));

// ---------- Jours ----------

/// Jour local, pas UTC : le jeu change à minuit chez le joueur.
String dayKey([DateTime? d]) {
  d ??= DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
bool isDayKey(String s) => _dayRe.hasMatch(s);

DateTime dateOf(String day) {
  final p = day.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

int dayNumber(String day) {
  final d = dateOf(day);
  return DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;
}

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String prettyDay(String day) {
  final d = dateOf(day);
  return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
}

String ordinal(int n) {
  final m100 = n % 100;
  if (m100 >= 11 && m100 <= 13) return '${n}th';
  return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
}

// ---------- Noms et codes de défi ----------

final _badChars = RegExp(r"[^\p{L}\p{N} '\-]", unicode: true);

String cleanName(String raw) {
  final s = raw.replaceAll(_badChars, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > 12 ? s.substring(0, 12).trim() : s;
}

class Challenge {
  const Challenge(this.day, this.scores);
  final String day;
  final Map<String, int> scores;
}

String encodeChallenge(String day, Map<String, int> scores) {
  final body = [day, ...scores.entries.map((e) => '${e.key}:${e.value}')].join('|');
  return '$codePrefix.${base64Url.encode(utf8.encode(body)).replaceAll('=', '')}';
}

final _codeRe = RegExp('$codePrefix\\.([A-Za-z0-9_-]{8,800})');

/// Lit un code collé seul ou au milieu d'un message. Le contenu vient d'ailleurs :
/// tout est borné et nettoyé. Retourne null si le code ne tient pas debout.
Challenge? decodeChallenge(String text) {
  if (text.length > 4000) return null;
  final m = _codeRe.firstMatch(text);
  if (m == null) return null;
  try {
    var b = m.group(1)!;
    while (b.length % 4 != 0) {
      b += '=';
    }
    final parts = utf8.decode(base64Url.decode(b)).split('|');
    if (parts.isEmpty || !isDayKey(parts.first)) return null;
    final scores = <String, int>{};
    for (final part in parts.skip(1).take(20)) {
      final i = part.lastIndexOf(':');
      if (i < 1) continue;
      final name = cleanName(part.substring(0, i));
      final pts = int.tryParse(part.substring(i + 1));
      if (name.isEmpty || pts == null || pts < -500 || pts > 999) continue;
      scores[name] = pts;
    }
    return Challenge(parts.first, scores);
  } catch (_) {
    return null;
  }
}

// ---------- Bande ----------

class Player {
  const Player(this.name, this.score, {this.isMe = false, this.isDemo = false});
  final String name;
  final int score;
  final bool isMe;
  final bool isDemo;
}

const _demoNames = ['Maya', 'Leo', 'Zoe', 'Sam'];

/// Joueurs fictifs, tant qu'aucun vrai score n'est arrivé par un code.
List<Player> demoCrew(String day, int max) {
  final r = Rng(hashText('demo-$day'));
  return [
    for (final n in _demoNames) Player(n, (max * (0.38 + r.next() * 0.42)).round(), isDemo: true),
  ];
}

List<Player> ranking({
  required String day,
  required int max,
  required Map<String, int> friends,
  String? myName,
  int? myScore,
}) {
  final list = friends.isEmpty
      ? demoCrew(day, max)
      : [for (final e in friends.entries) Player(e.key, e.value)];
  if (myScore != null) list.add(Player(myName ?? 'Me', myScore, isMe: true));
  list.sort((a, b) => b.score.compareTo(a.score));
  return list;
}

/// Liste fermée et relue : jamais de gage en texte libre.
const dares = [
  'Bring snacks for the whole crew.',
  'Speak only in rhymes for ten minutes.',
  'Wear mismatched socks on Monday.',
  'Give every crew member a sincere compliment.',
  'Sing the chorus the winner picks.',
  'Keep the profile pic the crew picks for 24 hours.',
  'Do the animal impression the winner picks, for ten seconds.',
  'Send a voice note as a weather presenter.',
];

String dareOfWeek(String day) => dares[(dayNumber(day) ~/ 7) % dares.length];
