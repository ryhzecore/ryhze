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
Future<RyhzeState> fixtureState({Member? user}) async {
  SharedPreferences.setMockInitialValues({});
  final state = RyhzeState(
    RyhzeApi(
      client: MockClient(
        (r) async =>
            http.Response(jsonEncode({'error': 'Sign in required.'}), 401),
      ),
      store: MemorySession(),
    ),
    await SharedPreferences.getInstance(),
  );
  state.user = user;
  state.titles = [sample, gta];
  state.loading = false;
  return state;
}
