import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/game_library.dart';
import 'package:ryhze/ui/design.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native brand sound, intro, Cyberpunk artwork and favourites', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final audio = Player();
    await audio.setVolume(0);
    await audio.open(Media('asset:///assets/audio/brand-intro-v4.mp3'));
    await audio.stream.position
        .firstWhere((p) => p.inMilliseconds > 300)
        .timeout(const Duration(seconds: 10));
    expect(audio.state.duration.inMilliseconds, greaterThan(3000));
    await audio.dispose();
    final state = await fixtureState();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RyhzeApp(state: state, showLaunchIntro: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await capture(key, 'native-brand-intro');
    await tester.pump(const Duration(seconds: 3));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await tester.pump();
    await capture(key, 'native-brand-shine');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.text('Skip intro'), findsNothing);
    final game = LocalGame(
      id: 'steam:1091500',
      name: 'Cyberpunk 2077',
      source: 'Steam',
      root: r'C:\QA\Cyberpunk',
      storeId: '1091500',
    );
    final media = GameMediaStore(state.prefs);
    final data = await media.load(game);
    expect(data.artwork, endsWith('/1091500/library_hero_2x.jpg'));
    expect(data.screenshots, isNotEmpty);
    final library = GameLibrary(
      state.prefs,
      autoPoll: false,
      processReader: () async => [],
    );
    library.games = [game];
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 560,
                child: LocalGameCard(
                  game: game,
                  library: library,
                  media: media,
                  state: state,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 2));
    await tester.pump();
    await capture(key, 'cyberpunk-card-restored');
    await tester.tap(find.byKey(const ValueKey('card-open-local-steam:1091500')));
    await tester.pump();
    for (var frame = 0; frame < 8 && find.byKey(const ValueKey('expanding-game-frame')).evaluate().isEmpty; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final openingFrame = tester.getRect(
      find.byKey(const ValueKey('expanding-game-frame')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getRect(find.byKey(const ValueKey('expanding-game-frame'))).width,
      greaterThan(openingFrame.width),
    );
    await capture(key, 'cyberpunk-frame-immediate');
    await tester.pump(const Duration(milliseconds: 240));
    await capture(key, 'cyberpunk-opening-centre');
    await tester.pumpAndSettle();
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    await capture(key, 'cyberpunk-details');
    expect(find.byTooltip('Add to list'), findsOneWidget);
    await tester.tap(find.byTooltip('Add to list'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove from list'), findsOneWidget);
    expect(
      (state.prefs.getStringList('local-organisation:${state.scope}:game') ??
          []),
      contains('favorite:steam:1091500'),
    );
    await tester.tap(find.text('Back').first);
    await tester.pump(const Duration(milliseconds: 340));
    await capture(key, 'cyberpunk-closing-centre');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('card-open-local-steam:1091500')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(LocalGameDetail), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    media.dispose();
    library.dispose();
    state.dispose();
  });
}
