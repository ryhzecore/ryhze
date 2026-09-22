import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';

void main() {
  testWidgets(
    'held tabs track, commit once, cancel and reject a second pointer',
    (tester) async {
      var page = 'games', commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, update) => BrowseTabs(
                  page: page,
                  onChanged: (value) {
                    commits++;
                    update(() => page = value);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final games = find.byKey(const ValueKey('browse-games'));
      final films = find.byKey(const ValueKey('browse-films'));
      final selection = find.byKey(const ValueKey('browse-selection'));
      final left = tester.getCenter(games), right = tester.getCenter(films);
      final gesture = await tester.startGesture(left, pointer: 21);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.getRect(selection).width,
        greaterThan(tester.getSize(games).width),
      );
      await gesture.moveTo(Offset.lerp(left, right, .6)!);
      await tester.pump();
      expect(
        tester.getCenter(selection).dx,
        closeTo(Offset.lerp(left, right, .6)!.dx, .1),
      );
      expect(commits, 0);
      final second = await tester.startGesture(right, pointer: 22);
      await second.up();
      await tester.pump();
      expect(commits, 0);
      await gesture.moveTo(right);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(page, 'films');
      expect(commits, 1);
      expect(tester.getRect(selection), tester.getRect(films));
      final cancelled = await tester.startGesture(right);
      await cancelled.moveTo(left);
      await tester.pump();
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(commits, 1);
      expect(tester.getRect(selection), tester.getRect(films));
      final outside = await tester.startGesture(right);
      await outside.moveTo(left + const Offset(0, 100));
      await outside.up();
      await tester.pumpAndSettle();
      expect(commits, 1);
      await tester.tap(games);
      await tester.pumpAndSettle();
      expect(commits, 2);
      expect(page, 'games');
      final filmButton = tester.widget<TextButton>(films);
      filmButton.focusNode?.requestFocus();
      // Tab traversal and Enter stay on the native TextButton action path.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(commits, 3);
    },
  );

  testWidgets('reduced-motion tab drag has no growth and commits normally', (
    tester,
  ) async {
    var page = 'games';
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: Center(
              child: StatefulBuilder(
                builder: (context, update) => BrowseTabs(
                  page: page,
                  onChanged: (value) => update(() => page = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final games = find.byKey(const ValueKey('browse-games'));
    final films = find.byKey(const ValueKey('browse-films'));
    final selection = find.byKey(const ValueKey('browse-selection'));
    final drag = await tester.startGesture(tester.getCenter(games));
    await tester.pumpAndSettle();
    expect(tester.getRect(selection), tester.getRect(games));
    await drag.moveTo(tester.getCenter(films));
    await tester.pump();
    expect(tester.getRect(selection), tester.getRect(films));
    await drag.up();
    await tester.pumpAndSettle();
    expect(page, 'films');
  });

  for (final reduced in [false, true]) {
    testWidgets(
      'search expands from source and reverses safely; reduced=$reduced',
      (tester) async {
        final state = await fixtureState();
        await state.preference('reduced-motion', reduced);
        await tester.pumpWidget(RyhzeApp(state: state));
        await tester.pumpAndSettle();
        final source = find.byTooltip('Search Ryhze');
        final rect = tester.getRect(source);
        await tester.tap(source);
        await tester.pump();
        final surface = find.byKey(const ValueKey('expanding-surface'));
        if (!reduced) {
          expect(tester.getRect(surface).width, closeTo(rect.width, .1));
          await tester.pump(const Duration(milliseconds: 70));
          expect(tester.getRect(surface).width, greaterThan(rect.width));
          expect(tester.getRect(surface).width, lessThan(620));
        }
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
        await tester.tap(source);
        await tester.pumpAndSettle();
        expect(surface, findsOneWidget);
        expect(tester.getTopLeft(surface).dy, lessThan(90));
        expect(
          tester.widget<TextField>(find.byType(TextField)).focusNode!.hasFocus,
          isTrue,
        );
        await tester.enterText(find.byType(TextField), 'no match');
        await tester.pumpAndSettle();
        expect(find.textContaining('No matches'), findsOneWidget);
        await tester.tapAt(const Offset(2, 300));
        await tester.pumpAndSettle();
        expect(surface, findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
