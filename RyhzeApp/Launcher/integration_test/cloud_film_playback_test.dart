import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/playback_bar.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('existing Cloudflare film streams and resumes in the native app', (tester) async {
    MediaKit.ensureInitialized();
    final state = await fixtureState(user: const Member('alice','viewer'));
    expect(state.api.origin.host, '127.0.0.1', reason: 'Run against the local-only media fixture.');
    final film=RyhzeTitle(id:'internal-fantastic-four-first-steps',title:'Fantastic Four First Steps',kind:'film',label:'Ryhze Studio',status:'QA',description:'QA fixture',image:sample.image,streams: const ['/media/Films/Fanstastic%20Four%20First%20Steps/Streams/Stream1-web.mp4']);
    state.titles=[film];
    await state.prefs.setBool('ambient-sound',false);
    await state.library.attach('alice');
    while(state.library.syncing) { await Future<void>.delayed(const Duration(milliseconds:20)); }
    await state.library.change('progress:internal-fantastic-four-first-steps', {'stream':'/media/Films/Fanstastic%20Four%20First%20Steps/Streams/Stream1-web.mp4','position':20.5,'duration':6882.176,'watched':false});
    final boundary=GlobalKey();
    await tester.pumpWidget(RepaintBoundary(key:boundary,child:RyhzeApp(state:state)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('browse-films'))); await tester.pumpAndSettle();
    final card=find.byKey(const ValueKey('card-open-internal-fantastic-four-first-steps'));
    await tester.ensureVisible(card); await tester.tap(card); await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continue watching'));
    await tester.tap(find.text('Continue watching'));
    await tester.pump(const Duration(seconds:2));
    final bar=find.byType(PlaybackBar);
    expect(bar,findsOneWidget);
    final player=tester.widget<PlaybackBar>(bar).player;
    if(player.state.position.inMilliseconds<20500) {
      await player.stream.position.firstWhere((p)=>p.inMilliseconds>=20500).timeout(const Duration(seconds:20));
    }
    expect(player.state.playing,true);
    expect(player.state.playlist.medias.single.uri,contains('Stream1-web.mp4'));
    await tester.ensureVisible(find.byTooltip('Pause'));await tester.tap(find.byTooltip('Pause'));await tester.pump();
    await capture(boundary,'fantastic-four-live-playback');
    await tester.tap(find.text('Back').first); await tester.pumpAndSettle();
    expect(state.history['internal-fantastic-four-first-steps']['position'],greaterThanOrEqualTo(20));
    expect(state.history['internal-fantastic-four-first-steps']['stream'],'/media/Films/Fanstastic%20Four%20First%20Steps/Streams/Stream1-web.mp4');
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());state.dispose();
  });
}
