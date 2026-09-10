import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'game_library.dart';

class GameMedia {
  final String artwork, description, store, source;
  final List<String> screenshots, trailers;
  final List<String> trailerThumbnails;
  const GameMedia({
    this.artwork = '',
    this.description = '',
    this.store = '',
    this.source = '',
    this.screenshots = const [],
    this.trailers = const [],
    this.trailerThumbnails = const [],
  });
  factory GameMedia.fromJson(Map<String, dynamic> j) => GameMedia(
    artwork: j['artwork'] ?? '',
    description: j['description'] ?? '',
    store: j['store'] ?? '',
    source: j['source'] ?? '',
    screenshots: List<String>.from(j['screenshots'] ?? []),
    trailers: List<String>.from(j['trailers'] ?? []),
    trailerThumbnails: List<String>.from(j['trailerThumbnails'] ?? []),
  );
  Map<String, dynamic> toJson() => {
    'artwork': artwork,
    'description': description,
    'store': store,
    'source': source,
    'screenshots': screenshots,
    'trailers': trailers,
    'trailerThumbnails': trailerThumbnails,
  };
}

bool officialGameMedia(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) {
    return false;
  }
  return [
    'steamstatic.com',
    'steamusercontent.com',
    'steamcontent.com',
    'steampowered.com',
    'akamaihd.net',
    'epicgames.com',
  ].any((h) => uri.host == h || uri.host.endsWith('.$h'));
}

GameMedia steamGameMedia(Map<String, dynamic> data, String id) {
  String url(dynamic value) {
    final text = value is String
        ? value.replaceFirst('http://', 'https://')
        : '';
    return officialGameMedia(text) ? text : '';
  }

  final shots = <String>[];
  for (final shot in data['screenshots'] as List? ?? []) {
    final value = url(shot['path_full']);
    if (value.isNotEmpty) shots.add(value);
  }
  final videos = <String>[];
  final thumbnails = <String>[];
  for (final movie in data['movies'] as List? ?? []) {
    final value = url(
      movie['mp4']?['max'] ??
          movie['mp4']?['480'] ??
          movie['webm']?['max'] ??
          movie['hls_h264'],
    );
    if (value.isNotEmpty) {
      videos.add(value);
      thumbnails.add(url(movie['thumbnail']));
    }
  }
  return GameMedia(
    artwork: url(data['header_image']),
    screenshots: shots,
    trailers: videos,
    trailerThumbnails: thumbnails,
    description: (data['short_description'] as String? ?? '')
        .replaceAll(RegExp('<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"'),
    source: 'Steam store',
    store: 'https://store.steampowered.com/app/$id/',
  );
}

class GameMediaStore {
  final SharedPreferences prefs;
  final http.Client client;
  final Map<String, Future<GameMedia>> _requests = {};
  GameMediaStore(this.prefs, {http.Client? client})
    : client = client ?? http.Client();
  Future<GameMedia> load(LocalGame game) =>
      _requests.putIfAbsent('${game.id}:${game.storeId}', () => _load(game));
  void retry(LocalGame game) => _requests.remove('${game.id}:${game.storeId}');
  Future<dynamic> get(Uri uri) async {
    final request = http.Request('GET', uri)..followRedirects = false;
    final response = await client
        .send(request)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Store media is temporarily unavailable.');
    }
    final bytes = await response.stream.toBytes().timeout(
      const Duration(seconds: 12),
    );
    return jsonDecode(utf8.decode(bytes));
  }

  Future<GameMedia> _load(LocalGame game) async {
    if (game.id == 'riot:valorant') {
      return const GameMedia(
        artwork: 'asset:assets/art/valorant.png',
        source: 'Riot Games',
        store: 'https://playvalorant.com/en-us/',
      );
    }
    final key = 'game-media:${game.id}:${game.storeId}';
    GameMedia? cached;
    try {
      final saved =
          jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      if (saved['media'] is Map) {
        cached = GameMedia.fromJson(Map<String, dynamic>.from(saved['media']));
        if (DateTime.now().millisecondsSinceEpoch -
                (saved['time'] as int? ?? 0) <
            const Duration(days: 7).inMilliseconds) {
          return cached;
        }
      }
    } catch (_) {
      /* Refetch corrupt cache. */
    }
    try {
      var id = game.source == 'Epic Games' ? '' : game.storeId;
      // Cross-store media is used only for an exact title match and is attributed to Steam.
      if (id.isEmpty) {
        final search = await get(
          Uri.https('store.steampowered.com', '/api/storesearch/', {
            'term': game.name,
            'l': 'english',
            'cc': 'US',
          }),
        );
        String normalized(String text) =>
            text.toLowerCase().replaceAll(RegExp(r'[\s™®©]'), '');
        final matches = (search['items'] as List? ?? [])
            .where(
              (item) => normalized(item['name'] ?? '') == normalized(game.name),
            )
            .toList();
        if (matches.length == 1) id = matches.single['id'].toString();
      }
      if (RegExp(r'^\d+$').hasMatch(id)) {
        final response = await get(
          Uri.https('store.steampowered.com', '/api/appdetails', {
            'appids': id,
            'l': 'english',
          }),
        );
        if (response[id]?['success'] == true) {
          final media = steamGameMedia(
            Map<String, dynamic>.from(response[id]['data']),
            id,
          );
          await prefs.setString(
            key,
            jsonEncode({
              'time': DateTime.now().millisecondsSinceEpoch,
              'media': media.toJson(),
            }),
          );
          return media;
        }
      }
    } catch (_) {
      if (cached != null) return cached;
    }
    return cached ??
        GameMedia(
          store: game.source == 'Steam' && game.storeId.isNotEmpty
              ? 'https://store.steampowered.com/app/${game.storeId}/'
              : game.source == 'Epic Games'
              ? 'https://store.epicgames.com/en-US/browse?q=${Uri.encodeQueryComponent(game.name)}&sortBy=relevancy&sortDir=DESC&count=40'
              : 'https://store.steampowered.com/search/?term=${Uri.encodeQueryComponent(game.name)}',
        );
  }

  void dispose() => client.close();
}
