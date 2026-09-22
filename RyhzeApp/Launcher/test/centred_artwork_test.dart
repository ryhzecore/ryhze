import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/artwork_hero.dart';

void main() {
  testWidgets('details frame opens continuously on the artwork timeline', (
    tester,
  ) async {
    const source = Rect.fromLTWH(20, 100, 300, 200);
    final animation = AnimationController(vsync: tester);
    addTearDown(animation.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: GameFrameTransition(
          animation: animation,
          source: source,
          child: const SizedBox.expand(),
        ),
      ),
    );
    Rect frame() =>
        tester.getRect(find.byKey(const ValueKey('expanding-game-frame')));
    expect(frame(), source);
    animation.value = .1;
    await tester.pump();
    expect(frame().width, greaterThan(source.width));
    animation.value = .25;
    await tester.pump();
    expect(frame().width, greaterThan(source.width));
    expect(frame().height, greaterThan(source.height));
    animation.value = .45;
    await tester.pump();
    final beforeCentre = frame();
    animation.value = .55;
    await tester.pump();
    expect(frame().width, greaterThan(beforeCentre.width));
    animation.value = .45;
    await tester.pump();
    expect(frame(), beforeCentre);
    animation.value = 0;
    await tester.pump();
    expect(frame(), source);
  });

  test(
    'artwork follows a direct path without a centre pause and reverses exactly',
    () {
      const card = Rect.fromLTWH(20, 100, 300, 200),
          detail = Rect.fromLTWH(100, 180, 900, 600);
      final opening = DirectArtworkRectTween(begin: card, end: detail);
      final closing = DirectArtworkRectTween(begin: detail, end: card);
      expect(opening.lerp(0), card);
      expect(opening.lerp(1), detail);
      for (final t in [.45, .5, .55]) {
        expect(opening.lerp(t), Rect.lerp(card, detail, t * t * (3 - 2 * t)));
        expect(
          opening.lerp(t + .01)!.width,
          greaterThan(opening.lerp(t)!.width),
        );
      }
      for (final t in [0.0, .15, .4, .5, .7, .9, 1.0]) {
        final a = opening.lerp(t)!, b = closing.lerp(1 - t)!;
        expect(a.left, closeTo(b.left, .0001));
        expect(a.top, closeTo(b.top, .0001));
        expect(a.width, closeTo(b.width, .0001));
        expect(a.width / a.height, closeTo(1.5, .0001));
      }
    },
  );
}
