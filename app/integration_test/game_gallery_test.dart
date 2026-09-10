import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/ui/game_library.dart';
import 'package:ryhze/ui/design.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('official Steam artwork gallery and native trailer playback', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
    final prefs = await SharedPreferences.getInstance();
    final game = LocalGame(
      id: 'steam:570',
      name: 'Dota 2',
      source: 'Steam',
      root: r'D:\SteamLibrary\steamapps\common\dota 2 beta',
      storeId: '570',
    );
    final media = GameMediaStore(prefs);
    final library = GameLibrary(prefs, autoPoll: false);
    library.games = [game];
    final data = await media.load(game);
    expect(data.artwork, isNotEmpty);
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
        child: MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InstalledGamesPage(library: library, media: media),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    await capture(key, 'native-installed-games');
    await tester.ensureVisible(find.text('Dota 2'));
    await tester.tap(find.text('Dota 2'));
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Trailer 1'), findsOneWidget);
    await capture(key, 'native-game-gallery');
    await tester.tap(find.byTooltip('Close details'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    library.dispose();
    media.dispose();
  });
}
