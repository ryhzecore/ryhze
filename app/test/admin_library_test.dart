import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

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
  for (final width in [320.0, 390.0, 500.0, 700.0, 1000.0, 1280.0]) {
    testWidgets('Admin library header fits at $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browse-engine')), findsOneWidget);
      final menu = tester.getRect(find.byTooltip('Account and settings'));
      final library = tester.getRect(find.byTooltip('Game library'));
      expect(library.left, greaterThan(menu.right));
      expect(library.width, library.height);
      expect(library.right, lessThanOrEqualTo(width));
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => capture(boundary, 'admin-header-${width.toInt()}'),
      );
      await tester.tap(find.byTooltip('Game library'));
      await tester.pumpAndSettle();
      expect(find.text('Your library.'), findsOneWidget);
      await tester.runAsync(
        () => capture(boundary, 'admin-library-${width.toInt()}'),
      );
      expect(find.text('Made to explore.'), findsNothing);
      state.user = null;
      state.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('browse-engine')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
  testWidgets('Engine selection supports keyboard and drag', (tester) async {
    String page = 'games';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, update) => Scaffold(
            body: Center(
              child: BrowseTabs(
                page: page,
                engineAvailable: true,
                onChanged: (value) => update(() => page = value),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('browse-engine')));
    await tester.pumpAndSettle();
    expect(page, 'engine');
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('browse-engine'))),
    );
    await gesture.moveTo(
      tester.getCenter(find.byKey(const ValueKey('browse-games'))),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(page, 'games');
  });
  test('Launcher permissions require named admins and role', () {
    expect(const Member('Andru', 'admin').launcherAdmin, true);
    expect(const Member('Leo', 'admin').launcherAdmin, true);
    expect(const Member('Leo', 'viewer').launcherAdmin, false);
    expect(const Member('Other', 'admin').launcherAdmin, false);
  });
}
