import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/artwork_hero.dart';
import 'package:ryhze/ui/design.dart';

void main() {
  for (final width in [1280.0, 1400.0]) {
    testWidgets('Game frame follows artwork timing and reverses ($width)', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 700),
      );
      addTearDown(controller.dispose);
      const source = Rect.fromLTWH(70, 300, 380, 250);
      final field = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: GameFrameTransition(
            animation: controller,
            source: source,

            child: Material(
              child: Center(child: TextField(key: field)),
            ),
          ),
        ),
      );
      final originalState = field.currentState;
      final originalFrame = tester.renderObject(
        find.byKey(const ValueKey('expanding-game-frame')),
      );
      final originalDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('expanding-game-frame')),
                  )
                  .decoration
              as ShapeDecoration;
      Rect frame() =>
          tester.getRect(find.byKey(const ValueKey('expanding-game-frame')));
      expect(frame(), source);
      controller.value = .5;
      await tester.pump();
      final target = Rect.fromLTRB(
        (width - 1080) / 2,
        24,
        (width + 1080) / 2,
        876,
      );
      expect(frame(), Rect.lerp(source, target, ryhzeEase.transform(.5)));
      controller.value = 1;
      await tester.pump();
      expect(frame(), target);
      expect(field.currentState, same(originalState));
      expect(
        tester.renderObject(find.byKey(const ValueKey('expanding-game-frame'))),
        same(originalFrame),
      );
      final settledDecoration =
          tester
                  .widget<DecoratedBox>(
                    find.byKey(const ValueKey('expanding-game-frame')),
                  )
                  .decoration
              as ShapeDecoration;
      expect(settledDecoration.color, originalDecoration.color);
      expect(
        (settledDecoration.shape as RoundedSuperellipseBorder).side,
        (originalDecoration.shape as RoundedSuperellipseBorder).side,
      );
      expect(
        tester
            .widget<ClipRSuperellipse>(find.byType(ClipRSuperellipse).first)
            .clipper,
        isNotNull,
      );
      controller.value = .5;
      await tester.pump();
      expect(frame(), Rect.lerp(source, target, ryhzeEase.transform(.5)));
      controller.value = 0;
      await tester.pump();
      expect(frame(), source);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Reduced motion shows final frame immediately', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: GameFrameTransition(
          animation: AlwaysStoppedAnimation(0),
          source: Rect.fromLTWH(0, 0, 100, 100),
          reduced: true,
          child: SizedBox.expand(),
        ),
      ),
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('expanding-game-frame'))),
      const Rect.fromLTRB(24, 24, 776, 576),
    );
  });
}
