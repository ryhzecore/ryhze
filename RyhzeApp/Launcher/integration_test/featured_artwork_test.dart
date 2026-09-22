import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ryhze/main.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native featured artwork pans while text stays still and pauses behind details',
    (tester) async {
      final state = await fixtureState(featuredMotion: true);
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      Matrix4 matrix() => tester
          .widget<Transform>(
            find.byKey(
              const ValueKey('featured-artwork-drift'),
              skipOffstage: false,
            ),
          )
          .transform
          .clone();
      final start = matrix();
      final text = tester.getRect(find.text('Larcenous Driftscape').first);
      await capture(key, 'featured-pan-start');
      await tester.pump(const Duration(seconds: 5));
      expect(matrix(), isNot(start));
      expect(tester.getRect(find.text('Larcenous Driftscape').first), text);
      await capture(key, 'featured-pan-moving');
      await tester.tap(find.text('Explore the game'));
      await tester.pumpAndSettle();
      final paused = matrix();
      await tester.pump(const Duration(seconds: 2));
      expect(matrix(), paused);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
