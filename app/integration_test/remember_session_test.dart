import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/state.dart';

// Run seed and restore as separate native app processes. This key is isolated
// from the member's real session; all account responses are local fixtures.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final previousPolicy = binding.framePolicy;
    binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
    try {
      runApp(const SizedBox.shrink());
      await binding.waitUntilFirstFrameRasterized.timeout(
        const Duration(seconds: 30),
      );
      await binding.endOfFrame.timeout(const Duration(seconds: 30));
    } finally {
      binding.framePolicy = previousPolicy;
    }
  });
  const phase = String.fromEnvironment('RYHZE_SESSION_PHASE');
  testWidgets('remembered session across native process restart: $phase', (
    tester,
  ) async {
    // iOS must render a first frame before the native test runner attaches.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(['seed', 'restore'], contains(phase));
    final store = SecureSessionStore(key: 'ryhze-qa-session-restart-v1');
    final token = 'd' * 64;
    var loggedOut = false;
    RyhzeApi makeApi() => RyhzeApi(
      origin: Uri.parse(
        phase == 'seed'
            ? 'https://ryhze-web.live-insights.workers.dev'
            : 'https://ryhze.com',
      ),
      store: store,
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/api/health':
            expect(request.headers['Cookie'], isNull);
            return http.Response('{"ok":true,"media":"Cloudflare R2"}', 200);
          case '/api/login':
            expect(jsonDecode(request.body)['remember'], true);
            return http.Response(
              '{"user":{"username":"restart-fixture","role":"viewer"}}',
              200,
              headers: {
                'set-cookie':
                    '__Host-ryhze_session=$token; Path=/; Secure; HttpOnly; Max-Age=2592000',
              },
            );
          case '/api/session':
            if (loggedOut) {
              expect(request.headers['Cookie'], isNull);
              return http.Response('{"error":"Sign in required."}', 401);
            }
            expect(request.headers['Cookie'], '__Host-ryhze_session=$token');
            return http.Response(
              '{"user":{"username":"restart-fixture","role":"viewer"}}',
              200,
            );
          case '/api/logout':
            loggedOut = true;
            return http.Response(
              '{}',
              200,
              headers: {
                'set-cookie': '__Host-ryhze_session=; Path=/; Max-Age=0',
              },
            );
          default:
            return http.Response('[]', 200);
        }
      }),
    );
    final api = makeApi();
    final state = RyhzeState(api, await SharedPreferences.getInstance());
    try {
      if (phase == 'seed') {
        await store.clear();
        await state.login('restart-fixture', 'fixture password', true);
        expect(state.user?.username, 'restart-fixture');
        final saved = await store.read();
        expect(saved, isNotNull);
        expect(saved, isNot(contains('fixture password')));
      } else {
        expect(
          await store.read(),
          isNotNull,
          reason: 'Saved by the earlier app process.',
        );
        await state.initialize();
        expect(state.user?.username, 'restart-fixture');
        expect(state.error, isNull);
        await state.logout();
        expect(await store.read(), isNull);
        final afterLogout = makeApi();
        await afterLogout.restore();
        expect(afterLogout.authHeaders, isEmpty);
        afterLogout.close();
      }
    } finally {
      state.dispose();
      api.close();
      if (phase == 'restore') await store.clear();
    }
  });
}
