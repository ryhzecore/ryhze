import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/race_installation.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'support.dart';
import 'package:ryhze/ui/engine_versions.dart';

Map<String, dynamic> metadata(
  String id, {
  int? buildNumber,
  String? displayVersion,
}) => {
  'id': id,
  'version': '0.0.2',
  'url': '/api/engine/releases/$id/download',
  'sha256': 'a' * 64,
  'bytes': 1,
  'entrypoint': '$id/RACE.exe',
  'buildNumber': ?buildNumber,
  'displayVersion': ?displayVersion,
};
void main() {
  testWidgets(
    'published lower version remains latest without inventing availability',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        raceChannel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          raceChannel,
          null,
        ),
      );
      final next = metadata(
        'RACE-new',
        buildNumber: 2,
        displayVersion: '0.0.2 Build 2',
      );
      final previous = {...metadata('RACE-old'), 'version': '0.1.0'};
      final state = await fixtureState(
        user: const Member('Dev', 'viewer', developerAccess: true),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'schema': 1,
              'releases': [next, previous],
            }),
            200,
          ),
        ),
      );
      addTearDown(state.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: EngineVersions(state: state)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Latest release: RACE 0.0.2 Build 2'), findsOneWidget);
      final menu = tester.widget<RyhzeDropdown<String>>(
        find.byType(RyhzeDropdown<String>),
      );
      expect(menu.items.first.value, 'RACE-new');
      expect(menu.value, 'RACE-new');
      expect(
        find.text('Selected: RACE 0.0.2 Build 2 - Not installed'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'second buildNumber displays exact label while preserving install version and identity',
    () {
      final old = EngineBuild.fromJson(metadata('RACE-old'));
      final next = EngineBuild.fromJson(
        metadata('RACE-new', buildNumber: 2, displayVersion: '0.0.2 Build 2'),
      );
      expect(next.displayLabel, startsWith('V0.0.2 Build 2 - '));
      expect(next.version, '0.0.2');
      expect(next.id, 'RACE-new');
      expect(next.toJson()['buildNumber'], 2);
      expect(
        EngineBuild.fromJson(next.toJson()).displayVersion,
        '0.0.2 Build 2',
      );
      expect(old.buildNumber, isNull);
    },
  );
  for (final bad in [
    metadata('RACE-bad', buildNumber: 2, displayVersion: '0.1.0'),
    metadata('RACE-bad', buildNumber: 0),
    metadata('RACE-bad', displayVersion: '0.0.2 Build 2'),
  ]) {
    test(
      'reject contradictory buildNumber metadata $bad',
      () => expect(() => EngineBuild.fromJson(bad), throwsFormatException),
    );
  }
}
