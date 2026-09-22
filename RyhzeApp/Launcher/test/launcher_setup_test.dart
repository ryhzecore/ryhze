import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/steamdeck_startup.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/launcher_setup.dart';

class SetupStartup extends SteamDeckStartup {
  final choices = <bool>[];
  Completer<bool>? pending;
  bool fail = false;
  @override
  Future<bool> setEnabled(bool enabled) async {
    choices.add(enabled);
    if (fail) throw StateError('SteamOS could not save the choice.');
    return pending == null ? enabled : pending!.future;
  }
}

void main() {
  testWidgets(
    'choice waits for intro and cancellation preserves boot settings',
    (tester) async {
      final startup = SetupStartup();
      Widget page(bool ready) => MaterialApp(
        theme: ryhzeTheme(),
        home: LauncherSetupGate(
          requested: true,
          ready: ready,
          startup: startup,
          builder: (blocked) =>
              Scaffold(body: Text(blocked ? 'Blocked' : 'Ready')),
        ),
      );
      await tester.pumpWidget(page(false));
      await tester.pumpAndSettle();
      expect(find.text('Choose your home'), findsNothing);
      expect(find.text('Blocked'), findsOneWidget);
      await tester.pumpWidget(page(true));
      await tester.pumpAndSettle();
      expect(find.text('Choose your home'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(startup.choices, isEmpty);
      expect(find.text('Ready'), findsOneWidget);
    },
  );

  testWidgets(
    'Ryhze keeps other prompts blocked until the setting is confirmed',
    (tester) async {
      final startup = SetupStartup()..pending = Completer<bool>();
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: LauncherSetupGate(
            requested: true,
            ready: true,
            startup: startup,
            builder: (blocked) =>
                Scaffold(body: Text(blocked ? 'Blocked' : 'Ready')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ryhze'));
      await tester.pump();
      expect(startup.choices, [true]);
      expect(find.text('Blocked'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Not now'))
            .onPressed,
        isNull,
      );
      startup.pending!.complete(true);
      await tester.pumpAndSettle();
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Choose your home'), findsNothing);
    },
  );

  for (final fail in [false, true]) {
    testWidgets('Steam launches only after confirmed save (failure=$fail)', (
      tester,
    ) async {
      final startup = SetupStartup()..fail = fail;
      int steamLaunches = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: LauncherSetupGate(
            requested: true,
            ready: true,
            startup: startup,
            openSteam: () async {
              steamLaunches++;
            },
            builder: (_) => const Scaffold(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Steam'));
      await tester.pumpAndSettle();
      expect(startup.choices, [false]);
      expect(steamLaunches, fail ? 0 : 1);
      expect(
        find.text('Choose your home'),
        fail ? findsOneWidget : findsNothing,
      );
      if (fail) {
        expect(find.text('SteamOS could not save the choice.'), findsOneWidget);
      }
    });
  }

  testWidgets('a Steam opening error distinguishes the saved boot choice', (
    tester,
  ) async {
    final startup = SetupStartup();
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: LauncherSetupGate(
          requested: true,
          ready: true,
          startup: startup,
          openSteam: () async => throw StateError('Steam could not open.'),
          builder: (_) => const Scaffold(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steam'));
    await tester.pumpAndSettle();
    expect(
      find.text('Your startup choice was saved. Steam could not open.'),
      findsOneWidget,
    );
    expect(find.text('Choose your home'), findsOneWidget);
  });
}
