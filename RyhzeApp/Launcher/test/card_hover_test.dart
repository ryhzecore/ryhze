import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/preview.dart';
import 'package:ryhze/ui/title_card.dart';
import 'support.dart';

void main() {
  testWidgets('status, categories and save button lift with the whole card', (
    tester,
  ) async {
    final state = await fixtureState();
    var opens = 0, saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ListenableBuilder(
                listenable: state,
                builder: (_, _) => RyhzeTitleCard(
                  title: sample,
                  state: state,
                  onOpen: () => opens++,
                  onSave: () => saves++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final status = find.text(sample.status);
    final categories = find.text('Open world · Driving');
    final artwork = find.byKey(ValueKey('card-open-${sample.id}'));
    final scale = find.byKey(ValueKey('card-scale-${sample.id}'));
    final statusY = tester.getTopLeft(status).dy;
    final categoryY = tester.getTopLeft(categories).dy;
    final artworkY = tester.getTopLeft(artwork).dy;
    final mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: 940,
    );
    await mouse.addPointer(location: const Offset(1, 1));
    await mouse.moveTo(tester.getCenter(status));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(status).dy, closeTo(statusY - 3, .01));
    expect(tester.getTopLeft(categories).dy, closeTo(categoryY - 3, .01));
    expect(tester.getTopLeft(artwork).dy, closeTo(artworkY - 3, .01));
    expect(tester.widget<AnimatedScale>(scale).scale, 1);
    expect(
      tester.widget<ArtworkPreview>(find.byType(ArtworkPreview)).active,
      false,
    );
    await mouse.moveTo(tester.getCenter(artwork));
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedScale>(scale).scale, 1.025);
    expect(tester.getTopLeft(status).dy, closeTo(statusY - 3, .01));
    final save = find.byType(TextButton);
    await mouse.moveTo(tester.getCenter(save));
    await tester.pumpAndSettle();
    await mouse.down(tester.getCenter(save));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(opens, 0);
    expect(tester.getTopLeft(status).dy, closeTo(statusY - 3, .01));
    await mouse.moveTo(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(status).dy, closeTo(statusY, .01));
    await state.preference('reduced-motion', true);
    await mouse.moveTo(tester.getCenter(status));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(status).dy, closeTo(statusY, .01));
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
    state.api.close();
    state.dispose();
  });
}
