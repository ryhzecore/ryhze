import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/ui/game_library.dart';
import 'package:ryhze/ui/design.dart';
import 'website_parity_test.dart' show capture;
import 'support.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/title_card.dart';

void main() {
  testWidgets('installed games share the catalogue and filter by category', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final state = await fixtureState();
    addTearDown(state.dispose);
    await state.prefs.setBool(GameLibrary.permissionKey, true);
    await state.prefs.setString(
      'game-media:manual:one:',
      jsonEncode({
        'time': DateTime.now().millisecondsSinceEpoch,
        'media': const GameMedia().toJson(),
      }),
    );
    final library = GameLibrary(state.prefs, autoPoll: false);
    library.games = [
      LocalGame(
        id: 'manual:one',
        name: 'My installed game',
        source: 'Manual',
        root: r'D:\Games\One',
      ),
    ];
    await tester.pumpWidget(RyhzeApp(state: state, gameLibrary: library));
    await tester.pumpAndSettle();
    expect(find.text('Discover'), findsNothing);
    expect(find.text('Installed games.'), findsNothing);
    expect(find.byType(RyhzeTitleCard), findsNWidgets(3));
    final filter = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(filter);
    await tester.tap(filter);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Installed games').last);
    await tester.pumpAndSettle();
    expect(find.byType(RyhzeTitleCard), findsOneWidget);
    expect(find.text('My installed game'), findsOneWidget);
    await tester.ensureVisible(find.text('Not played since adding to Ryhze'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Not played since adding to Ryhze')));
    await tester.pumpAndSettle();
    final lift = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey('card-lift-local-manual:one')),
    );
    expect(lift.transform!.getTranslation().y, -3);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  for (final width in [480.0, 800.0, 1280.0]) {
    testWidgets('installed games and expanded gallery fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState();
      addTearDown(state.dispose);
      final prefs = state.prefs;
      await prefs.setBool(GameLibrary.permissionKey, true);
      final library = GameLibrary(prefs, autoPoll: false);
      addTearDown(library.dispose);
      library.games = [
        LocalGame(
          id: 'steam:570',
          name: 'Dota 2',
          source: 'Steam',
          root: r'D:\SteamLibrary\steamapps\common\dota 2 beta',
          storeId: '570',
        ),
        LocalGame(
          id: 'epic:1',
          name: 'A game with a long name',
          source: 'Epic Games',
          root: r'E:\Epic Games\A Game',
          lastPlayed: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];
      final media = GameMediaStore(
        prefs,
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              '570': {
                'success': true,
                'data': {
                  'short_description': 'Official game details.',
                  'screenshots': [
                    {'path_full': 'https://cdn.steamstatic.com/shot1.jpg'},
                    {'path_full': 'https://cdn.steamstatic.com/shot2.jpg'},
                  ],
                  'movies': [],
                },
              },
            }),
            200,
          ),
        ),
      );
      addTearDown(media.dispose);
      final key = GlobalKey();
      bool detailsOpen = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: 460,
                    child: LocalGameCard(
                      game: library.games.first,
                      state: state,
                      library: library,
                      media: media,
                      onDetailsChanged: (open) => detailsOpen = open,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => capture(key, 'installed-games-${width.toInt()}'),
      );
      await tester.ensureVisible(find.text('Dota 2'));
      await tester.tap(find.text('Dota 2'));
      await tester.pumpAndSettle();
      expect(find.text('Official game details.'), findsOneWidget);
      expect(detailsOpen, true);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('Next image or trailer'));
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Next image or trailer'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      expect(detailsOpen, false);
    });
  }
  testWidgets(
    'permission prompt decline is remembered and reads no processes',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final library = GameLibrary(
        await SharedPreferences.getInstance(),
        autoPoll: false,
        processReader: () async {
          fail('No process inspection before consent');
        },
      );
      addTearDown(library.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => gamePermission(context, library),
                child: const Text('Set up'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Set up'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(library.permission, false);
      await library.refresh();
    },
  );
}
