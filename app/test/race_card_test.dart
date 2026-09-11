import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/race_installation.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/engine.dart';
import 'package:ryhze/ui/artwork_hero.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

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
  for (final width in [390.0, 1280.0]) {
    testWidgets('RACE opens from its card with delayed controls at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        raceChannel,
        (_) async => {
          'path': r'E:\RACE',
          'executable': r'E:\RACE\race_editor.exe',
          'version': '0.1.0',
          'build': 1,
        },
      );
      addTearDown(() => messenger.setMockMethodCallHandler(raceChannel, null));
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient(
          (_) async => http.Response('{"available":false}', 200),
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-engine')));
      await tester.pumpAndSettle();
      await tester.runAsync(() => capture(key, 'race-card-${width.toInt()}'));
      await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      final reveal = find.descendant(
        of: find.byType(RaceDetail),
        matching: find.byType(DetailControlsReveal),
      );
      for (final opacity in tester.widgetList<Opacity>(
        find.descendant(of: reveal, matching: find.byType(Opacity)),
      )) {
        expect(opacity.opacity, 0);
      }
      await tester.runAsync(
        () => capture(key, 'race-opening-${width.toInt()}'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Launch RACE'), findsOneWidget);
      await tester.runAsync(() => capture(key, 'race-detail-${width.toInt()}'));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(RaceDetail), findsNothing);
      state.user = null;
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browse-engine')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }
}
