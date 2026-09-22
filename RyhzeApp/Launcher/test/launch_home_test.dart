import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/steamdeck_startup.dart';
import 'package:ryhze/ui/launch_home.dart';

class FakeStartup extends SteamDeckStartup {
  bool enabled = false, fail = false;
  final changes = <bool>[];
  @override
  Future<bool> read() async => enabled;
  @override
  Future<bool> setEnabled(bool value) async {
    changes.add(value);
    if (fail) throw StateError('SteamOS denied the change');
    return enabled = value;
  }
}

void main() {
  testWidgets(
    'Launch Home is off for Steam, on for Ryhze, and can switch back',
    (tester) async {
      final service = FakeStartup();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LaunchHomeSetting(startup: service)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Launch Home'), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.changes, [true]);
      expect(find.text('Next startup: Ryhze Big Picture.'), findsOneWidget);
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(service.changes, [true, false]);
      expect(find.text('Next startup: Steam Gaming Mode.'), findsOneWidget);
    },
  );
  testWidgets('failed changes never show a successful boot setting', (
    tester,
  ) async {
    final service = FakeStartup()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LaunchHomeSetting(startup: service)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.textContaining('SteamOS denied'), findsOneWidget);
    expect(find.text('Startup setting unavailable'), findsOneWidget);
    expect(find.text('Next startup: Ryhze Big Picture.'), findsNothing);
  });
}
