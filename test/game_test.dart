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

  test('challenge code round trip', () {
    final code = encodeChallenge('2026-11-21', {'Léa': 27, 'Tom': -3});
    final c = decodeChallenge('I scored 27. Paste this:\n$code\nthanks')!;
    expect(c.day, '2026-11-21');
    expect(c.scores, {'Léa': 27, 'Tom': -3});
  });

  test('hostile codes are rejected or cleaned', () {
    expect(decodeChallenge('hello'), isNull);
    expect(decodeChallenge('WOMP.!!!!'), isNull);
    expect(decodeChallenge('WOMP.${'A' * 900}'), isNull);
    expect(decodeChallenge('x' * 5000), isNull);
    final c = decodeChallenge(encodeChallenge('2026-11-21', {'<b>Al</b>': 5, 'Big': 99999}))!;
    expect(c.scores, {'bAlb': 5});
    final many = decodeChallenge(
      encodeChallenge('2026-11-21', {for (var i = 0; i < 40; i++) 'P$i': i}),
    )!;
    expect(many.scores.length, 20);
  });

  test('names and ordinals', () {
    expect(cleanName('  Jean-Luc   Picard the Second '), 'Jean-Luc Pic');
    expect(cleanName('a:b|c'), 'abc');
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd']);
    expect(prettyDay('2026-11-21'), 'Saturday, November 21');
  });

  test('demo crew leaves when a real score arrives', () {
    final demo = ranking(day: '2026-11-21', max: 70, friends: {}, myName: 'Me', myScore: 30);
    expect(demo.where((p) => p.isDemo).length, 4);
    final real = ranking(day: '2026-11-21', max: 70, friends: {'Tom': 12}, myName: 'Me', myScore: 30);
    expect(real.map((p) => p.name).toList(), ['Me', 'Tom']);
  });
}

// Valeurs relevées une fois : si elles bougent, la partie du jour a changé pour tout le monde.
const pinned = [78, 71, 700, 44075];
