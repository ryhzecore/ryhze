import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:real_liquid_glass/real_liquid_glass.dart';
import 'package:ryhze/ui/design.dart';

void main() {
  testWidgets('native glass is gated to iOS', (tester) async {
    Widget? built;
    Widget? iosDialog;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            debugDefaultTargetPlatformOverride = TargetPlatform.windows;
            expect(usesIOSLiquidGlass, isFalse);
            final windows = const Glass(
              frameVisible: false,
              child: Text('content'),
            ).build(context);
            expect(windows, isA<ClipRSuperellipse>());
            expect(
              ((windows as ClipRSuperellipse).child! as BackdropFilter).enabled,
              isFalse,
            );
            expect(
              const RyhzeAlertDialog(title: Text('Title')).build(context),
              isA<AlertDialog>(),
            );

            debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
            expect(usesIOSLiquidGlass, isTrue);
            built = const Glass(child: Text('content')).build(context);
            iosDialog = const RyhzeAlertDialog(
              title: Text('Title'),
            ).build(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(built, isA<LiquidGlassContainer>());
    expect(iosDialog, isA<Dialog>());
    debugDefaultTargetPlatformOverride = null;
  });

  test('glass control themes only apply on iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final android = ryhzeTheme();
    expect(android.filledButtonTheme.style?.backgroundColor, isNull);
    expect(android.iconButtonTheme.style, isNull);

    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final ios = ryhzeTheme();
    expect(ios.filledButtonTheme.style?.backgroundColor, isNotNull);
    expect(ios.filledButtonTheme.style?.backgroundBuilder, isNotNull);
    expect(ios.textButtonTheme.style?.backgroundColor, isNotNull);
    expect(ios.textButtonTheme.style?.backgroundBuilder, isNotNull);
    expect(ios.iconButtonTheme.style, isNotNull);
    debugDefaultTargetPlatformOverride = null;
  });
}
