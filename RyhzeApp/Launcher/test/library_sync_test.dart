import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/library_sync.dart';
import 'support.dart';

Future<void> settled(LibrarySync sync) async {
  for (var i = 0; i < 100 && sync.syncing; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(sync.syncing, false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'offline edits survive restart and import merges without overwriting tombstones',
    () async {
      SharedPreferences.setMockInitialValues({
        'saved:alice': ['game', 'deleted'],
        'saved:guest': ['guest-only'],
        'history:alice': jsonEncode({
          'film': {'stream': '', 'position': 25, 'duration': 100},
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      var offline = true, revision = 1;
      final entries = <String, dynamic>{
        'favorite:deleted': {'value': null, 'revision': 1, 'added': 1},
      };
      final sent = <Map<String, dynamic>>[];
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient((request) async {
          if (offline) throw Exception('offline');
          if (request.method == 'POST') {
            revision++;
            for (final raw in jsonDecode(request.body)['operations']) {
              final op = Map<String, dynamic>.from(raw);
              sent.add(op);
              if (op['importOnly'] == true && entries.containsKey(op['key'])) {
                continue;
              }
              entries[op['key']] = {
                'value': op['value'],
                'revision': revision,
                'added': 1,
              };
            }
          }
          return http.Response(
            jsonEncode({'schema': 1, 'revision': revision, 'entries': entries}),
            200,
          );
        }),
      );
      var sync = LibrarySync(api, prefs, autoSync: false);
      await sync.attach('alice');
      await settled(sync);
      await sync.change('favorite:offline-game', true);
      await settled(sync);
      expect(sync.pending.length, 1);
      sync.dispose();
      sync = LibrarySync(api, prefs, autoSync: false);
      await sync.attach('alice');
      await settled(sync);
      expect(sync.value('favorite:offline-game'), true);
      offline = false;
      await sync.sync();
      expect(sync.pending, isEmpty);
      expect(sync.value('favorite:deleted'), null);
      expect(sync.value('favorite:game'), true);
      expect(sync.value('progress:film')['position'], 25);
      expect(sent.any((op) => op['key'] == 'favorite:guest-only'), false);
      sync.dispose();
    },
  );
  test(
    'account switch rejects a late response and hides old cached data immediately',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = Completer<http.Response>();
      var requests = 0;
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient((request) async {
          if (++requests == 1) return first.future;
          return http.Response(
            jsonEncode({'schema': 1, 'revision': 0, 'entries': {}}),
            200,
          );
        }),
      );
      final sync = LibrarySync(api, prefs, autoSync: false);
      await sync.attach('alice');
      await sync.attach('bob');
      await settled(sync);
      first.complete(
        http.Response(
          jsonEncode({
            'schema': 1,
            'revision': 1,
            'entries': {
              'favorite:private': {'value': true, 'revision': 1, 'added': 1},
            },
          }),
          200,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(sync.account, 'bob');
      expect(sync.entries, isEmpty);
      await sync.attach(null);
      expect(sync.entries, isEmpty);
      expect(sync.pending, isEmpty);
      sync.dispose();
    },
  );
  test(
    'conflict refresh retains operation identity and original base revision',
    () async {
      SharedPreferences.setMockInitialValues({'library-import-v2:alice': true});
      final prefs = await SharedPreferences.getInstance();
      var revision = 0, conflict = true;
      final writes = <Map<String, dynamic>>[];
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient((request) async {
          if (request.method == 'POST') {
            writes.add(
              Map<String, dynamic>.from(
                jsonDecode(request.body)['operations'][0],
              ),
            );
            if (conflict) {
              conflict = false;
              revision = 1;
              return http.Response('{"error":"conflict"}', 409);
            }
            revision++;
          }
          return http.Response(
            jsonEncode({
              'schema': 1,
              'revision': revision,
              'entries': revision == 0
                  ? {}
                  : {
                      'favorite:game': {
                        'value': null,
                        'revision': 1,
                        'added': 1,
                      },
                    },
            }),
            200,
          );
        }),
      );
      final sync = LibrarySync(api, prefs, autoSync: false);
      await sync.attach('alice');
      await settled(sync);
      await sync.change('favorite:game', true);
      await settled(sync);
      expect(writes.length, 2);
      expect(writes.first['id'], writes.last['id']);
      expect(writes.last['base'], 0);
      expect(sync.value('favorite:game'), null);
      expect(sync.pending, isEmpty);
      sync.dispose();
    },
  );
}
