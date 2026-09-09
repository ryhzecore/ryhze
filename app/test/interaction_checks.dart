import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/preview.dart';
import 'support.dart';

void interactionChecks({bool native = false}) {
  testWidgets(
    'navigation selection stays aligned at both ends and after rapid switching',
    (tester) async {
      if (!native) {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final state = await fixtureState();
      await tester.pumpWidget(RyhzeApp(state: state));
      await tester.pumpAndSettle();
      final games = find.byKey(const ValueKey('browse-games'));
      final films = find.byKey(const ValueKey('browse-films'));
      final selection = find.byKey(const ValueKey('browse-selection'));
      void aligned(Finder target) {
        expect(tester.getRect(selection), tester.getRect(target));
        final text = find.descendant(of: target, matching: find.byType(Text));
        expect(
          (tester.getCenter(text) - tester.getCenter(target)).distance,
          lessThan(.1),
        );
      }

      aligned(games);
      await tester.tap(films, pointer: 901);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(games, pointer: 902);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(films, pointer: 903);
      await tester.pumpAndSettle();
      aligned(films);
      expect(find.text('Stories,\nmade to stay.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'mouse hover changes button appearance, press activates it, and exit restores it',
    (tester) async {
      var taps = 0;
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: key,
                child: Pill(
                  'Hover target',
                  icon: Icons.arrow_forward,
                  onPressed: () => taps++,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final target = find.byType(TextButton);
      final initial = tester.getRect(target);
      Future<List<int>> pixels() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final picture = (await tester.runAsync(() => boundary.toImage()))!;
        final data = (await tester.runAsync(
          () => picture.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        final bytes = data.buffer.asUint8List().toList();
        picture.dispose();
        return bytes;
      }

      final before = await pixels();
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 910,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(target));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(target),
        initial.size,
      ); // Hover must not reflow its neighbours.
      expect(find.byType(AnimatedScale), findsOneWidget);
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        1.055,
      );
      expect(
        await pixels(),
        isNot(equals(before)),
      ); // The hover is actually painted.
      final button = tester.widget<TextButton>(target);
      expect(button.statesController!.value, contains(WidgetState.hovered));
      expect(
        button.style!.backgroundColor!.resolve(button.statesController!.value),
        const Color(0x16ffffff),
      );
      await mouse.down(tester.getCenter(target));
      await tester.pumpAndSettle();
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        .975,
      );
      await mouse.up();
      await mouse.moveTo(const Offset(1, 1));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await mouse.removePointer();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'artwork responds to mouse and keyboard; panels stop background previews',
    (tester) async {
      if (!native) {
        tester.view.physicalSize = const Size(1280, 820);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final state = await fixtureState();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.runAsync(() async {
        for (final path in [
          'assets/art/san-coronado.png',
          'assets/art/gta-vi.png',
          'assets/brand/wordmark.png',
          'assets/brand/symbol.png',
        ]) {
          await precacheImage(AssetImage(path), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      final card = find.byKey(ValueKey('card-open-${sample.id}'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 920,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(card));
      await tester.pumpAndSettle();
      final scale = find.byKey(ValueKey('card-scale-${sample.id}'));
      expect(tester.widget<AnimatedScale>(scale).scale, 1.025);
      expect(
        tester.widget<ArtworkPreview>(find.byType(ArtworkPreview).first).active,
        true,
      );
      if (!native) {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final picture = (await tester.runAsync(() => boundary.toImage()))!;
        final data = (await tester.runAsync(
          () => picture.toByteData(format: ui.ImageByteFormat.png),
        ))!;
        Directory('.private/qa').createSync(recursive: true);
        File(
          '.private/qa/catalog-hover.png',
        ).writeAsBytesSync(data.buffer.asUint8List());
        picture.dispose();
      }
      await mouse.down(tester.getCenter(card));
      await mouse.up();
      await tester.pumpAndSettle();
      expect(find.text('One state. Every way out.'), findsOneWidget);
      for (final preview in tester.widgetList<ArtworkPreview>(
        find.byType(ArtworkPreview, skipOffstage: false),
      )) {
        expect(preview.active, false);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await mouse.moveTo(const Offset(1, 1));
      await mouse.removePointer();
      await tester.pumpAndSettle();
      // Direct focus is a real keyboard focus event, independent of pointer position.
      final ink = tester.widget<InkWell>(card);
      ink.focusNode!.requestFocus();
      await tester.pumpAndSettle();
      expect(ink.focusNode!.hasFocus, true);
      expect(tester.widget<AnimatedScale>(scale).scale, 1.025);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('One state. Every way out.'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await state.preference('reduced-motion', true);
      await tester.pumpAndSettle();
      expect(tester.widget<AnimatedScale>(scale).scale, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
