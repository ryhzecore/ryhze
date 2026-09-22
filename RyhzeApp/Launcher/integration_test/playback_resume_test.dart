import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/playback_bar.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'synced fractional progress resumes the correct episode in native playback',
    (tester) async {
      MediaKit.ensureInitialized();
      final state = await fixtureState(user: const Member('alice', 'viewer'));
      expect(
        state.api.origin.host,
        '127.0.0.1',
        reason: 'Run against the local-only media fixture.',
      );
      final film = RyhzeTitle(
        id: 'qa-film',
        title: 'Film library preview',
        kind: 'film',
        label: 'Ryhze Studio',
        status: 'QA',
        description: 'QA fixture',
        image: sample.image,
        seasons: const [
          Season('Season 1', [
            Episode('First episode', ['/media/Films/qa-first.mp4']),
            Episode('Second episode', ['/media/Films/qa-second.mp4']),
          ]),
        ],
      );
      state.titles = [film];
      await state.prefs.setBool('ambient-sound', false);
      await state.library.attach('alice');
      while (state.library.syncing) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await state.library.change('progress:qa-film', {
        'stream': '/media/Films/qa-second.mp4',
        'position': 20.5,
        'duration': 30,
        'watched': false,
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('browse-films')));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('card-open-qa-film'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue watching'));
      await tester.tap(find.text('Continue watching'));
      await tester.pump(const Duration(seconds: 2));
      final bar = find.byType(PlaybackBar);
      expect(bar, findsOneWidget);
      final player = tester.widget<PlaybackBar>(bar).player;
      if (player.state.position.inMilliseconds < 20500) {
        await player.stream.position
            .firstWhere((p) => p.inMilliseconds >= 20500)
            .timeout(const Duration(seconds: 20));
      }
      expect(player.state.playing, true);
      expect(
        player.state.playlist.medias.single.uri,
        contains('qa-second.mp4'),
      );
      await tester.ensureVisible(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      final videoRect = tester.getRect(find.byType(Video));
      final pauseRect = tester.getRect(find.byTooltip('Play').last);
      expect(
        videoRect.contains(pauseRect.center),
        isTrue,
        reason: 'Play/pause belongs on the video',
      );
      await capture(boundary, 'continued-second-episode');
      await tester.tap(find.text('Back').first);
      await tester.pumpAndSettle();
      expect(state.history['qa-film']['position'], greaterThanOrEqualTo(20));
      expect(state.history['qa-film']['stream'], '/media/Films/qa-second.mp4');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
