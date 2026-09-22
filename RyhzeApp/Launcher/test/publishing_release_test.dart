import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/admin_games.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

void main() {
  setUpAll(() async {
    if (const String.fromEnvironment('RYHZE_SCREENSHOTS').isEmpty) return;
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  for (final width in [390.0, 1280.0]) {
    testWidgets('release form requires a saved title and resets at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <Uri>[];
      final captureKey = GlobalKey();
      final doc = {
        'id': 'qa-game',
        'kind': 'game',
        'title': 'QA game',
        'draftRevision': 1,
        'categories': [],
        'facts': [],
        'screenshots': [],
        'releases': [],
      };
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((r) async {
          calls.add(r.url);
          Object body = [];
          if (r.url.path.endsWith('/games')) {
            body = {
              'games': [doc],
              'drafts': [],
            };
          }
          if (r.url.path.endsWith('/games/qa-game')) {
            body = {'draft': doc, 'published': null};
          }
          if (r.url.path.endsWith('/uploads')) {
            body = [
              {
                'id': 'asset-a',
                'kind': 'package',
                'state': 'verified',
                'filename': 'game.zip',
              },
            ];
          }
          return http.Response(jsonEncode(body), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: RepaintBoundary(
            key: captureKey,
            child: GamePublishingPage(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Game releases'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a catalogue game'), findsOneWidget);
      await tester.runAsync(
        () => capture(captureKey, 'publishing-empty-${width.toInt()}'),
      );
      expect(find.text('Upload game package'), findsNothing);
      expect(calls.any((u) => u.path.endsWith('/releases')), isFalse);
      final catalogue = find.byType(RyhzeDropdown<String>).at(1);
      await tester.tap(catalogue);
      await tester.pumpAndSettle();
      await tester.tap(find.text('QA game').last);
      await tester.pumpAndSettle();
      expect(find.text('Upload game package'), findsOneWidget);
      await tester.runAsync(
        () => capture(captureKey, 'publishing-release-${width.toInt()}'),
      );
      final upload = find.widgetWithText(OutlinedButton, 'Upload game package');
      final package = find.ancestor(
        of: find.text('Verified package'),
        matching: find.byType(RyhzeDropdown<String>),
      );
      expect(
        tester.getTopLeft(package).dy - tester.getBottomLeft(upload).dy,
        greaterThanOrEqualTo(18),
      );
      final register = find.widgetWithText(TextButton, 'Register version');
      await tester.ensureVisible(register);
      expect(tester.widget<TextButton>(register).onPressed, isNull);
      await tester.ensureVisible(package);
      await tester.tap(package);
      await tester.pumpAndSettle();
      await tester.tap(find.text('game.zip').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('release-version-qa-game')),
        '1.0.0',
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(register);
      expect(tester.widget<TextButton>(register).onPressed, isNotNull);
      final newGame = width <= 480
          ? find.byTooltip('New game')
          : find.text('New game');
      await tester.tap(newGame);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Game releases'));
      await tester.tap(find.text('Game releases'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Choose a catalogue game'), findsOneWidget);
      expect(find.text('game.zip'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }

  testWidgets(
    'missing catalogue title has recovery guidance without release requests',
    (tester) async {
      final calls = <Uri>[];
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((r) async {
          calls.add(r.url);
          return http.Response(
            jsonEncode(
              r.url.path.endsWith('/games')
                  ? {'games': [], 'drafts': []}
                  : {'draft': null, 'published': null},
            ),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: GamePublishingPage(state: state, gameId: 'removed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Choose another title or create a new one'),
        findsOneWidget,
      );
      expect(find.text('Exception: Title not found.'), findsNothing);
      expect(calls.any((u) => u.path.endsWith('/releases')), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
