import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/ui/game_library.dart';
import 'package:ryhze/ui/design.dart';
import 'website_parity_test.dart' show capture;

void main() {
  for (final width in [480.0, 800.0, 1280.0]) {
    testWidgets('installed games and expanded gallery fit at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
      final prefs = await SharedPreferences.getInstance();
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
                  'screenshots': [],
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
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: InstalledGamesPage(library: library, media: media),
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
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close details'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'no-such-title');
      await tester.pumpAndSettle();
      expect(find.text('No games match your search.'), findsOneWidget);
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
