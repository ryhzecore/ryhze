import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/core/race_installation.dart';

import '../test/website_parity_test.dart' show capture;
import '../test/support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'RDR2 sharp artwork, rounded dropdown, gallery and new RACE detection',
    (tester) async {
      MediaKit.ensureInitialized();
      final state = await fixtureState();
      final prefs = state.prefs;
      await prefs.setBool(GameLibrary.permissionKey, true);
      final game = LocalGame(
        id: 'steam:1174180',
        name: 'Red Dead Redemption 2',
        source: 'Steam',
        root: r'D:\SteamLibrary\steamapps\common\dota 2 beta',
        storeId: '1174180',
      );
      final media = GameMediaStore(prefs);
      final library = GameLibrary(prefs, autoPoll: false);
      library.games = [game];
      final data = await media.load(game);
      expect(data.artwork, contains('library_hero.jpg'));
      final race = await raceInstallation();
      expect(race?['executable'], endsWith('RACE.exe'));
      expect(data.screenshots, isNotEmpty);
      expect(data.trailers, isNotEmpty);
      final player = Player();
      try {
        await player.open(Media(data.trailers.first));
        await player.stream.position
            .firstWhere((time) => time > const Duration(seconds: 1))
            .timeout(const Duration(seconds: 40));
        expect(player.state.playing, isTrue);
      } finally {
        await player.dispose();
      }
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state, gameLibrary: library),
        ),
      );
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
      await Scrollable.ensureVisible(
        tester.element(find.byKey(const ValueKey('game-category-select'))),
        alignment: .2,
      );
      await tester.pumpAndSettle();
      await capture(key, 'rdr2-library');
      await tester.tap(find.byKey(const ValueKey('game-category-select')));
      await tester.pumpAndSettle();
      await capture(key, 'category-menu');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Red Dead Redemption 2'));
      await tester.tap(find.text('Red Dead Redemption 2'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 2));
      await tester.pump();
      await capture(key, 'rdr2-detail-artwork');
      expect(find.byKey(const ValueKey('game-frame-stroke')), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      expect(
        find.text('2 / ${1 + data.screenshots.length + data.trailers.length}'),
        findsOneWidget,
      );
      await capture(key, 'rdr2-gallery');
      await tester.tap(find.text('Back').first);
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());

      media.dispose();
      state.dispose();
    },
  );
}
