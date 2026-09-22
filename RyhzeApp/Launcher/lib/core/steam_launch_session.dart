import 'package:flutter/services.dart';

/// Tracks only games launched here. A brief missing-process sample can be a
/// launcher handing over to the game, so require a second, later observation.
class SteamLaunchSessions {
  final MethodChannel channel;
  final DateTime Function() now;
  final _sessions = <String, _Session>{};
  SteamLaunchSessions(this.channel, {DateTime Function()? clock})
    : now = clock ?? DateTime.now;

  static String? appId(String uri) =>
      RegExp(r'^steam://rungameid/([1-9][0-9]*)$').firstMatch(uri)?.group(1);

  Future<void> launch(String gameId, String uri) async {
    final id = appId(uri);
    if (id == null) throw ArgumentError('Invalid Steam game link');
    await channel.invokeMethod<void>('launchSteam', {'appId': id});
    _sessions[gameId] = _Session(id, now());
  }

  Future<void> refresh(Set<String> running) async {
    for (final entry in _sessions.entries.toList()) {
      if (!identical(_sessions[entry.key], entry.value)) continue;
      final session = entry.value;
      final active = running.contains(entry.key);
      final time = now();
      if (active) {
        session.seen = true;
        session.missingSince = null;
      } else if (session.seen) {
        session.missingSince ??= time;
      }
      final finished =
          session.seen &&
          !active &&
          time.difference(session.missingSince!) >= const Duration(seconds: 3);
      if (!session.seen &&
          time.difference(session.started) >= const Duration(seconds: 90)) {
        await cancel(entry.key);
        continue;
      }
      try {
        await channel.invokeMethod<void>('updateSteamSession', {
          'appId': session.appId,
          'running': active,
          'finished': finished,
        });
      } on PlatformException {
        await cancel(entry.key);
        continue;
      }
      if (finished) _sessions.remove(entry.key);
    }
  }

  Future<void> cancel(String gameId) async {
    final session = _sessions.remove(gameId);
    if (session == null) return;
    try {
      await channel.invokeMethod<void>('cancelSteamSession', {
        'appId': session.appId,
      });
    } on PlatformException {
      // Native sessions also expire when heartbeats stop.
    } on MissingPluginException {
      // Teardown may already have destroyed the native window.
    }
  }

  Future<void> cancelAll() async {
    for (final id in _sessions.keys.toList()) {
      await cancel(id);
    }
  }
}

class _Session {
  final String appId;
  final DateTime started;
  bool seen = false;
  DateTime? missingSince;
  _Session(this.appId, this.started);
}
