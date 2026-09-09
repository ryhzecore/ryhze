import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/state.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('lists, alerts and history are isolated between accounts', () async {
    final state = await fixtureState(user: const Member('alice', 'viewer'));
    await state.toggleSaved(sample);
    await state.toggleAlert(gta);
    await state.progress(
      sample.id,
      '/media/Films/example.mp4',
      const Duration(seconds: 42),
      const Duration(seconds: 120),
    );
    state.user = const Member('bob', 'viewer');
    expect(state.saved, isEmpty);
    expect(state.alerts, isEmpty);
    expect(state.history, isEmpty);
    state.user = const Member('alice', 'viewer');
    expect(state.saved, contains(sample.id));
    expect(state.alerts, contains(gta.id));
    expect(state.history[sample.id]['position'], 42);
    await state.clearHistory();
    expect(state.history, isEmpty);
  });
  test('guests cannot save member-only lists', () async {
    final state = await fixtureState();
    await expectLater(state.toggleSaved(sample), throwsA(isA<ApiException>()));
  });
  test(
    'public catalogue survives temporary network loss with an error notice',
    () async {
      final state = await fixtureState();
      await state.refresh();
      expect(state.error, isNotNull);
      expect(state.titles.map((t) => t.id), contains(sample.id));
      expect(state.loading, false);
    },
  );
  test(
    'expired sessions remove protected titles even when discovery fails',
    () async {
      final state = await fixtureState(user: const Member('alice', 'viewer'));
      state.titles.add(
        const RyhzeTitle(
          id: 'private',
          title: 'Private',
          kind: 'film',
          label: '',
          status: '',
          description: '',
          internal: true,
        ),
      );
      await state.refresh();
      expect(state.user, isNull);
      expect(state.titles.any((t) => t.internal), false);
    },
  );
  test('available-game notice consumes only matching subscriptions', () async {
    SharedPreferences.setMockInitialValues({
      'alerts:guest': ['released', 'later'],
    });
    final api = RyhzeApi(
      store: MemorySession(),
      client: MockClient(
        (r) async => r.url.path == '/api/session'
            ? http.Response('{"error":"Sign in required."}', 401)
            : http.Response(
                jsonEncode([
                  {
                    'id': 'released',
                    'title': 'Released Game',
                    'kind': 'game',
                    'availability': 'available',
                  },
                ]),
                200,
              ),
      ),
    );
    final state = RyhzeState(api, await SharedPreferences.getInstance());
    await state.refresh();
    expect(state.notice, contains('Released Game'));
    expect(state.alerts, {'later'});
  });
  test('search is case insensitive across titles, labels and categories', () {
    expect(sample.matches('RYHZE'), true);
    expect(sample.matches('driving'), true);
    expect(sample.matches('no-match'), false);
  });
}
