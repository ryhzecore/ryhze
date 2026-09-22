import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/state.dart';

class UnavailableKeyring implements SessionStore {
  int clears = 0;
  @override
  Future<String?> read() async => throw StateError('No secret service');
  @override
  Future<void> write(String value) async =>
      throw StateError('No secret service');
  @override
  Future<void> clear() async {
    clears++;
    throw StateError('No secret service');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('guest discovery loads when the Linux keyring is unavailable', () async {
    SharedPreferences.setMockInitialValues({});
    final store = UnavailableKeyring();
    final visited = <String>[];
    final state = RyhzeState(
      RyhzeApi(
        store: store,
        client: MockClient((r) async {
          visited.add(r.url.path);
          return switch (r.url.path) {
            '/api/health' => http.Response(
              '{"ok":true,"media":"Cloudflare R2"}',
              200,
            ),
            '/api/session' => http.Response(
              '{"error":"Sign in required."}',
              401,
            ),
            '/api/discover' => http.Response(
              '[{"id":"live-game","title":"Live Game","kind":"game"}]',
              200,
            ),
            '/api/catalog/revision' => http.Response('{"revision":1}', 200),
            _ => throw StateError('Unexpected request ${r.url.path}'),
          };
        }),
      ),
      await SharedPreferences.getInstance(),
      libraryAutoSync: false,
    );
    addTearDown(state.dispose);
    await state.initialize();
    expect(visited, contains('/api/discover'));
    expect(state.error, isNull);
    expect(state.titles.single.id, 'live-game');
    expect(state.user, isNull);
    expect(store.clears, 0);
  });
}
