import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int status;
  const ApiException(this.message, [this.status = 0]);
  @override
  String toString() => message;
}

abstract class SessionStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionStore implements SessionStore {
  final FlutterSecureStorage storage = const FlutterSecureStorage();
  final String key;
  SecureSessionStore({this.key = 'ryhze-session-v1'});
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> clear() => storage.delete(key: key);
}

class RyhzeApi {
  // Both addresses serve the same Ryhze account database. Never extend this
  // trust to arbitrary origins or redirects.
  static const _accountOrigins = {
    'https://ryhze.com',
    'https://ryhze-web.live-insights.workers.dev',
  };
  Uri _origin;
  Uri get origin => _origin;
  final http.Client client;
  final SessionStore store;
  String? _token;
  RyhzeApi({Uri? origin, http.Client? client, SessionStore? store})
    : _origin =
          origin ??
          Uri.parse(
            const String.fromEnvironment(
              'RYHZE_API_ORIGIN',
              defaultValue: 'https://ryhze.com',
            ),
          ),
      client = client ?? http.Client(),
      store = store ?? SecureSessionStore() {
    if (this.origin.scheme != 'https' &&
        !['127.0.0.1', 'localhost'].contains(this.origin.host)) {
      throw ArgumentError('Ryhze requires HTTPS.');
    }
  }
  Future<void> connect() async {
    // The legacy host can remain cached during the domain migration. Probe
    // only Ryhze's two known origins, without any authentication headers.
    if (origin.origin != 'https://ryhze.com') return;
    Future<bool> healthy(Uri candidate) async {
      try {
        final req = http.Request('GET', candidate.resolve('/api/health'))
          ..followRedirects = false;
        final response = await http.Response.fromStream(
          await client.send(req).timeout(const Duration(seconds: 8)),
        ).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) return false;
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data is Map &&
            data['ok'] == true &&
            data['media'] == 'Cloudflare R2';
      } catch (_) {
        return false;
      }
    }

    if (await healthy(origin)) return;
    final fallback = Uri.parse('https://ryhze-web.live-insights.workers.dev');
    if (await healthy(fallback)) _origin = fallback;
  }

  Future<void> restore() async {
    final value = await store.read();
    if (value == null) return;
    try {
      final j = jsonDecode(value) as Map<String, dynamic>;
      final sameService =
          j['origin'] == origin.origin ||
          (_accountOrigins.contains(j['origin']) &&
              _accountOrigins.contains(origin.origin));
      if (sameService &&
          DateTime.parse(j['expires']).isAfter(DateTime.now()) &&
          RegExp(r'^[a-f0-9]{64}$').hasMatch(j['token'])) {
        _token = j['token'];
      } else {
        await store.clear();
      }
    } catch (_) {
      await store.clear();
    }
  }

  Map<String, String> get authHeaders => {
    if (_token != null) 'Cookie': '__Host-ryhze_session=$_token',
  };
  Uri resource(String path) {
    final url = origin.resolve(path);
    if (url.origin != origin.origin || url.userInfo.isNotEmpty) {
      throw const ApiException('This resource is outside Ryhze.');
    }
    return url;
  }

  Uri media(String path) {
    final url = resource(path);
    if (!RegExp(r'^/media/(Films|Games)/').hasMatch(url.path) ||
        url.pathSegments.any((p) => p == '..' || p.contains('\\'))) {
      throw const ApiException('This media is not available.');
    }
    return url;
  }

  Future<dynamic> request(
    String path, {
    Map<String, dynamic>? body,
    bool remember = false,
  }) async {
    try {
      final req = http.Request(body == null ? 'GET' : 'POST', resource(path))
        ..followRedirects = false;
      req.headers.addAll({
        ...authHeaders,
        'Accept': 'application/json',
        'Origin': origin.origin,
      });
      if (body != null) {
        req.headers['Content-Type'] = 'application/json';
        req.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
        await client.send(req).timeout(const Duration(seconds: 20)),
      ).timeout(const Duration(seconds: 20));
      dynamic data;
      try {
        data = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        throw const ApiException(
          'Unable to connect to Ryhze. Please try again.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        if (response.statusCode == 401 && path != '/api/login') await forget();
        throw ApiException(
          data is Map
              ? data['error'] ?? 'Please try again.'
              : 'Please try again.',
          response.statusCode,
        );
      }
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null) {
        final token = RegExp(
          r'__Host-ryhze_session=([a-f0-9]{64})(?:;|$)',
        ).firstMatch(setCookie)?.group(1);
        if (token != null) {
          // Clear an older remembered session before a non-remembered login.
          await store.clear();
          _token = token;
          if (remember) {
            await store.write(
              jsonEncode({
                'token': token,
                'origin': origin.origin,
                'expires': DateTime.now()
                    .add(const Duration(days: 30))
                    .toIso8601String(),
              }),
            );
          }
        } else if (setCookie.contains('__Host-ryhze_session=;')) {
          await forget();
        }
      }
      return data;
    } on TimeoutException {
      throw const ApiException(
        'The connection took too long. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        'You’re offline. Check your connection and try again.',
      );
    } on http.ClientException {
      throw const ApiException('Connection interrupted. Please try again.');
    }
  }

  Future<void> forget() async {
    _token = null;
    await store.clear();
  }

  void close() => client.close();
}
