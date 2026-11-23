import 'package:flutter_test/flutter_test.dart';
import 'package:womp/core/game.dart';

void main() {
  test('same day gives the same round, another day a different one', () {
    final a = buildPlan('2026-11-21', 45000);
    final b = buildPlan('2026-11-21', 45000);
    final c = buildPlan('2026-11-22', 45000);
    expect(a.length, b.length);
    for (var i = 0; i < a.length; i++) {
      expect([a[i].t, a[i].life, a[i].x, a[i].y, a[i].kind], [b[i].t, b[i].life, b[i].x, b[i].y, b[i].kind]);
    }
    expect(a.map((s) => s.t).toList(), isNot(c.map((s) => s.t).toList()));
  });

  test('round stays inside its bounds', () {
    final plan = buildPlan('2026-11-21', 45000);
    expect(plan.length, greaterThan(50));
    for (final s in plan) {
      expect(s.t, inInclusiveRange(0, 45000));
      expect(s.life, greaterThan(300));
      expect(s.x, inInclusiveRange(0, 1));
      expect(s.y, inInclusiveRange(0, 1));
    }
    expect(maxScore(plan), greaterThan(40));
  });

  test('pinned round for 2026-11-21', () {
    final plan = buildPlan('2026-11-21', 45000);
    expect([plan.length, maxScore(plan), plan.first.t, plan.last.t], pinned);
  });

  test('names are cleaned', () {
    expect(cleanName('  Jean-Luc   Picard the Second '), 'Jean-Luc Pic');
    expect(cleanName('a:b|c'), 'abc');
  });
}

// Valeurs relevées une fois : si elles bougent, la partie du jour a changé pour tout le monde.
const pinned = [78, 71, 700, 44075];
