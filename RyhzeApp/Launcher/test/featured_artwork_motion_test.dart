import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/featured_artwork_motion.dart';

void main() {
  testWidgets(
    'featured camera drifts slowly without exposed edges and pauses for overlays',
    (tester) async {
      var active = true, reduced = false;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return Center(
                child: SizedBox(
                  width: 600,
                  height: 400,
                  child: FeaturedArtworkMotion(
                    active: active,
                    reduced: reduced,
                    child: const ColoredBox(color: Colors.blue),
                  ),
                ),
              );
            },
          ),
        ),
      );
      Matrix4 matrix() => tester
          .widget<Transform>(
            find.byKey(const ValueKey('featured-artwork-drift')),
          )
          .transform
          .clone();
      final first = matrix();
      await tester.pump(const Duration(seconds: 9));
      final middle = matrix();
      expect(middle, isNot(first));
      expect(middle.entry(0, 0), inExclusiveRange(1.04, 1.085));
      for (var i = 0; i < 5; i++) {
        final m = matrix();
        expect(m.entry(0, 3).abs(), lessThan((m.entry(0, 0) - 1) * 300));
        expect(m.entry(1, 3).abs(), lessThan((m.entry(1, 1) - 1) * 200));
        await tester.pump(const Duration(seconds: 6));
      }
      update(() => active = false);
      await tester.pump();
      final paused = matrix();
      await tester.pump(const Duration(seconds: 9));
      expect(matrix(), paused);
      update(() => reduced = true);
      await tester.pump();
      expect(matrix(), Matrix4.identity());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
