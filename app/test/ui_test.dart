import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/pages.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
  });
  for (final size in [
    const Size(1280, 820),
    const Size(390, 844),
    const Size(320, 740),
    const Size(768, 1024),
  ]) {
    testWidgets('native home layout ${size.width.toInt()}px has no overflow', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
          'assets/brand/wordmark.png',
          'assets/brand/symbol.png',
          'assets/art/san-coronado.png',
          'assets/art/gta-vi.png',
        ]) {
          await precacheImage(AssetImage(path), key.currentContext!);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Explore the game'), findsOneWidget);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = (await tester.runAsync(
        () => boundary.toImage(pixelRatio: 1),
      ))!;
      final bytes = await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.png),
      );
      Directory('.private/qa').createSync(recursive: true);
      File(
        '.private/qa/home-${size.width.toInt()}.png',
      ).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
      await tester.tap(find.text('Films').first);
      await tester.pumpAndSettle();
      expect(find.text('Stories,\nmade to stay.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('search opens a title and Back restores the home', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 820);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await fixtureState();
    await tester.pumpWidget(RyhzeApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Search Ryhze'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'larcenous');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, sample.title));
    await tester.pumpAndSettle();
    expect(find.text('One state. Every way out.'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Explore the game'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('signed-in My List updates immediately', (tester) async {
    final state = await fixtureState(user: const Member('alice', 'viewer'));
    await tester.pumpWidget(RyhzeApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My List').first);
    await tester.pumpAndSettle();
    expect(state.saved, contains(sample.id));
    expect(find.text('In My List'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('empty sign-in validates locally and preserves form', (
    tester,
  ) async {
    final state = await fixtureState();
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: AuthPage(
              state: state,
              activation: false,
              onNavigate: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Sign in').last);
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter your user ID.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });
}
