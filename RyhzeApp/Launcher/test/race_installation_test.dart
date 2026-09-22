import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/race_installation.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const installation = {
    'path': r'E:\RACE',
    'executable': r'E:\RACE\race_editor.exe',
    'version': '0.1.0',
    'build': 1,
  };
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(raceChannel, null));
  testWidgets('Local RACE is shown before online updates finish', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(raceChannel, (_) async => installation);
    final online = Completer<http.Response>();
    final state = await fixtureState(
      user: const Member('Leo', 'admin'),
      client: MockClient((_) => online.future),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Scaffold(body: EnginePage(state: state)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (!Platform.isWindows) {
      expect(find.text('Local installation (unverified)'), findsNothing);
      expect(find.text('Install and launch RACE from Ryhze on Windows.'),
          findsOneWidget);
      online.complete(http.Response('{"schema":1,"releases":[]}', 200));
      await tester.pumpAndSettle();
      expect(find.text('Launch selected version'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
      return;
    }
    expect(find.text('Local installation (unverified)'), findsOneWidget);
    expect(find.textContaining('Executable reports 0.1.0.'), findsOneWidget);
    expect(find.text('V0.1.0 - Local Build'), findsNothing);
    final open = tester.widget<Pill>(
      find.widgetWithText(Pill, 'Launch selected version'),
    );
    expect(open.onPressed, isNull);
    expect(find.text('Locate RACE'), findsOneWidget);
    online.complete(http.Response('{"schema":1,"releases":[]}', 200));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Pill>(find.widgetWithText(Pill, 'Launch selected version'))
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets(
    'Admin library keeps missing RACE visible and refreshes discovery',
    (tester) async {
      Map<String, Object>? found;
      messenger.setMockMethodCallHandler(raceChannel, (_) async => found);
      final state = await fixtureState(user: const Member('Andru', 'admin'));
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 380,
              child: InstalledEngineCard(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RACE'), findsOneWidget);
      expect(find.text('Install or locate'), findsOneWidget);
      found = installation;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      if (!Platform.isWindows) {
        expect(find.text('Installed'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
        await tester.pumpAndSettle();
        expect(find.text('Install and launch RACE from Ryhze on Windows.'),
            findsOneWidget);
        expect(find.text('Launch selected version'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        state.dispose();
        return;
      }
      expect(find.text('Installed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
      await tester.pumpAndSettle();
      expect(find.byType(RaceDetail), findsOneWidget);
      expect(find.text('Launch selected version'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    },
  );
  test(
    'A stale saved path falls back to registry; manual selection stays strict',
    () async {
      messenger.setMockMethodCallHandler(
        raceChannel,
        (call) async =>
            (call.arguments as Map)['path'] == '' ? installation : null,
      );
      if (!Platform.isWindows) {
        expect(await raceInstallation(directory: r'F:\old'), isNull);
        expect(
          await raceInstallation(directory: r'F:\wrong.exe', strict: true),
          isNull,
        );
        return;
      }
      expect(await raceInstallation(directory: r'F:\old'), installation);
      expect(
        await raceInstallation(directory: r'F:\wrong.exe', strict: true),
        isNull,
      );
    },
  );
}
