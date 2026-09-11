import 'dart:async';
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
    expect(find.text('Installed: 0.1.0'), findsOneWidget);
    final open = tester.widget<Pill>(find.widgetWithText(Pill, 'Launch RACE'));
    expect(open.onPressed, isNotNull);
    expect(find.text('Locate RACE'), findsOneWidget);
    online.complete(http.Response('{"available":false}', 200));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'RACE is installed on this PC. Online updates are not available yet.',
      ),
      findsOneWidget,
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
          home: Scaffold(body: InstalledEngineCard(state: state)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('RACE'), findsOneWidget);
      expect(find.text('Install or locate'), findsOneWidget);
      found = installation;
      await tester.pump(const Duration(seconds: 15));
      await tester.pumpAndSettle();
      expect(find.text('Installed'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
      await tester.pumpAndSettle();
      expect(find.byType(RaceDetail), findsOneWidget);
      expect(find.text('Launch RACE'), findsOneWidget);
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
      expect(await raceInstallation(directory: r'F:\old'), installation);
      expect(
        await raceInstallation(directory: r'F:\wrong.exe', strict: true),
        isNull,
      );
    },
  );
}
