import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/artwork_hero.dart';

void main() {
  testWidgets(
    'Controls follow frame progress without opening delay or closing flash',
    (tester) async {
      var progress = 0.0;
      var reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return GameFrameMotion(
                moving: progress != 1,
                progress: progress,
                reduced: reduced,
                child: const DetailControlsReveal(child: Text('Launch')),
              );
            },
          ),
        ),
      );
      final opacity = find.descendant(
        of: find.byType(DetailControlsReveal),
        matching: find.byType(Opacity),
      );
      double alpha() => tester.widget<Opacity>(opacity).opacity;
      expect(alpha(), 0);
      update(() => progress = .85);
      await tester.pump();
      final openingAlpha = alpha();
      expect(openingAlpha, inExclusiveRange(0, 1));
      update(() => progress = 1);
      await tester.pump();
      expect(alpha(), 1); // No extra fade after the panel settles.
      update(() => progress = .95);
      await tester.pump();
      expect(alpha(), greaterThan(.98)); // Closing does not blank the header.
      update(() => progress = .85);
      await tester.pump();
      expect(alpha(), openingAlpha); // Interrupted transitions reverse exactly.
      final pointer = find.descendant(
        of: find.byType(DetailControlsReveal),
        matching: find.byType(IgnorePointer),
      );
      expect(tester.widget<IgnorePointer>(pointer).ignoring, true);
      update(() => progress = 0);
      await tester.pump();
      expect(alpha(), 0);
      update(() => reduced = true);
      await tester.pump();
      expect(alpha(), 1);
      expect(tester.widget<IgnorePointer>(pointer).ignoring, false);
    },
  );
  for (final width in [1280.0, 1400.0]) {
    testWidgets('Game frame expands alongside artwork and reverses ($width)', (
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
      expect(frame(), Rect.lerp(source, target, .5));
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
      expect(frame(), Rect.lerp(source, target, .5));
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
