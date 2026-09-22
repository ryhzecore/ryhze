import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

String libraryId() =>
    '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class LibrarySync extends ChangeNotifier {
  final RyhzeApi api;
  final SharedPreferences prefs;
  final bool autoSync;
  String? account;
  Map<String, dynamic> entries = {};
  List<Map<String, dynamic>> pending = [];
  int revision = 0, _generation = 0;
  bool syncing = false, _disposed = false;
  String? error;
  bool sessionExpired = false;
  Timer? _timer;
  LibrarySync(this.api, this.prefs, {this.autoSync = true});
  String get _key => 'library-v2:$account';
  dynamic value(String key) => entries[key]?['value'];
  Future<void> attach(String? username) async {
    if (account == username) return;
    _generation++;
    account = username;
    sessionExpired = false;
    entries = {};
    pending = [];
    revision = 0;
    syncing = false;
    error = null;
    _timer?.cancel();
    if (username != null) {
      try {
        final cache = jsonDecode(prefs.getString(_key) ?? '{}');
        entries = Map<String, dynamic>.from(cache['entries'] ?? {});
        pending = (cache['pending'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        revision = cache['revision'] ?? 0;
        if (entries.isEmpty && prefs.getBool('library-import-v2:$username') != true) {
          for (final id in prefs.getStringList('saved:$username') ?? <String>[]) {
            entries['favorite:$id'] = {'value': true, 'revision': 0, 'added': 0};
          }
          final history = jsonDecode(prefs.getString('history:$username') ?? '{}');
          if (history is Map) {
            for (final entry in history.entries) {
              if (entry.value is Map) entries['progress:${entry.key}'] = {'value': entry.value, 'revision': 0, 'added': 0};
            }
          }
        }
      } catch (_) {
        error = 'Your library cache could not be read. Reconnecting…';
      }
      if (autoSync) {
        _timer = Timer.periodic(
          const Duration(seconds: 20),
          (_) => unawaited(sync()),
        );
      }
      unawaited(sync());
    }
    notifyListeners();
  }

  Future<void> _save() async {
    if (account == null) return;
    if (!await prefs.setString(
      _key,
      jsonEncode({
        'entries': entries,
        'pending': pending,
        'revision': revision,
      }),
    )) {
      throw const ApiException(
        'Your library changes could not be saved on this device.',
      );
    }
  }

  void _overlay() {
    for (final op in pending) {
      final old = entries[op['key']];
      if (old != null &&
          (op['importOnly'] == true || (old['revision'] ?? 0) > op['base'])) {
        continue;
      }
      entries[op['key']] = {
        'value': op['value'],
        'revision': op['base'],
        'added': old?['added'] ?? DateTime.now().millisecondsSinceEpoch,
      };
    }
  }

  Future<void> change(
    String key,
    dynamic value, {
    bool importOnly = false,
  }) async {
    if (account == null) {
      throw const ApiException('Sign in to save your library.');
    }
    final oldEntries = Map<String, dynamic>.from(entries);
    final op = {
      'id': libraryId(),
      'base': revision,
      'key': key,
      'value': value,
      if (importOnly) 'importOnly': true,
    };
    pending.add(op);
    _overlay();
    try {
      await _save();
    } catch (_) {
      pending.remove(op);
      entries = oldEntries;
      rethrow;
    }
    notifyListeners();
    unawaited(sync());
  }

  Future<void> sync() async {
    if (account == null || syncing || _disposed) return;
    final generation = _generation, username = account!;
    syncing = true;
    try {
      var data = await api.request('/api/library');
      if (_disposed || generation != _generation) return;
      revision = data['revision'];
      entries = Map<String, dynamic>.from(data['entries']);
      _overlay();
      // Imports are non-overwriting, including server tombstones.
      if (prefs.getBool('library-import-v2:$username') != true) {
        final keys = pending.map((op) => op['key']).toSet();
        for (final id in prefs.getStringList('saved:$username') ?? <String>[]) {
          final key = 'favorite:$id';
          if (!entries.containsKey(key) && !keys.contains(key)) {
            pending.add({
              'id': libraryId(),
              'base': revision,
              'key': key,
              'value': true,
              'importOnly': true,
            });
          }
        }
        try {
          final history =
              jsonDecode(prefs.getString('history:$username') ?? '{}') as Map;
          for (final entry in history.entries) {
            final key = 'progress:${entry.key}';
            if (!entries.containsKey(key) && !keys.contains(key)) {
              pending.add({
                'id': libraryId(),
                'base': revision,
                'key': key,
                'value': entry.value,
                'importOnly': true,
              });
            }
          }
        } catch (_) {}
        await _save();
        if (_disposed || generation != _generation) return;
        await prefs.setBool('library-import-v2:$username', true);
      }
      if (_disposed || generation != _generation) return;
      for (var batch = 0; pending.isNotEmpty && batch < 20; batch++) {
        final sent = pending.take(50).toList();
        try {
          data = await api.request(
            '/api/library',
            body: {'revision': revision, 'operations': sent},
          );
        } on ApiException catch (e) {
          if (e.status != 409) rethrow;
          data = await api.request('/api/library');
          if (_disposed || generation != _generation) return;
          revision = data['revision'];
          entries = Map<String, dynamic>.from(data['entries']);
          continue;
        }
        if (_disposed || generation != _generation) return;
        final ids = sent.map((op) => op['id']).toSet();
        pending.removeWhere((op) => ids.contains(op['id']));
        revision = data['revision'];
        entries = Map<String, dynamic>.from(data['entries']);
        for (final op in pending) {
          final previous = sent.where((s) => s['key'] == op['key']).lastOrNull;
          final committed = entries[op['key']];
          if (previous != null &&
              committed?['revision'] == revision &&
              jsonEncode(committed?['value']) ==
                  jsonEncode(previous['value'])) {
            op['base'] = revision;
          }
        }
      }
      _overlay();
      await _save();
      error = null;
    } catch (e) {
      if (generation != _generation || _disposed) return;
      if (e is ApiException && e.status == 401) {
        await attach(null);
        sessionExpired = true;
        notifyListeners();
        return;
      }
      error = 'Library sync pending. Check your connection or retry.';
      _overlay();
    } finally {
      if (!_disposed && generation == _generation) {
        syncing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
