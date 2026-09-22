import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/engine_demo.dart';
import 'package:ryhze/ui/engine_versions.dart';
import 'package:ryhze/ui/player.dart';
import 'support.dart';

void main() {
  const id = 'RACE-0.0.3-Windows-20260912-201847-989';
  final metadata = <String, dynamic>{
    'title': 'Captured workflow',
    'description':
        'Editor import and runtime inspection from this released build.',
    'url': '/api/engine/releases/$id/demo',
    'bytes': 1024,
    'sha256': 'a' * 64,
    'mime': 'video/mp4',
  };
  final release = <String, dynamic>{
    'id': id,
    'version': '0.0.3',
    'url': '/api/engine/releases/$id/download',
    'bytes': 22268502,
    'sha256': 'b' * 64,
    'entrypoint': '$id/RACE.exe',
    'notes': 'Build-specific fixes.',
  };
  testWidgets(
    'selected build shows its own notes and matching demo availability',
    (tester) async {
      const older = 'RACE-0.0.3-Windows-20260912-185827-636';
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('ryhze/game_library'),
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          const MethodChannel('ryhze/game_library'),
          null,
        ),
      );
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'schema': 1,
              'releases': [
                {
                  ...release,
                  'demo': {
                    ...metadata,
                    'title': 'RACE 0.0.3 - Captured workflow',
                  },
                },
                {
                  ...release,
                  'id': older,
                  'url': '/api/engine/releases/$older/download',
                  'entrypoint': '$older/RACE.exe',
                  'notes': 'Earlier release-specific changes.',
                },
              ],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EngineVersions(state: state)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Latest release: RACE 0.0.3'), findsOneWidget);
      expect(find.text('V0.1.0 — Unstable'), findsOneWidget);
      expect(
        find.text('Planned release · Not available to download yet.'),
        findsOneWidget,
      );
      final selector = tester.widget<RyhzeDropdown<String>>(
        find.byType(RyhzeDropdown<String>),
      );
      expect(selector.items.first.enabled, isFalse);
      expect(selector.items.first.value, isNull);
      expect(find.text('Selected: RACE 0.0.3 - Not installed'), findsOneWidget);
      expect(find.text('Build-specific fixes.'), findsOneWidget);
      expect(find.text("What's in RACE 0.0.3"), findsOneWidget);
      expect(find.text('Tech demo'), findsOneWidget);
      expect(find.text('RACE 0.0.3 - Captured workflow'), findsNothing);
      expect(find.text(metadata['description'] as String), findsOneWidget);
      expect(find.byType(EngineDemoArtwork), findsOneWidget);
      final dynamic versions = tester.state(find.byType(EngineVersions));
      versions.setState(() {
        versions.message = 'This RACE version is already running.';
      });
      await tester.pump();
      expect(
        find.text('This RACE version is already running.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(RyhzeDropdown<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('V0.0.3 - Live DXR Workspace'));
      await tester.pumpAndSettle();
      expect(find.text('Earlier release-specific changes.'), findsOneWidget);
      expect(find.text('This RACE version is already running.'), findsNothing);
      expect(find.text('Build-specific fixes.'), findsNothing);
      expect(find.text('Choose latest version'), findsOneWidget);
      expect(find.byType(EngineDemoArtwork), findsNothing);
      expect(
        find.text('Tech demo not available for this build yet.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  test(
    'optional demos preserve exact build identity and legacy release compatibility',
    () {
      expect(EngineBuild.fromJson(release).demo, isNull);
      final build = EngineBuild.fromJson({...release, 'demo': metadata});
      expect(build.demo!.url, metadata['url']);
      expect(EngineBuild.fromJson(build.toJson()).demo!.sha256, 'a' * 64);
      expect(build.notes, 'Build-specific fixes.');
    },
  );
  for (final invalid in [
    {'url': 'https://outside.example/demo.mp4'},
    {'url': '/api/engine/releases/another-build/demo'},
    {'bytes': 0},
    {'bytes': 4 * 1024 * 1024 * 1024 + 1},
    {'mime': 'text/html'},
    {'sha256': 'invalid'},
    {'title': ''},
  ]) {
    test('invalid demo is omitted without breaking installation: $invalid', () {
      final build = EngineBuild.fromJson({
        ...release,
        'demo': {...metadata, ...invalid},
      });
      expect(build.demo, isNull);
      expect(build.bytes, 22268502);
    });
  }
  test(
    'demo URLs remain same-origin and limited to protected media routes',
    () async {
      final state = await fixtureState();
      expect(state.api.media(metadata['url']).path, metadata['url']);
      for (final url in [
        'https://outside.example/api/engine/releases/$id/demo',
        '/api/engine/releases/$id/download',
        '/api/admin/users',
      ]) {
        expect(() => state.api.media(url), throwsException);
      }
      state.dispose();
    },
  );
  testWidgets(
    'demo playback is separate from film history and hides when admin mode turns off',
    (tester) async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      await state.prefs.setString(
        'history:Leo',
        jsonEncode({
          'race-demo-$id': {'position': 20, 'duration': 100, 'watched': false},
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: EngineDemoPage(
            state: state,
            buildId: id,
            version: '0.0.3',
            demo: EngineDemo.fromJson(metadata, id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final player = tester.widget<RyhzePlayer>(find.byType(RyhzePlayer));
      expect(player.recordProgress, false);
      expect(player.canPlay!(), true);
      expect(find.text('Continue watching'), findsNothing);
      expect(find.text('Play'), findsOneWidget);
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.byType(RyhzePlayer), findsNothing);
      expect(
        find.text(
          'Sign in with an authorised RACE account to watch this demo.',
        ),
        findsOneWidget,
      );
      expect(state.library.entries, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'switching accounts cannot retain an open demo even when both accounts have RACE access',
    (tester) async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      await tester.pumpWidget(
        MaterialApp(
          home: EngineDemoPage(
            state: state,
            buildId: id,
            version: '0.0.3',
            demo: EngineDemo.fromJson(metadata, id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      state.user = const Member('developer', 'viewer', developerAccess: true);
      await state.preference('test-account-notification', true);
      await tester.pumpAndSettle();
      expect(find.byType(RyhzePlayer), findsNothing);
      expect(find.text('Captured workflow'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
