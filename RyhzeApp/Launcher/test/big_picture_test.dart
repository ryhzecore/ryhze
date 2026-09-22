import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/ui/big_picture.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/game_library.dart';
import 'package:ryhze/ui/game_shelf.dart';
import 'package:ryhze/ui/shell.dart';
import 'package:ryhze/ui/title_card.dart';
import 'package:ryhze/ui/artwork_hero.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

class TestLibrary extends GameLibrary {
  int launches = 0;
  TestLibrary(super.prefs) : super(autoPoll: false);
  @override
  Future<void> launchGame(LocalGame game) async {
    launches++;
  }
}

Future<void> controller(WidgetTester tester, String key) async {
  tester.binding.channelBuffers.push(
    'ryhze/desktop',
    const StandardMethodCodec().encodeMethodCall(MethodCall('controller', key)),
    (_) {},
  );
  await tester.pumpAndSettle();
}

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
  testWidgets(
    'horizontal controller selection opens shared animated game details and restores focus',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState();
      addTearDown(state.dispose);
      await state.prefs.setBool(GameLibrary.permissionKey, true);
      final library = TestLibrary(state.prefs);
      final media = GameMediaStore(state.prefs);
      addTearDown(library.dispose);
      addTearDown(media.dispose);
      library.games = List.generate(
        12,
        (i) => LocalGame(
          id: '$i',
          name: 'Game ${i.toString().padLeft(2, '0')}',
          source: 'Manual',
          root: '/games/$i',
        ),
      );
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        BigPicture.channel,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          BigPicture.channel,
          null,
        ),
      );
      final key = GlobalKey();
      bool exited = false;
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: ryhzeTheme(),
            home: BigPicture(
              onExit: () => exited = true,
              child: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.all(28),
                  child: GameShelf(
                    children: [
                      for (final game in library.games)
                        LocalGameCard(
                          key: ValueKey(game.id),
                          game: game,
                          library: library,
                          media: media,
                          state: state,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls.first.arguments, true);
      expect(find.byType(RyhzeTitleCard), findsNWidgets(12));
      for (var i = 0; i < 6; i++) {
        await controller(tester, 'right');
      }
      final seventh = find.byKey(const ValueKey('card-open-local-6'));
      expect(tester.getRect(seventh).center.dx, inInclusiveRange(100, 1180));
      await controller(tester, 'select');
      expect(find.byType(LocalGameDetail), findsOneWidget);
      expect(library.launches, 0);
      expect(find.byType(GameFrameTransition), findsOneWidget);
      await controller(tester, 'back');
      expect(find.byType(LocalGameDetail), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(
        tester.widget<LocalGameDetail>(find.byType(LocalGameDetail)).game.id,
        '5',
      );
      await tester.runAsync(() => capture(key, 'steamdeck-shared-game-menu'));
      await controller(tester, 'back');
      await controller(tester, 'back');
      expect(find.text('Leave Big Picture?'), findsOneWidget);
      await tester.tap(find.text('Keep playing'));
      await tester.pumpAndSettle();
      expect(exited, false);
      await controller(tester, 'back');
      await tester.tap(find.text('Exit Big Picture'));
      await tester.pumpAndSettle();
      expect(exited, true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(calls.last.arguments, false);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [800.0, 1280.0]) {
    testWidgets('regular app shell and horizontal games fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, width == 800 ? 600 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState();
      addTearDown(state.dispose);
      state.titles = [];
      state.error = 'Unable to load Ryhze. Please try again.';
      await state.prefs.setBool(GameLibrary.permissionKey, true);
      final library = TestLibrary(state.prefs);
      // RyhzeShell owns and disposes the supplied library.
      library.games = List.generate(
        8,
        (i) => LocalGame(
          id: '$i',
          name: 'Game ${i.toString().padLeft(2, '0')}',
          source: 'Manual',
          root: '/games/$i',
        ),
      );
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ryhzeTheme(),
            home: RyhzeShell(
              state: state,
              gameLibrary: library,
              initialBigPicture: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BigPicture), findsOneWidget);
      expect(find.byType(GameShelf), findsOneWidget);
      expect(find.byType(BrowseTabs), findsOneWidget);
      expect(find.textContaining('Unable to load Ryhze'), findsNothing);
      expect(find.textContaining('Showing the last available'), findsNothing);
      expect(find.byType(RyhzeTitleCard), findsNWidgets(8));
      await tester.runAsync(
        () => capture(key, 'steamdeck-shared-ui-${width.toInt()}'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
