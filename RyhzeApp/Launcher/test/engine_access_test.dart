import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/pages.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'developer download grants default denied, independent of browsing',
    () async {
      final member = Member.fromJson({
        'username': 'NewDev',
        'role': 'viewer',
        'developerAccess': true,
      });
      final state = await fixtureState(user: member);
      expect(state.engineAccess, isTrue);
      expect(state.engineDownloadAccess, isFalse);
      state.user = Member.fromJson({
        'username': 'NewDev',
        'role': 'viewer',
        'developerAccess': true,
        'engineDownloadAccess': true,
      });
      expect(state.engineDownloadAccess, isTrue);
      state.dispose();
    },
  );

  test(
    'admins retain grants; normal view still hides admin engine access',
    () async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      expect(state.engineDownloadAccess, isTrue);
      await state.setAdminAccess(false);
      expect(state.engineDownloadAccess, isFalse);
      state.dispose();
    },
  );

  test(
    'fresh install authorization detects pause after an earlier grant',
    () async {
      bool granted = true;
      int checks = 0;
      final state = await fixtureState(
        user: const Member(
          'Dev',
          'viewer',
          developerAccess: true,
          engineDownloadAccess: true,
        ),
        client: MockClient((request) async {
          expect(request.url.path, '/api/session');
          checks++;
          return http.Response(
            jsonEncode({
              'user': {
                'username': 'Dev',
                'role': 'viewer',
                'developerAccess': true,
                'engineDownloadAccess': granted,
              },
            }),
            200,
          );
        }),
      );
      await state.authorizeEngineInstall();
      granted = false;
      await expectLater(
        state.authorizeEngineInstall(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      expect(checks, 2);
      expect(state.engineAccess, isTrue);
      expect(state.engineDownloadAccess, isFalse);
      state.dispose();
    },
  );

  test(
    'session failure and account mismatch cannot authorize installation',
    () async {
      final state = await fixtureState(
        user: const Member(
          'Dev',
          'viewer',
          developerAccess: true,
          engineDownloadAccess: true,
        ),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'user': {
                'username': 'AnotherDev',
                'role': 'viewer',
                'developerAccess': true,
                'engineDownloadAccess': true,
              },
            }),
            200,
          ),
        ),
      );
      await expectLater(
        state.authorizeEngineInstall(),
        throwsA(isA<ApiException>()),
      );
      expect(state.user!.username, 'Dev');
      state.dispose();
    },
  );

  testWidgets(
    'Manage Members allows and pauses engine grants with admin view gating',
    (tester) async {
      bool granted = false;
      final mutations = <bool>[];
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: MockClient((request) async {
          if (request.url.path == '/api/admin/engine-access') {
            final body = jsonDecode(request.body);
            expectSync(body['id'], 'dev-id');
            granted = body['allowed'] as bool;
            mutations.add(granted);
            return http.Response(
              jsonEncode({
                'ok': true,
                'id': 'dev-id',
                'engineDownloadAccess': granted,
              }),
              200,
            );
          }
          expectSync(request.url.path, '/api/admin/users');
          return http.Response(
            jsonEncode([
              {
                'id': 'admin',
                'username': 'Leo',
                'role': 'admin',
                'disabled': 0,
                'developerAccess': 1,
                'engineDownloadAccess': true,
              },
              {
                'id': 'dev-id',
                'username': 'Dev',
                'role': 'viewer',
                'disabled': 0,
                'developerAccess': 1,
                'engineDownloadAccess': granted,
              },
            ]),
            200,
          );
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(
            body: SingleChildScrollView(child: AdminPage(state: state)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Allow engine access'), findsOneWidget);
      final allow = tester.widget<Pill>(
        find.widgetWithText(Pill, 'Allow engine access'),
      );
      allow.onPressed!();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(
        find.text('Pause engine access'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '),
      );
      tester
          .widget<Pill>(find.widgetWithText(Pill, 'Pause engine access'))
          .onPressed!();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(mutations, [true, false]);
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.text('Allow engine access'), findsNothing);
      expect(find.text('Administrator access required.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
