import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/state.dart';

class MemorySession implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

const sample = RyhzeTitle(
  id: 'larcenous-driftscape',
  title: 'Larcenous Driftscape',
  kind: 'game',
  label: 'Ryhze Games',
  status: 'In development',
  description:
      'An open-world crime and driving game set across San Coronado. From the working docks of Oakhaven to the mountain roads of Cascadia, every route is another way into the story.',
  image: '/art/san-coronado.png',
  imageNote: 'World concept artwork · Not gameplay',
  categories: ['Open world', 'Driving', 'Crime'],
);
const gta = RyhzeTitle(
  id: 'internal-grand-theft-auto-vi',
  title: 'Grand Theft Auto VI',
  kind: 'game',
  label: 'Rockstar Games',
  status: 'Coming 19 November 2026',
  description: 'A new chapter in Leonida.',
  image: '/art/gta-vi.png',
  availability: 'coming-soon',
);
Future<RyhzeState> fixtureState({Member? user, http.Client? client, bool adminAccess = true, bool featuredMotion = false}) async {
  SharedPreferences.setMockInitialValues({});
  final entries = <String, dynamic>{};
  var revision = 0;
  final state = RyhzeState(
    RyhzeApi(
      client:
          client ??
          MockClient(
            (r) async {
              if (r.url.path == '/api/library' && user != null) {
                if (r.method == 'POST') {
                  revision++;
                  for (final op in jsonDecode(r.body)['operations']) { entries[op['key']] = {'value': op['value'], 'revision': revision, 'added': 1}; }
                }
                return http.Response(jsonEncode({'schema': 1, 'revision': revision, 'entries': entries}), 200);
              }
              return http.Response(jsonEncode({'error': 'Sign in required.'}), 401);
            },
          ),
      store: MemorySession(),
    ),
    await SharedPreferences.getInstance(),
    libraryAutoSync: false,
    featuredMotion: featuredMotion,
  );
  state.user = user;
  if (adminAccess && user?.role == 'admin') await state.setAdminAccess(true);
  state.titles = [sample, gta];
  state.loading = false;
  return state;
}
