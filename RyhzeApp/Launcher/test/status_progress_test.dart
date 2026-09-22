import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/design.dart';

void main() {
  testWidgets(
    'rapid byte updates match the fill on the same frame without a trailing animation',
    (tester) async {
      var value = .01;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return StatusProgress(label: 'Downloading', value: value);
            },
          ),
        ),
      );
      for (final next in [.12, .38, .77, .999, 1.0]) {
        update(() => value = next);
        await tester.pump(const Duration(milliseconds: 16));
        expect(
          tester
              .widget<FractionallySizedBox>(
                find.byKey(const ValueKey('actual-progress-fill')),
              )
              .widthFactor,
          next,
        );
        expect(
          find.text('Downloading ${(next * 100).floor()}%'),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets(
    'status fill is elongated, non-actionable and reports actual progress',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: StatusProgress(label: 'Installing', value: .4)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Installing 40%'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsNothing);
      final rect = tester.getRect(find.byType(StatusProgress));
      expect(rect.width, greaterThan(rect.height * 4));
    },
  );
  testWidgets(
    'unknown progress respects reduced motion without claiming a percentage',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(body: StatusProgress(label: 'Loading video')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading video'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, isFalse);
    },
  );
}
