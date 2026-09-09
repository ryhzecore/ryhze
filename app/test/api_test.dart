import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/api.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final token = 'a' * 64;
  test(
    'domain migration fallback probes only Ryhze and sends no credentials',
    () async {
      final visited = <String>[];
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient((r) async {
          visited.add(r.url.host);
          expect(r.headers.containsKey('Cookie'), false);
          expect(r.followRedirects, false);
          return r.url.host == 'ryhze.com'
              ? http.Response('<html>Old host</html>', 404)
              : http.Response('{"ok":true,"media":"Cloudflare R2"}', 200);
        }),
      );
      await api.connect();
      expect(visited, ['ryhze.com', 'ryhze-web.live-insights.workers.dev']);
      expect(api.origin.host, 'ryhze-web.live-insights.workers.dev');
      expect(api.media('/media/Films/test.mp4').host, api.origin.host);
    },
  );
  test('healthy primary service remains the app origin', () async {
    final api = RyhzeApi(
      store: MemorySession(),
      client: MockClient((r) async {
        expect(r.url.host, 'ryhze.com');
        return http.Response('{"ok":true,"media":"Cloudflare R2"}', 200);
      }),
    );
    await api.connect();
    expect(api.origin.host, 'ryhze.com');
  });
  test(
    'catalogue preserves UTF-8 punctuation without a charset header',
    () async {
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient(
          (_) async => http.Response.bytes(
            utf8.encode('{"title":"Ryhze’s première"}'),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      expect((await api.request('/api/discover'))['title'], 'Ryhze’s première');
    },
  );
  test(
    'sign-in uses the existing origin and protects remembered token',
    () async {
      final store = MemorySession();
      final api = RyhzeApi(
        store: store,
        client: MockClient((r) async {
          expect(r.headers['Origin'], 'https://ryhze.com');
          expect(r.followRedirects, false);
          expect(r.headers['Content-Type'], contains('application/json'));
          return http.Response(
            '{"user":{"username":"test","role":"viewer"}}',
            200,
            headers: {
              'set-cookie':
                  '__Host-ryhze_session=$token; Path=/; Secure; HttpOnly',
            },
          );
        }),
      );
      await api.request(
        '/api/login',
        body: {'username': 'test', 'password': 'test'},
        remember: true,
      );
      expect(api.authHeaders['Cookie'], '__Host-ryhze_session=$token');
      expect(jsonDecode(store.value!)['token'], token);
      expect(store.value, isNot(contains('password')));
    },
  );
  test('remembered session survives a new API instance', () async {
    final store = MemorySession()
      ..value = jsonEncode({
        'origin': 'https://ryhze.com',
        'token': token,
        'expires': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
    final api = RyhzeApi(store: store);
    await api.restore();
    expect(api.authHeaders['Cookie'], contains(token));
  });
  test('expired and different-origin sessions are discarded', () async {
    for (final origin in ['https://ryhze.com', 'https://unrelated.example']) {
      final store = MemorySession()
        ..value = jsonEncode({
          'origin': origin,
          'token': token,
          'expires': DateTime.now()
              .subtract(const Duration(days: 1))
              .toIso8601String(),
        });
      final api = RyhzeApi(store: store);
      await api.restore();
      expect(api.authHeaders, isEmpty);
      expect(store.value, isNull);
    }
  });
  test(
    'remembered session survives switching between Ryhze service addresses',
    () async {
      for (final savedOrigin in [
        'https://ryhze.com',
        'https://ryhze-web.live-insights.workers.dev',
      ]) {
        final store = MemorySession()
          ..value = jsonEncode({
            'origin': savedOrigin,
            'token': token,
            'expires': DateTime.now()
                .add(const Duration(days: 1))
                .toIso8601String(),
          });
        final api = RyhzeApi(
          origin: Uri.parse(
            savedOrigin == 'https://ryhze.com'
                ? 'https://ryhze-web.live-insights.workers.dev'
                : 'https://ryhze.com',
          ),
          store: store,
        );
        await api.restore();
        expect(api.authHeaders['Cookie'], '__Host-ryhze_session=$token');
        expect(store.value, isNotNull);
        api.close();
      }
    },
  );
  test('unexpired sessions never cross an unrelated origin', () async {
    for (final origins in [
      ['https://unrelated.example', 'https://ryhze.com'],
      ['https://ryhze.com', 'https://unrelated.example'],
    ]) {
      final store = MemorySession()
        ..value = jsonEncode({
          'origin': origins[0],
          'token': token,
          'expires': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        });
      final api = RyhzeApi(origin: Uri.parse(origins[1]), store: store);
      await api.restore();
      expect(api.authHeaders, isEmpty);
      expect(store.value, isNull);
      api.close();
    }
  });
  test('non-remembered login removes a previous persisted session', () async {
    final store = MemorySession()..value = 'older';
    final api = RyhzeApi(
      store: store,
      client: MockClient(
        (_) async => http.Response(
          '{}',
          200,
          headers: {'set-cookie': '__Host-ryhze_session=$token; Path=/'},
        ),
      ),
    );
    await api.request('/api/login', body: {}, remember: false);
    expect(store.value, isNull);
    expect(api.authHeaders, isNotEmpty);
  });
  test('session expiry clears authentication before another request', () async {
    final store = MemorySession()
      ..value = jsonEncode({
        'origin': 'https://ryhze.com',
        'token': token,
        'expires': DateTime.now()
            .add(const Duration(days: 1))
            .toIso8601String(),
      });
    final api = RyhzeApi(
      store: store,
      client: MockClient(
        (_) async => http.Response('{"error":"Sign in required."}', 401),
      ),
    );
    await api.restore();
    await expectLater(
      api.request('/api/session'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(store.value, isNull);
    expect(api.authHeaders, isEmpty);
  });
  test('media rejects third-party URLs and non-media paths', () {
    final api = RyhzeApi(store: MemorySession());
    for (final path in [
      'https://unrelated.example/media/Films/test.mp4',
      '//unrelated.example/media/Films/test.mp4',
      '/api/session',
      '/media/Films/../../api/session',
      '/media/Films/%5Csecret',
    ]) {
      expect(() => api.media(path), throwsA(isA<ApiException>()), reason: path);
    }
    expect(api.media('/media/Films/A%20Film/test.mp4').host, 'ryhze.com');
  });
  test('network and non-JSON failures become actionable messages', () async {
    final api = RyhzeApi(
      store: MemorySession(),
      client: MockClient(
        (_) async => http.Response('<html>Bad gateway</html>', 502),
      ),
    );
    await expectLater(
      api.request('/api/discover'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          contains('try again'),
        ),
      ),
    );
  });
  test(
    'unencrypted production origin is rejected',
    () => expect(
      () => RyhzeApi(origin: Uri.parse('http://ryhze.com')),
      throwsArgumentError,
    ),
  );
}
