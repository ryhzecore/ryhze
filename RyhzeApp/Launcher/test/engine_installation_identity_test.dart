import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/race_installation.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine_versions.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

void main() {
  setUpAll(() async {
    if (const String.fromEnvironment('RYHZE_SCREENSHOTS').isEmpty) return;
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test(
    'canonical Windows paths include slash, case, dot and long-path forms',
    () async {
      final installations = {
        'managed': {'executable': r'C:\RACE\versions\build9\RACE.exe'},
      };
      for (final executable in [
        'c:/race/versions/build9/RACE.EXE',
        r'C:\RACE\versions\build9\folder\..\RACE.exe',
        r'\\?\C:\RACE\versions\build9\RACE.exe',
      ]) {
        expect(
          await managedEngineForExecutable(executable, installations),
          'managed',
        );
      }
      expect(
        await canonicalEngineExecutable(r'\\?\UNC\server\share\RACE.exe'),
        await canonicalEngineExecutable(r'\\SERVER\share\race.exe'),
      );
    },
  );

  test(
    'same version and unverified identity never merge distinct executables',
    () async {
      expect(
        await managedEngineForExecutable(r'C:\checkout\RACE.exe', {
          'build9': {
            'executable': r'C:\installed\RACE.exe',
            'release': {'version': '0.0.9', 'id': 'build9'},
          },
        }),
        isNull,
      );
    },
  );

  testWidgets(
    'developer discovery, refresh and Locate prefer the same managed installation',
    (tester) async {
      if (!Platform.isWindows) return;
      tester.view.physicalSize = const Size(1100, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Directory root;
      late File managedExe;
      late File distinctExe;
      await tester.runAsync(() async {
        root = await Directory.systemTemp.createTemp('ryhze-engine-identity-');
        managedExe = await File(
          '${root.path}/managed/RACE.exe',
        ).create(recursive: true);
        distinctExe = await File(
          '${root.path}/checkout/RACE.exe',
        ).create(recursive: true);
      });
      addTearDown(() => root.delete(recursive: true));
      Map<String, dynamic>? discovery = {
        'executable': managedExe.path.toUpperCase().replaceAll('\\', '/'),
        'path': managedExe.parent.path,
        'version': '0.0.9',
      };
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        raceChannel,
        (call) async {
          if (call.method == 'pickExecutable') return discovery?['executable'];
          if (call.method == 'raceInstallation') return discovery;
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          raceChannel,
          null,
        ),
      );
      const id = 'RACE-0.0.9-Windows-identity-test';
      final release = {
        'id': id,
        'version': '0.0.9',
        'bytes': 1,
        'sha256': 'a' * 64,
        'url': '/api/engine/releases/$id/download',
        'entrypoint': '$id/RACE.exe',
      };
      var offline = false;
      final state = await fixtureState(
        user: const Member(
          'Developer',
          'viewer',
          developerAccess: true,
          engineDownloadAccess: true,
        ),
        client: MockClient(
          (r) async => http.Response(
            jsonEncode(
              offline
                  ? {'error': 'Offline'}
                  : {
                      'schema': 1,
                      'releases': [release],
                    },
            ),
            offline ? 503 : 200,
          ),
        ),
      );
      addTearDown(state.dispose);
      await state.prefs.setString('race-selected-build', 'located');
      final screenshot = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenshot,
          child: MaterialApp(
            theme: ryhzeTheme(),
            home: Scaffold(
              body: SingleChildScrollView(child: EngineVersions(state: state)),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      RyhzeDropdown<String> dropdown() =>
          tester.widget(find.byType(RyhzeDropdown<String>));
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        hasLength(1),
      );
      final installations = {
        id: {'executable': managedExe.path, 'release': release},
      };
      await state.prefs.setString(
        'race-managed-installations',
        jsonEncode(installations),
      );
      final dynamic controller = tester.state(find.byType(EngineVersions));
      await tester.runAsync(() async => controller.refresh());
      await tester.pumpAndSettle();
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        isEmpty,
      );
      expect(dropdown().value, id);
      expect(state.prefs.getString('race-selected-build'), id);
      await tester.runAsync(() async => controller.locate());
      await tester.pumpAndSettle();
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        isEmpty,
      );
      expect(dropdown().value, id);
      await tester.tap(find.byType(RyhzeDropdown<String>));
      await tester.pumpAndSettle();
      expect(find.text('Local installation (unverified)'), findsNothing);
      expect(find.text('V0.0.9 - Development Build - Installed'), findsWidgets);
      await tester.runAsync(
        () => capture(screenshot, 'developer-managed-version'),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      discovery = {
        'executable': distinctExe.path,
        'path': distinctExe.parent.path,
        'version': '0.0.9',
      };
      await tester.runAsync(() async => controller.locate());
      await tester.pumpAndSettle();
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        hasLength(1),
      );
      expect(dropdown().items.where((item) => item.value == id), hasLength(1));
      expect(dropdown().value, 'located');
      expect(find.textContaining(distinctExe.path), findsOneWidget);
      await tester.runAsync(
        () => capture(screenshot, 'developer-distinct-local-version'),
      );

      // The same reconciliation runs immediately after a successful installation.
      controller.installs[id]['executable'] = distinctExe.path;
      await tester.runAsync(() async => controller.reconcileLocated(discovery));
      await tester.runAsync(() async => controller.select(id));
      await tester.pumpAndSettle();
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        isEmpty,
      );
      expect(dropdown().value, id);

      // Losing a selected local copy must also leave a valid selection offline.
      controller.installs[id]['executable'] = managedExe.path;
      await tester.runAsync(() async => controller.locate());
      await tester.pumpAndSettle();
      expect(dropdown().value, 'located');
      offline = true;
      discovery = null;
      await tester.runAsync(() async => controller.refresh());
      await tester.pumpAndSettle();
      expect(
        dropdown().items.where((item) => item.value == 'located'),
        isEmpty,
      );
      expect(dropdown().value, id);
      expect(state.prefs.getString('race-selected-build'), id);
      expect(tester.takeException(), isNull);
    },
  );
}
