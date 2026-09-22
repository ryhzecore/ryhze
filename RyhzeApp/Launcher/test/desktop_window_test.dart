import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/desktop_window.dart';
import 'package:ryhze/ui/design.dart';

void main() {
  testWidgets(
    'desktop controls invoke native actions and hide in Big Picture without remounting content',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final calls = <String>[];
      var nativeMaximized = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        DesktopWindow.channel,
        (call) async {
          calls.add(call.method);
          if (call.method == 'maximize') {
            nativeMaximized = !nativeMaximized;
            tester.binding.handleMetricsChanged();
          }
          return call.method == 'state' ? {'maximized': nativeMaximized} : null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          DesktopWindow.channel,
          null,
        ),
      );
      var count = 0;
      late ValueChanged<bool> fullscreen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          builder: (_, child) => DesktopWindow(child: child!),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                fullscreen = DesktopWindowScope.of(context)!.setFullscreen;
                return TextButton(
                  onPressed: () => update(() => count++),
                  child: Text('Content $count'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Content 0'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Minimize'));
      await tester.tap(find.byTooltip('Maximize'));
      await tester.pumpAndSettle();
      expect(calls, containsAllInOrder(['minimize', 'maximize']));
      expect(find.byTooltip('Restore window'), findsOneWidget);
      await tester.tap(find.byTooltip('Restore window'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Maximize'), findsOneWidget);
      fullscreen(true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Minimize'), findsNothing);
      expect(find.text('Content 1'), findsOneWidget);
      fullscreen(false);
      await tester.pumpAndSettle();
      expect(find.text('Content 1'), findsOneWidget);
      await tester.tap(find.byTooltip('Close Ryhze'));
      expect(calls.last, 'close');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('mobile has no desktop title controls', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(
      const MaterialApp(
        home: DesktopWindow(child: Scaffold(body: Text('Mobile'))),
      ),
    );
    expect(find.text('Mobile'), findsOneWidget);
    expect(find.byTooltip('Close Ryhze'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}
