import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine_demo.dart';
import 'package:ryhze/ui/engine.dart' show RaceArtwork;
import 'package:ryhze/ui/player.dart';
import 'package:ryhze/ui/engine_versions.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'package:ryhze/ui/playback_bar.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

class DemoQaPaths extends PathProviderPlatform {
  final directory = Directory.systemTemp.createTempSync('ryhze-race-demo-qa-');
  @override
  Future<String?> getApplicationSupportPath() async => directory.path;
  @override
  Future<String?> getTemporaryPath() async => Directory.systemTemp.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final ids = const String.fromEnvironment(
    'RYHZE_QA_RACE_BUILDS',
    defaultValue: 'RACE-0.0.4-Windows,RACE-0.0.3-Windows-20260912-201847-989',
  ).split(',');

  Future<void> until(WidgetTester tester, bool Function() done) async {
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(minutes: 3));
    while (!done()) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (DateTime.now().isAfter(deadline)) fail('Native operation timed out');
    }
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('inline artwork demo switches with selected release', (
    tester,
  ) async {
    final state = await fixtureState(
      user: const Member('Leo', 'admin'),
      client: http.Client(),
    );
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: EngineVersions(
                state: state,
                artworkBuilder: (build) => build?.demo == null
                    ? const SizedBox()
                    : EngineDemoArtwork(
                        key: ValueKey(build!.id),
                        state: state,
                        buildId: build.id,
                        demo: build.demo!,
                        poster: const RaceArtwork(),
                        aspectRatio: 1.5,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    await until(tester, () => find.byType(StatusProgress).evaluate().isEmpty);
    for (final id in ids) {
      tester
          .widget<RyhzeDropdown<String>>(find.byType(RyhzeDropdown<String>))
          .onChanged!(id);
      await tester.pumpAndSettle();
      final playerWidget = tester.widget<RyhzePlayer>(find.byType(RyhzePlayer));
      expect(
        playerWidget.title.streams.single,
        '/api/engine/releases/$id/demo',
      );
      expect(playerWidget.recordProgress, isFalse);
      expect(find.byType(PlaybackBar), findsNothing);
      await tester.ensureVisible(find.text('Play'));
      await tester.tap(find.text('Play'));
      await until(tester, () => find.byType(PlaybackBar).evaluate().isNotEmpty);
      final player = tester
          .widget<PlaybackBar>(find.byType(PlaybackBar))
          .player;
      await until(tester, () => player.state.position.inMilliseconds > 700);
      await player.seek(const Duration(seconds: 12));
      await until(tester, () => player.state.position.inSeconds >= 11);
      await player.pause();
      final ratio = tester
          .widgetList<AspectRatio>(
            find.descendant(
              of: find.byType(RyhzePlayer),
              matching: find.byType(AspectRatio),
            ),
          )
          .first
          .aspectRatio;
      expect(ratio, 1.5);
      expect(find.text('Watch tech demo'), findsNothing);
      await capture(key, 'race-inline-$id');
    }
    await state.setAdminAccess(false);
    await tester.pumpAndSettle();
    expect(find.byType(PlaybackBar), findsNothing);
    expect(state.history, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });

  for (final id in ids) {
    testWidgets(
      'protected demo playback, seeking and fullscreen revocation: $id',
      (tester) async {
        final state = await fixtureState(
          user: const Member('Leo', 'admin'),
          client: http.Client(),
        );
        final catalogue = await state.api.request('/api/engine/releases');
        final release = EngineBuild.fromJson(
          Map<String, dynamic>.from(
            (catalogue['releases'] as List).firstWhere((r) => r['id'] == id),
          ),
        );
        expect(release.demo, isNotNull);
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: ryhzeTheme(),
              home: EngineDemoPage(
                state: state,
                buildId: id,
                version: release.version,
                demo: release.demo!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Play'));
        await tester.tap(find.text('Play'));
        await until(
          tester,
          () => find.byType(PlaybackBar).evaluate().isNotEmpty,
        );
        final bar = tester.widget<PlaybackBar>(find.byType(PlaybackBar));
        final player = bar.player;
        await until(tester, () => player.state.position.inMilliseconds > 700);
        expect(player.state.duration.inSeconds, greaterThanOrEqualTo(20));
        await player.seek(const Duration(seconds: 12));
        await until(tester, () => player.state.position.inSeconds >= 11);
        await player.pause();
        expect(player.state.playing, isFalse);
        await capture(key, 'race-demo-${release.version}-playing');
        bar.onFullscreen();
        await tester.pumpAndSettle();
        expect(find.text('Exit full screen'), findsOneWidget);
        await state.setAdminAccess(false);
        await tester.pumpAndSettle();
        expect(find.byType(PlaybackBar), findsNothing);
        expect(
          find.text('Playback access is no longer available.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Exit full screen'));
        await tester.pumpAndSettle();
        expect(state.library.entries, isEmpty);
        expect(state.history, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }

  testWidgets(
    'install, select and launch exact released RACE builds without replacing versions',
    (tester) async {
      final paths = DemoQaPaths();
      PathProviderPlatform.instance = paths;
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: http.Client(),
      );
      final key = GlobalKey();
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
      await until(tester, () => find.byType(StatusProgress).evaluate().isEmpty);
      for (final id in ids) {
        tester
            .widget<RyhzeDropdown<String>>(find.byType(RyhzeDropdown<String>))
            .onChanged!(id);
        await tester.pumpAndSettle();
        final catalogue = await state.api.request('/api/engine/releases');
        final metadata = (catalogue['releases'] as List).firstWhere(
          (r) => r['id'] == id,
        );
        expect(find.text(metadata['notes'] as String), findsOneWidget);
        await tester.ensureVisible(find.text(metadata['notes'] as String));
        await capture(key, 'race-notes-$id');
        final install = find.text('Install selected version');
        await tester.ensureVisible(install);
        await tester.tap(install);
        var sawDownloadComplete = false;
        Future<void>? downloadCapture;
        await until(tester, () {
          for (final bar in tester.widgetList<StatusProgress>(
            find.byType(StatusProgress),
          )) {
            if (bar.label == 'Download complete') {
              expect(bar.value, 1);
              sawDownloadComplete = true;
              downloadCapture ??= capture(key, 'race-download-complete-$id');
            }
          }
          return find.byType(StatusProgress).evaluate().isEmpty;
        });
        expect(
          sawDownloadComplete,
          isTrue,
          reason:
              'Full download bar must remain visible during verification and installation',
        );
        await downloadCapture;
        expect(find.text('Launch selected version'), findsOneWidget);
        final installs =
            jsonDecode(state.prefs.getString('race-managed-installations')!)
                as Map;
        final exe = installs[id]['executable'] as String;
        expect(await File(exe).exists(), isTrue);
        expect(state.prefs.getString('race-selected-build'), id);
        final launch = find.text('Launch selected version');
        await tester.ensureVisible(launch);
        await tester.tap(launch);
        await until(
          tester,
          () => find.byType(StatusProgress).evaluate().isEmpty,
        );
        final result = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r'$limit=(Get-Date).AddSeconds(30); do { $p=Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq [IO.Path]::GetFullPath($env:RYHZE_QA_EXE) -and $_.MainWindowHandle -ne 0 }; if($p){ exit 0 }; Start-Sleep -Milliseconds 200 } while((Get-Date) -lt $limit); exit 1',
          ],
          environment: {...Platform.environment, 'RYHZE_QA_EXE': exe},
        );
        expect(
          result.exitCode,
          0,
          reason: 'Selected packaged editor must open a real window',
        );
        await tester.tap(launch);
        await until(
          tester,
          () => find.byType(StatusProgress).evaluate().isEmpty,
        );
        expect(
          find.text('This RACE version is already running.'),
          findsOneWidget,
        );
        if (const bool.fromEnvironment('RYHZE_QA_UNINSTALL')) {
          await tester.ensureVisible(find.text('Uninstall selected version'));
          await tester.tap(find.text('Uninstall selected version'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Uninstall'));
          await until(
            tester,
            () => find.byType(StatusProgress).evaluate().isEmpty,
          );
          expect(
            find.textContaining('This RACE version is running.'),
            findsOneWidget,
          );
          expect(await File(exe).exists(), isTrue);
        }
        final duplicate = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            r'$p=@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq [IO.Path]::GetFullPath($env:RYHZE_QA_EXE) }); $count=$p.Count; $p | ForEach-Object { $_.CloseMainWindow() | Out-Null }; if($count -eq 1){exit 0}; exit 1',
          ],
          environment: {...Platform.environment, 'RYHZE_QA_EXE': exe},
        );
        expect(
          duplicate.exitCode,
          0,
          reason: 'Repeated launch must retain exactly one process',
        );
      }
      final installs =
          jsonDecode(state.prefs.getString('race-managed-installations')!)
              as Map;
      expect(installs.keys.toSet(), ids.toSet());
      for (final entry in installs.values) {
        expect(await File(entry['executable']).exists(), isTrue);
      }
      if (const bool.fromEnvironment('RYHZE_QA_UNINSTALL')) {
        final removed = ids.last;
        final removedExe = installs[removed]['executable'] as String;
        final project = File(
          '${paths.directory.path}/Projects/preservation.txt',
        );
        await project.parent.create(recursive: true);
        await project.writeAsString(
          'Keep this project through uninstall/reinstall',
        );
        final olderProjects = <File>[];
        for (final id in ids.where((id) => id != removed)) {
          final file = File(
            '${File(installs[id]['executable']).parent.path}/user-project.txt',
          );
          await file.writeAsString('Older version project: $id');
          olderProjects.add(file);
        }
        await tester.ensureVisible(find.text('Uninstall selected version'));
        await tester.tap(find.text('Uninstall selected version'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(await File(removedExe).exists(), isTrue);
        await tester.tap(find.text('Uninstall selected version'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Uninstall'));
        await until(
          tester,
          () => find.byType(StatusProgress).evaluate().isEmpty,
        );
        expect(find.text('Install selected version'), findsOneWidget);
        expect(await File(removedExe).exists(), isFalse);
        var current =
            jsonDecode(state.prefs.getString('race-managed-installations')!)
                as Map;
        expect(current.containsKey(removed), false);
        for (final id in ids.where((id) => id != removed)) {
          expect(await File(current[id]['executable']).exists(), isTrue);
        }
        await tester.ensureVisible(find.text('Refresh versions'));
        await tester.tap(find.text('Refresh versions'));
        await until(
          tester,
          () => find.byType(StatusProgress).evaluate().isEmpty,
        );
        expect(find.text('Install selected version'), findsOneWidget);
        expect(find.text('Launch selected version'), findsNothing);
        await capture(key, 'race-uninstalled');
        await tester.ensureVisible(find.text('Install selected version'));
        await tester.tap(find.text('Install selected version'));
        await until(
          tester,
          () => find.byType(StatusProgress).evaluate().isEmpty,
        );
        expect(await File(removedExe).exists(), isTrue);
        current =
            jsonDecode(state.prefs.getString('race-managed-installations')!)
                as Map;
        expect(current.keys.toSet(), ids.toSet());
        expect(find.text('Launch selected version'), findsOneWidget);
        expect(
          await project.readAsString(),
          'Keep this project through uninstall/reinstall',
        );
        for (final file in olderProjects) {
          expect(
            await file.readAsString(),
            startsWith('Older version project:'),
          );
        }
        await capture(key, 'race-reinstalled');
      }
      await capture(key, 'race-demo-versions-installed');
      await File('${paths.directory.path}/qa-receipt.json').writeAsString(
        jsonEncode({
          'builds': ids,
          'installationAndWindowLaunch': true,
          'uninstallCancelRunningRefusalAndReinstall':
              const bool.fromEnvironment('RYHZE_QA_UNINSTALL'),
          'projectSentinelsPreserved': const bool.fromEnvironment(
            'RYHZE_QA_UNINSTALL',
          ),
        }),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
