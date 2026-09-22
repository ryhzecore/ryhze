import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/engine.dart';
import 'package:ryhze/ui/engine_editor.dart';
import 'package:ryhze/ui/engine_support.dart';
import 'package:ryhze/ui/engine_versions.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native engine opening, editing, access removal and uninstall consent',
    (tester) async {
      final release = <String, dynamic>{
        'id': 'RACE-native-fixture',
        'version': '0.0.8',
        'title': 'Game Export',
        'notes': 'Version description',
        'url': '/api/engine/releases/RACE-native-fixture/download',
        'entrypoint': 'RACE-native-fixture/RACE.exe',
        'sha256': 'a' * 64,
        'bytes': 1200,
      };
      final writes = <Map<String, dynamic>>[];
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final body = Map<String, dynamic>.from(jsonDecode(request.body));
            writes.add(body);
            release['title'] = body['title'];
            release['notes'] = body['notes'];
            return http.Response('{"revision":2}', 200);
          }
          return http.Response(
            jsonEncode({
              'schema': 1,
              'revision': 1,
              'releases': [release],
              'thumbnail': {'id': 'fixture', 'url': '/art/valorant.png'},
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
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 360,
                  child: InstalledEngineCard(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await capture(key, 'engine-native-opening');
      await tester.pumpAndSettle();
      expect(find.byType(RaceDetail), findsOneWidget);
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      expect(find.byType(EngineEditor), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField).first);
      await tester.enterText(
        find.byType(TextField).first,
        'Native verified version title',
      );
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(
        find.byType(TextField).last,
        'Edited in the native app.',
      );
      await tester.scrollUntilVisible(
        find.text('Save version'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save version'));
      await tester.pumpAndSettle();
      expect(writes.single['title'], 'Native verified version title');
      await capture(key, 'engine-native-detail');
      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      bool? accepted;
      final prompt = confirmUnsupportedEngineRemoval(
        tester.element(find.byType(InstalledEngineCard)),
        state,
        EngineBuild.fromJson(release),
      ).then((value) => accepted = value);
      await tester.pumpAndSettle();
      expect(accepted, isNull);
      await capture(key, 'engine-native-unsupported');
      await tester.tap(find.text('Proceed with uninstalling'));
      await tester.pumpAndSettle();
      await prompt;
      expect(accepted, isTrue);
      await tester.tap(find.byKey(const ValueKey('card-open-race-engine')));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.text('Administrator access is off.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
