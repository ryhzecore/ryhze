import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in [
      ('Inter', 'assets/fonts/Inter.ttf'),
      ('Space Grotesk', 'assets/fonts/SpaceGrotesk.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(font.$1)..addFont(rootBundle.load(font.$2))).load();
    }
  });
  for (final width in [320.0, 360.0, 390.0, 430.0]) {
    for (final admin in [false, true]) {
      testWidgets('Phone header and hero fit $width admin=$admin', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        tester.view.padding = const FakeViewPadding(top: 28, bottom: 24);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPadding);
        final state = await fixtureState(
          user: admin ? const Member('Leo', 'admin') : null,
        );
        final boundary = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundary,
            child: RyhzeApp(state: state),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() => precacheImage(
          const AssetImage('assets/brand/symbol.png'),
          tester.element(find.byType(RyhzeApp)),
        ));
        await tester.pumpAndSettle();
        final logo = tester.getRect(find.bySemanticsLabel('Ryhze home'));
        final search = tester.getRect(find.byTooltip('Search Ryhze'));
        final library = tester.getRect(find.byTooltip('Game library'));
        final tabs = tester.getRect(find.byKey(const ValueKey('browse-games')));
        expect(logo.left, lessThanOrEqualTo(22));
        expect(search.center.dy, closeTo(logo.center.dy, 1));
        expect(library.right, closeTo(width - (width <= 350 ? 14 : 22), 1));
        expect(library.width, library.height);
        expect(tabs.top, greaterThan(logo.bottom));
        final explore = tester.getRect(find.text('Explore the game').first);
        expect(explore.bottom, lessThan(756));
        expect(tester.takeException(), isNull);
        await tester.runAsync(
          () => capture(boundary, 'phone-${width.toInt()}-$admin'),
        );
        await tester.tap(find.byTooltip('Game library'));
        await tester.pumpAndSettle();
        expect(find.text('Your library.'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
      });
    }
  }
}
