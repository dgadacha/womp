import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:womp/core/game.dart';
import 'package:womp/screens/play.dart';

void main() {
  testWidgets('a touch on a target scores on pointer down, and the round ends', (tester) async {
    const plan = [
      Spawn(500, 1000, 0.5, 0.5, Kind.good),
      Spawn(1800, 1000, 0.2, 0.2, Kind.trap),
      Spawn(3200, 600, 0.8, 0.8, Kind.gold),
    ];
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: PlayScreen(plan: plan, durationMs: 4500, onDone: (s) => result = s),
    ));
    await tester.pump(); // premier tick

    Future<void> hit(IconData? icon) async {
      final target = icon == null
          ? find.byWidgetPredicate((w) => w is Listener && w.onPointerDown != null && w.child is Transform)
          : find.byIcon(icon);
      expect(target, findsOneWidget);
      final g = await tester.startGesture(tester.getCenter(target), kind: PointerDeviceKind.touch);
      await tester.pump();
      await g.up();
    }

    // Décompte de 2,1 s, puis première cible à 0,5 s.
    await tester.pump(const Duration(milliseconds: 2100 + 700));
    await hit(null);
    expect(find.text('1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300)); // t = 2000 : le piège est là
    await hit(Icons.close_rounded);
    expect(find.text('-2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300)); // t = 3300 : le jaune
    await hit(Icons.bolt_rounded);
    expect(find.text('1'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(result, 1);
  });
}
