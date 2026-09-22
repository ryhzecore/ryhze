import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'interaction_checks.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
  });
  interactionChecks();
  for (final width in [320.0, 390.0, 700.0, 1000.0, 1280.0, 1920.0]) {
    testWidgets(
      'header and panels remain usable at ${width.toInt()}px with 150% display scaling',
      (tester) async {
        tester.view.physicalSize = Size(width * 1.5, 820 * 1.5);
        tester.view.devicePixelRatio = 1.5;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = await fixtureState();
        await tester.pumpWidget(RyhzeApp(state: state));
        await tester.pumpAndSettle();
        final search = find.byTooltip('Search Ryhze');
        final menu = find.byTooltip('Account and settings');
        final tabs = tester.getRect(find.byType(BrowseTabs));
        final menuRect = tester.getRect(menu);
        if (width > 480) {
          final searchRect = tester.getRect(search);
          expect(searchRect.left, greaterThanOrEqualTo(tabs.right));
          final libraryRect = tester.getRect(find.byTooltip('Game library'));
          expect(libraryRect.left, greaterThan(menuRect.right));
          expect(libraryRect.width, closeTo(libraryRect.height, .01));
          expect(libraryRect.right, lessThanOrEqualTo(width));
          expect(menuRect.left, greaterThan(searchRect.right));
          expect(searchRect.width, closeTo(searchRect.height, .01));
        } else {
          final brand = tester.getRect(find.byType(BetaBrand).first);
          expect(tabs.left, greaterThan(brand.right));
          expect(tabs.center.dy, closeTo(brand.center.dy, .01));
          expect(menuRect.left, greaterThanOrEqualTo(tabs.right));
          expect(search, findsNothing);
        }
        expect(menuRect.right, lessThanOrEqualTo(width));
        if (width <= 480) {
          await tester.tap(menu);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Search Ryhze'));
        } else {
          await tester.tap(search);
        }
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('expanding-surface'))).dy,
          lessThan(110),
        );
        await tester.enterText(find.byType(TextField), 'nothing found');
        await tester.pumpAndSettle();
        expect(find.textContaining('No matches'), findsOneWidget);
        await tester.tap(find.byTooltip('Close search'));
        await tester.pumpAndSettle();
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Reduced motion'));
        await tester.pumpAndSettle();
        expect(state.reduced, true);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('card-open-larcenous-driftscape')),
        );
        await tester.tap(
          find.byKey(const ValueKey('card-open-larcenous-driftscape')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Back'), findsOneWidget);
        // Clicking the modal backdrop must close the title, as it does on the web.
        await tester.tapAt(const Offset(2, 120));
        await tester.pumpAndSettle();
        expect(find.text('Back'), findsNothing);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Sign in'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Sign in').last);
        await tester.tap(find.text('Sign in').last);
        await tester.pumpAndSettle();
        expect(find.text('Enter your user ID.'), findsOneWidget);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(find.widgetWithText(ListTile, 'Our story'), findsNothing);
        await tester.tap(find.widgetWithText(ListTile, 'Report Bug'));
        await tester.pumpAndSettle();
        expect(find.text('support@ryhze.com'), findsOneWidget);
        expect(find.text('Open email'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
