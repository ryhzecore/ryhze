import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ryhze/main.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Ryhze drag and source expansion evidence', (
    tester,
  ) async {
    final state = await fixtureState();
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: RyhzeApp(state: state),
      ),
    );
    await tester.pumpAndSettle();
    final games = tester.getCenter(find.byKey(const ValueKey('browse-games')));
    final films = tester.getCenter(find.byKey(const ValueKey('browse-films')));
    final drag = await tester.startGesture(games);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 190));
    for (var i = 0; i <= 5; i++) {
      await drag.moveTo(Offset.lerp(games, films, i / 5)!);
      await tester.pump();
      await capture(key, 'tabs-$i');
    }
    await drag.up();
    await tester.pumpAndSettle();
    expect(find.text('Stories,\nmade to stay.'), findsOneWidget);
    for (final item in [
      ('Search Ryhze', 'search'),
      ('Account and settings', 'menu'),
    ]) {
      await tester.tap(find.byTooltip(item.$1));
      await tester.pump();
      for (var i = 0; i < 5; i++) {
        await capture(key, '${item.$2}-$i');
        await tester.pump(const Duration(milliseconds: 70));
      }
      await tester.pumpAndSettle();
      await capture(key, '${item.$2}-open');
      await tester.tapAt(const Offset(2, 300));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('expanding-surface')), findsNothing);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
}
