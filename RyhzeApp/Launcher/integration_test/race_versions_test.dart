import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine_versions.dart';
import 'package:ryhze/ui/option_menu.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

class QaPaths extends PathProviderPlatform {
  final directory = Directory.systemTemp.createTempSync(
    'ryhze-race-build30-qa-',
  );
  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'install two verified RACE versions and switch without replacing either',
    (tester) async {
      PathProviderPlatform.instance = QaPaths();
      final transport = http.Client();
      final session = jsonDecode(
        (await transport.get(
          Uri.parse(
            '${const String.fromEnvironment('RYHZE_API_ORIGIN')}/api/session',
          ),
        )).body,
      );
      final state = await fixtureState(
        user: Member.fromJson(session['user']),
        client: transport,
      );
      final key = GlobalKey();
      final downloadSamples = <double>[];
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            theme: ryhzeTheme(),
            home: Scaffold(
              body: SingleChildScrollView(child: EngineVersions(state: state)),
            ),
          ),
        ),
      );
      Future<void> idle() async {
        final deadline = DateTime.now().add(const Duration(minutes: 4));
        do {
          await tester.pump(const Duration(milliseconds: 200));
          for (final status in tester.widgetList<StatusProgress>(
            find.byType(StatusProgress),
          )) {
            if (status.value != null) downloadSamples.add(status.value!);
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          if (DateTime.now().isAfter(deadline)) {
            fail('RACE operation timed out');
          }
        } while (find.byType(StatusProgress).evaluate().isNotEmpty);
        await tester.pumpAndSettle();
      }

      await idle();
      final dropdown = tester.widget<RyhzeDropdown<String>>(
        find.byType(RyhzeDropdown<String>),
      );
      final ids = dropdown.items
          .map((item) => item.value)
          .whereType<String>()
          .where((id) => id != 'located')
          .toList();
      expect(ids.length, greaterThanOrEqualTo(2));
      for (final id in ids.take(2)) {
        tester
            .widget<RyhzeDropdown<String>>(find.byType(RyhzeDropdown<String>))
            .onChanged!(id);
        await tester.pumpAndSettle();
        final install = find.text('Install selected version');
        await tester.ensureVisible(install);
        await tester.tap(install);
        await idle();
        expect(
          find.text('Launch selected version'),
          findsOneWidget,
          reason: tester
              .widgetList<Text>(find.byType(Text))
              .map((t) => t.data)
              .join(' | '),
        );
        final installed = jsonDecode(
          state.prefs.getString('race-managed-installations')!,
        );
        expect(await File(installed[id]['executable']).exists(), isTrue);
      }
      final installed =
          jsonDecode(state.prefs.getString('race-managed-installations')!)
              as Map;
      expect(installed.length, 2);
      tester
          .widget<RyhzeDropdown<String>>(find.byType(RyhzeDropdown<String>))
          .onChanged!(ids.first);
      await tester.pumpAndSettle();
      expect(state.prefs.getString('race-selected-build'), ids.first);
      for (final item in installed.values) {
        expect(await File(item['executable']).exists(), isTrue);
      }
      final remove = find.text('Uninstall selected version');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Uninstall'));
      await idle();
      expect(await File(installed[ids.first]['executable']).exists(), isFalse);
      expect(await File(installed[ids[1]]['executable']).exists(), isTrue);
      final reinstall = find.text('Install selected version');
      await tester.ensureVisible(reinstall);
      await tester.tap(reinstall);
      await idle();
      expect(
        find.text('Launch selected version'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      expect(await File(installed[ids.first]['executable']).exists(), isTrue);
      expect(
        downloadSamples.any((v) => v > 0 && v < 1),
        isTrue,
        reason: 'Real byte progress must appear before download completion.',
      );
      await File(
        r'C:\Test123\.codex\ui-review\build30-race-installed.json',
      ).writeAsString(jsonEncode(installed));
      await capture(key, 'race-two-installed-versions');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
