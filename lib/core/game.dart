
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

// ---------- Noms ----------

final _badChars = RegExp(r"[^\p{L}\p{N} '\-]", unicode: true);

String cleanName(String raw) {
  final s = raw.replaceAll(_badChars, '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.length > 12 ? s.substring(0, 12).trim() : s;
}

// ---------- Gages ----------
// Les textes des gages sont dans lib/l10n, une liste par langue, toutes alignées.

/// Nombre de gages dans chaque liste, quelle que soit la langue.
const dareCount = 8;

const packClassic = 'classic';
const packParty = 'party';
const darePacks = [packClassic, packParty];

