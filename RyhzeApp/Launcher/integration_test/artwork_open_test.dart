import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/artwork_hero.dart';
import 'package:ryhze/ui/title_card.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native thumbnail moves directly into details and returns without a centre detour',
    (tester) async {
      final state = await fixtureState();
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
    final card = find.byType(RyhzeTitleCard).first;
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final art = find.descendant(of: card, matching: find.byType(ArtworkHero));
      final source = tester.getRect(art);
      final tag = tester.widget<ArtworkHero>(art).tag;
      await capture(key, 'thumbnail-source');
      await tester.tap(art);
      await tester.pump();
      final flight = find.byKey(ValueKey('artwork-flight-$tag'));
      final rects = <Rect>[];
      for (var frame = 1; frame <= 8; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        if (flight.evaluate().isNotEmpty) rects.add(tester.getRect(flight));
        await capture(key, 'thumbnail-opening-$frame');
      }
      await tester.pumpAndSettle();
      expect(rects.length, greaterThanOrEqualTo(3));
      final vector = rects.last.center - source.center;
      for (var i = 0; i < rects.length; i++) {
        final offset = rects[i].center - source.center;
        final perpendicular =
            (offset.dx * vector.dy - offset.dy * vector.dx).abs() /
            vector.distance;
        expect(
          perpendicular,
          lessThan(2),
          reason: 'Artwork must stay on its direct source-to-detail path',
        );
        expect(
          rects[i].width / rects[i].height,
          closeTo(source.width / source.height, .02),
        );
        if (i > 0) {
          expect(
            (rects[i].center - rects[i - 1].center).distance,
            greaterThan(.1),
            reason: 'No centre pause',
          );
        }
      }
      await capture(key, 'thumbnail-detail');
      await tester.tap(find.text('Back').first);
      for (var frame = 1; frame <= 8; frame++) {
        await tester.pump(const Duration(milliseconds: 80));
        await capture(key, 'thumbnail-closing-$frame');
      }
      await tester.pumpAndSettle();
    expect(find.byType(RyhzeTitleCard), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
