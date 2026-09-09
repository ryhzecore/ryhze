import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

class RyhzeState extends ChangeNotifier {
  final RyhzeApi api;
  final SharedPreferences prefs;
  Member? user;
  List<RyhzeTitle> titles = [];
  bool loading = true;
  String? error, notice;
  int _sequence = 0;
  RyhzeState(this.api, this.prefs);
  bool get reduced => prefs.getBool('reduced-motion') ?? false;
  bool get sound => prefs.getBool('ambient-sound') ?? true;
  String get scope => user?.username ?? 'guest';
  Set<String> get saved => (prefs.getStringList('saved:$scope') ?? []).toSet();
  Set<String> get alerts =>
      (prefs.getStringList('alerts:$scope') ?? []).toSet();
  Map<String, dynamic> get history {
    try {
      return jsonDecode(prefs.getString('history:$scope') ?? '{}');
    } catch (_) {
      return {};
    }
  }

  Future<void> initialize() async {
    await api.connect();
    try {
      await api.restore();
    } catch (_) {
      error = 'Secure storage is unavailable. Sign in again to continue.';
    }
    await refresh();
  }

  Future<void> refresh() async {
    final sequence = ++_sequence;
    loading = true;
    error = null;
    notifyListeners();
    try {
      Member? member;
      try {
        final data = await api.request('/api/session');
        member = Member.fromJson(data['user']);
      } on ApiException catch (e) {
        if (e.status != 401) rethrow;
      }
      if (sequence != _sequence) return;
      user = member;
      // Never retain a previous account's protected catalogue after expiry.
      titles = titles.where((t) => !t.internal).toList();
      final data = await api.request(
        member == null ? '/api/discover' : '/api/catalog',
      );
      if (sequence != _sequence) return;
      titles = (data as List).map((t) => RyhzeTitle.fromJson(t)).toList();
      final released = titles
          .where((t) => alerts.contains(t.id) && t.availability == 'available')
          .toList();
      if (released.isNotEmpty) {
        notice =
            '${released.map((t) => t.title).join(', ')} is now available on Ryhze.';
        await prefs.setStringList(
          'alerts:$scope',
          alerts.difference(released.map((t) => t.id).toSet()).toList(),
        );
      }
    } catch (e) {
      if (sequence != _sequence) return;
      error = e is ApiException
          ? e.message
          : 'Unable to load Ryhze. Please try again.';
      if (titles.isEmpty) {
        final data =
            jsonDecode(await rootBundle.loadString('assets/catalog.json'))
                as List;
        titles = data.map((t) => RyhzeTitle.fromJson(t)).toList();
      }
    } finally {
      if (sequence == _sequence) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> login(String username, String password, bool remember) async {
    final data = await api.request(
      '/api/login',
      body: {
        'username': username.trim(),
        'password': password,
        'remember': remember,
      },
      remember: remember,
    );
    user = Member.fromJson(data['user']);
    titles = [];
    await refresh();
    if (user == null) {
      throw const ApiException(
        'Your session could not be confirmed. Please sign in again.',
      );
    }
  }

  Future<void> logout() async {
    await api.request('/api/logout', body: {});
    await api.forget();
    user = null;
    titles = [];
    await refresh();
  }

  Future<void> toggleSaved(RyhzeTitle title) async {
    if (user == null) {
      throw const ApiException('Sign in to keep your favourites in My List.');
    }
    final next = saved;
    next.contains(title.id) ? next.remove(title.id) : next.add(title.id);
    if (!await prefs.setStringList('saved:$scope', next.toList())) {
      throw const ApiException('Your list could not be saved.');
    }
    notifyListeners();
  }

  Future<void> toggleAlert(RyhzeTitle title) async {
    final next = alerts;
    next.contains(title.id) ? next.remove(title.id) : next.add(title.id);
    if (!await prefs.setStringList('alerts:$scope', next.toList())) {
      throw const ApiException('Your notification could not be saved.');
    }
    notifyListeners();
  }

  Future<void> preference(String key, bool value) async {
    if (!await prefs.setBool(key, value)) {
      throw const ApiException('Your preference could not be saved.');
    }
    notifyListeners();
  }

  Future<void> progress(
    String id,
    String stream,
    Duration position,
    Duration duration,
  ) async {
    if (user == null || duration.inSeconds == 0) return;
    final next = history;
    next[id] = {
      'stream': stream,
      'position': position.inSeconds,
      'duration': duration.inSeconds,
      'updated': DateTime.now().toIso8601String(),
    };
    await prefs.setString('history:$scope', jsonEncode(next));
  }

  Future<void> clearHistory() async {
    await prefs.remove('history:$scope');
    notifyListeners();
  }
}
