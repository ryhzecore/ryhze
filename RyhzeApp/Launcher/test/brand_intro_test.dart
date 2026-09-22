import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/brand_intro.dart';

Future<void> advance(WidgetTester tester, Duration duration) async {
  var remaining = duration.inMilliseconds;
  while (remaining > 0) {
    final step = remaining.clamp(1, 16);
    await tester.pump(Duration(milliseconds: step));
    remaining -= step;
  }
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets('startup reveals once and keeps page state, reduced=$reduced', (
      tester,
    ) async {
      var mounts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: BrandIntro(
            sound: false,
            reduced: reduced,
            builder: (_) => _Page(onMount: () => mounts++),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Skip intro'), findsOneWidget);
      await advance(tester, const Duration(milliseconds: 2999));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('brand-intro-logo')))
            .transform
            .entry(0, 0),
        1,
      );
      await advance(tester, const Duration(milliseconds: 1));
      await tester.pump();
      await advance(tester, const Duration(milliseconds: 700));
      await tester.pump();
      await advance(tester, const Duration(milliseconds: 450));
      final logo = tester.widget<Transform>(
        find.byKey(const ValueKey('brand-intro-logo')),
      );
      expect(logo.transform.entry(0, 0), reduced ? 1 : greaterThan(1));
      await advance(tester, const Duration(milliseconds: 500));
      expect(find.text('Skip intro'), findsNothing);
      expect(mounts, 1);
      await tester.tap(find.text('Page'));
      await tester.pump();
      expect(find.text('Page 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('brand-intro-logo')), findsNothing);
    });
  }
  testWidgets(
    'slow loading delays sound and shine until ready without replay',
    (tester) async {
      var ready = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return BrandIntro(
                ready: ready,
                sound: false,
                builder: (_) => const Scaffold(body: Text('Page')),
              );
            },
          ),
        ),
      );
      await advance(tester, const Duration(seconds: 5));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('brand-intro-logo')))
            .transform
            .entry(0, 0),
        1,
      );
      expect(find.text('Skip intro'), findsOneWidget);
      update(() => ready = true);
      await tester.pump();
      await advance(tester, const Duration(milliseconds: 350));
      expect(find.byKey(const ValueKey('brand-intro-shine')), findsOneWidget);
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('brand-intro-logo')))
            .transform
            .entry(0, 0),
        1,
      );
      await advance(tester, const Duration(milliseconds: 350));
      await tester.pump();
      await advance(tester, const Duration(milliseconds: 300));
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('brand-intro-logo')))
            .transform
            .entry(0, 0),
        greaterThan(1),
      );
      await advance(tester, const Duration(seconds: 4));
      expect(find.text('Skip intro'), findsNothing);
      update(() => ready = false);
      await tester.pump();
      update(() => ready = true);
      await tester.pump();
      expect(find.text('Skip intro'), findsNothing);
    },
  );
  testWidgets('skipping the reflection cancels the pending zoom', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(
          sound: false,
          builder: (_) => const Scaffold(body: Text('Page')),
        ),
      ),
    );
    await advance(tester, const Duration(seconds: 3));
    await tester.pump();
    await advance(tester, const Duration(milliseconds: 350));
    await tester.tap(find.text('Skip intro'));
    await advance(tester, const Duration(seconds: 5));
    expect(find.text('Skip intro'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Escape skips and releases the page', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BrandIntro(
          sound: false,
          builder: (_) => const Scaffold(body: Text('Ready')),
        ),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.text('Skip intro'), findsNothing);
    expect(find.text('Ready'), findsOneWidget);
  });
}

class _Page extends StatefulWidget {
  final VoidCallback onMount;
  const _Page({required this.onMount});
  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  int clicks = 0;
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: TextButton(
      onPressed: () => setState(() => clicks++),
      child: Text(clicks == 0 ? 'Page' : 'Page $clicks'),
    ),
  );
}
