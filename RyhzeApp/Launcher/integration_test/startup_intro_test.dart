import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/main.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native loading hold, black reflection and synchronized reveal', (
    tester,
  ) async {
    MediaKit.ensureInitialized();
    final state = await fixtureState();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RyhzeApp(state: state, showLaunchIntro: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('brand-intro-logo')))
          .transform
          .entry(0, 0),
      1,
    );
    await capture(key, 'startup-loading');
    await tester.pump(const Duration(milliseconds: 2800));
    await capture(key, 'startup-reflection');
    await tester.pump(const Duration(milliseconds: 1200));
    await capture(key, 'startup-zoom');
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 10),
    );
    expect(find.text('Skip intro'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
