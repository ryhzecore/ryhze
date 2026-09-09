import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/home.dart';
import 'package:ryhze/ui/title_card.dart';
import 'package:ryhze/ui/details.dart';
import 'support.dart';

Future<void> capture(GlobalKey key, String name) async {
  const output = String.fromEnvironment('RYHZE_SCREENSHOTS');
  if (output.isEmpty) return;
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await Directory(output).create(recursive: true);
  await File('$output/$name.png').writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('bundled game artwork decodes with the native image codec', (
    tester,
  ) async {
    for (final entry in [('valorant.png', 1500), ('gta-vi.png', 3840)]) {
      final data = await rootBundle.load('assets/art/${entry.$1}');
      await tester.runAsync(() async {
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, entry.$2);
        frame.image.dispose();
        codec.dispose();
      });
    }
  });
  for (final width in [320.0, 390.0, 768.0, 1280.0]) {
    testWidgets('brand introduction works at $width pixels', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      String? destination;
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: ColoredBox(
                color: canvas,
                child: SingleChildScrollView(
                  child: BrandHome(navigate: (page) => destination = page),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(key, 'brand-home-${width.toInt()}');
      await tester.ensureVisible(find.text('Explore Ryhze'));
      await tester.tap(find.text('Explore Ryhze'));
      expect(destination, 'games');
      await tester.ensureVisible(find.text('Explore series'));
      await tester.tap(find.text('Explore series'));
      expect(destination, 'films');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final kind in ['game', 'film']) {
    testWidgets(
      '$kind artwork stays visible during expansion and interrupted return',
      (tester) async {
        final state = await fixtureState();
        final title = RyhzeTitle(
          id: 'parity-$kind',
          title: 'Ryhze artwork',
          kind: kind,
          label: 'Ryhze',
          status: 'In development',
          description: 'A world beyond the ordinary.',
          image: sample.image,
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: ryhzeTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: RepaintBoundary(
                  key: key,
                  child: Center(
                    child: SizedBox(
                      width: 300,
                      child: RyhzeTitleCard(
                        title: title,
                        state: state,
                        onSave: () {},
                        onOpen: () {
                          Navigator.push(
                            context,
                            PageRouteBuilder<void>(
                              opaque: false,
                              transitionDuration: const Duration(
                                milliseconds: 2000,
                              ),
                              reverseTransitionDuration: const Duration(
                                milliseconds: 2000,
                              ),
                              pageBuilder: (_, animation, secondary) =>
                                  DetailPage(
                                    title: title,
                                    state: state,
                                    heroTag: 'card-${title.id}',
                                    onSignIn: () {},
                                  ),
                              transitionsBuilder:
                                  (_, animation, secondary, child) =>
                                      FadeTransition(
                                        opacity: animation,
                                        child: child,
                                      ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(ValueKey('card-open-${title.id}')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 150));
        final flight = find.byKey(ValueKey('artwork-flight-card-${title.id}'));
        expect(flight, findsOneWidget);
        for (final fade in tester.widgetList<FadeTransition>(
          find.ancestor(of: flight, matching: find.byType(FadeTransition)),
        )) {
          expect(
            fade.opacity.value,
            1,
            reason: 'Flying artwork stays fully opaque.',
          );
        }
        expect(
          find.descendant(of: flight, matching: find.byType(ColoredBox)),
          findsOneWidget,
        );
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Back'), findsNothing);
        expect(find.byKey(ValueKey('card-open-${title.id}')), findsOneWidget);
        await tester.tap(find.byKey(ValueKey('card-open-${title.id}')));
        await tester.pumpAndSettle();
        expect(find.byType(ClipRSuperellipse), findsWidgets);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        state.api.close();
        state.dispose();
      },
    );
  }
  test('ambient audio defaults on and preserves an explicit mute', () async {
    final state = await fixtureState();
    expect(state.sound, true);
    await state.preference('ambient-sound', false);
    expect(state.sound, false);
    state.api.close();
    state.dispose();
  });
  testWidgets(
    'library and translucent detail sheet adapt between desktop and phone',
    (tester) async {
      final state = await fixtureState();
      final key = GlobalKey();
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      await capture(key, 'library-desktop');
      await tester.tap(find.text('Explore the game'));
      await tester.pumpAndSettle();
      await capture(key, 'detail-desktop');
      final artwork = find.descendant(
        of: find.byType(DetailPage),
        matching: find.byType(TitleArt),
      );
      expect(tester.getSize(artwork).width, greaterThan(1000));
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await capture(key, 'detail-phone');
      expect(tester.getSize(artwork).width, greaterThan(330));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsNothing);
      await capture(key, 'library-phone');
      await tester.pumpWidget(const SizedBox());
      state.api.close();
      state.dispose();
    },
  );
}
