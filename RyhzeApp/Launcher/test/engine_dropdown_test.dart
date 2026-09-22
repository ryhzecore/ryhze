import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'website_parity_test.dart' show capture;

void main() {
  for (final width in [320.0, 1400.0]) {
    testWidgets(
      'RACE popup matches anchor at $width and dismisses by keyboard',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        String? choice;
        final screenshot = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenshot,
            child: MaterialApp(
              theme: ryhzeTheme(),
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: width - 40,
                    child: RyhzeDropdown<String>(
                      fullWidthMenu: true,
                      isExpanded: true,
                      value: 'a',
                      items: const [
                        DropdownMenuItem(
                          value: 'a',
                          child: Text('V0.0.7 - Source Backup'),
                        ),
                        DropdownMenuItem(
                          value: 'b',
                          child: Text('V0.0.6 - Project Presets'),
                        ),
                      ],
                      onChanged: (value) => choice = value,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final source = tester.getRect(find.byType(RyhzeDropdown<String>));
        await tester.tap(find.byType(RyhzeDropdown<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final opening = tester.getRect(
          find.byKey(const ValueKey('expanding-surface')),
        );
        expect(opening.height, greaterThan(source.height));
        expect(opening.height, lessThan(112));
        await tester.pumpAndSettle();
        final popup = tester.getRect(
          find.byKey(const ValueKey('expanding-surface')),
        );
        expect(popup.width, closeTo(source.width, .01));
        expect(popup.left, closeTo(source.left, .01));
        expect(popup.right, lessThanOrEqualTo(width));
        await tester.runAsync(() => capture(screenshot, 'race-selector-$width'));
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(choice, 'b');
        await tester.tap(find.byType(RyhzeDropdown<String>));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('full-width-options')), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(RyhzeDropdown<String>));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('full-width-options')), findsNothing);
        await tester.tap(find.byType(RyhzeDropdown<String>));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(4, 4));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('full-width-options')), findsNothing);
      },
    );
  }
}
