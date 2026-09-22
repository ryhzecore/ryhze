import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine.dart';
import 'package:ryhze/ui/engine_editor.dart';
import 'package:ryhze/ui/engine_versions.dart';
import 'package:ryhze/ui/engine_support.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

final release = <String, dynamic>{
  'id': 'RACE-test',
  'version': '0.0.8',
  'title': 'Game Export',
  'url': '/api/engine/releases/RACE-test/download',
  'entrypoint': 'RACE-test/RACE.exe',
  'bytes': 1234,
  'sha256': 'a' * 64,
  'notes': 'Existing description',
};
void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
  });
  test(
    'version title persists with package identity and unsupported entries are explicitly matched',
    () {
      final build = EngineBuild.fromJson(release);
      expect(build.displayLabel, 'V0.0.8 - Game Export');
      expect(EngineBuild.fromJson(build.toJson()).title, 'Game Export');
      final stored = jsonEncode({
        'RACE-test': {'release': release, 'executable': r'C:\managed\RACE.exe'},
      });
      expect(unsupportedManagedBuilds(stored, ['different-version']), isEmpty);
      expect(
        unsupportedManagedBuilds(stored, ['RACE-test']).single.id,
        'RACE-test',
      );
      expect(unsupportedManagedBuilds('broken JSON', ['RACE-test']), isEmpty);
    },
  );
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'admin edits title and description at $width; access off removes editor',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final writes = <Map<String, dynamic>>[];
        final state = await fixtureState(
          user: const Member('OtherAdmin', 'admin'),
          client: MockClient((request) async {
            if (request.method == 'POST') {
              writes.add(jsonDecode(request.body));
              return http.Response('{"revision":2}', 200);
            }
            return http.Response(
              jsonEncode({
                'revision': 1,
                'releases': [release],
                'thumbnail': null,
              }),
              200,
            );
          }),
        );
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              theme: ryhzeTheme(),
              home: Scaffold(
                body: Builder(
                  builder: (context) => Pill(
                    'Open editor',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            EngineEditor(state: state, selectedId: 'RACE-test'),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        expect(find.text('Game Export'), findsOneWidget);
        await tester.runAsync(
          () => capture(key, 'engine-editor-${width.toInt()}'),
        );
        final fields = find.byType(TextField);
        await tester.enterText(fields.at(0), 'Terrain tools');
        await tester.ensureVisible(fields.last);
        await tester.enterText(fields.last, 'Updated release description');
        await tester.scrollUntilVisible(find.text('Save version'), 200, scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save version'));
        await tester.pumpAndSettle();
        expect(writes.single['title'], 'Terrain tools');
        expect(writes.single['notes'], 'Updated release description');
        expect(writes.single['version'], '0.0.8');
        expect(writes.single['assetId'], null);
        await tester.tap(find.text('Open editor'));
        await tester.pumpAndSettle();
        await state.setAdminAccess(false);
        await tester.pumpAndSettle();
        expect(find.text('Administrator access is off.'), findsOneWidget);
        expect(find.text('Save version'), findsNothing);
        expect(find.byType(TextField), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
  testWidgets(
    'add version exposes package identity fields and delete describes unsupported prompt',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            writes.add(jsonDecode(request.body));
            return http.Response('{"revision":2}', 200);
          }
          return http.Response(
            jsonEncode({
              'revision': 1,
              'releases': [release],
            }),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: EngineEditor(state: state, selectedId: 'RACE-test'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete selected version'));
      await tester.tap(find.text('Delete selected version'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('asked to proceed with uninstalling'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.ensureVisible(find.text('Add version'));
      await tester.tap(find.text('Add version'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Upload packaged ZIP'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Upload packaged ZIP'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Release ID / folder inside ZIP'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(find.text('Save version'), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Save version'));
      await tester.pumpAndSettle();
      expect(writes, isEmpty);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'unsupported prompt requires Proceed and is revoked immediately with admin access',
    (tester) async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      bool? accepted;
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Pill(
                'Check support',
                onPressed: () async {
                  accepted = await confirmUnsupportedEngineRemoval(
                    context,
                    state,
                    EngineBuild.fromJson(release),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Check support'));
      await tester.pumpAndSettle();
      expect(find.text('Old version is no longer supported'), findsOneWidget);
      expect(accepted, isNull);
      await tester.tap(find.text('Proceed with uninstalling'));
      await tester.pumpAndSettle();
      expect(accepted, isTrue);
      accepted = null;
      await tester.tap(find.text('Check support'));
      await tester.pumpAndSettle();
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.text('Proceed with uninstalling'), findsNothing);
      expect(accepted, isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(accepted, isFalse);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'main thumbnail stays independent from version selection and clears on account switch',
    (tester) async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      state.setEngineThumbnail({'id': 'cover', 'url': '/art/valorant.png'});
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 300,
            height: 200,
            child: RaceThumbnail(state: state),
          ),
        ),
      );
      expect(
        tester.widget<TitleArt>(find.byType(TitleArt)).path,
        '/art/valorant.png',
      );
      state.user = const Member('Another', 'viewer', developerAccess: true);
      state.notifyListeners();
      await tester.pump();
      expect(state.engineThumbnail, null);
      expect(find.byType(RaceArtwork), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
