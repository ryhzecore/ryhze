import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'duplicate launcher entries share one card and prefer the running game',
    () async {
      SharedPreferences.setMockInitialValues({});
      final library = GameLibrary(
        await SharedPreferences.getInstance(),
        autoPoll: false,
      );
      addTearDown(library.dispose);
      final steam = LocalGame(
        id: 'steam-1',
        name: 'Same Game',
        source: 'Steam',
        root: r'D:\Steam\Game',
        storeId: '123',
      );
      final epic = LocalGame(
        id: 'epic-1',
        name: 'Same Game',
        source: 'Epic Games',
        root: r'E:\Epic\Game',
        lastPlayed: DateTime(2026),
      );
      final sequel = LocalGame(
        id: 'steam-2',
        name: 'Same Game 2',
        source: 'Steam',
        root: r'D:\Steam\Game2',
        storeId: '456',
      );
      library.games = [steam, epic, sequel];
      expect(library.sorted.map((g) => g.id), ['epic-1', 'steam-2']);
      library.running = {
        'steam-1': [
          {'pid': 1},
        ],
      };
      expect(library.sorted.first.id, 'steam-1');
      expect(library.games.length, 3);
      library.games.add(
        LocalGame(
          id: 'epic-other',
          name: 'Another Game',
          source: 'Epic Games',
          root: r'E:\Epic\Another',
          storeId: '123',
          namespace: 'another',
        ),
      );
      expect(library.sorted.any((game) => game.id == 'epic-other'), true);
      expect(gameNameKey('SAME GAME\u2122'), gameNameKey('Same Game'));
    },
  );
  test(
    'Riot discovers Valorant on another drive and normalizes doubled separators',
    () async {
      final temp = await Directory.systemTemp.createTemp('ryhze-riot-test-');
      addTearDown(() => temp.delete(recursive: true));
      final root = '${temp.path}/Other drive/VALORANT/live/';
      final executable = File(
        '$root/ShooterGame/Binaries/Win64/VALORANT-Win64-Shipping.exe',
      );
      await executable.parent.create(recursive: true);
      await executable.writeAsBytes([0]);
      final manifest = File('${temp.path}/Riot Games/RiotClientInstalls.json');
      await manifest.parent.create();
      await manifest.writeAsString(
        jsonEncode({
          'associated_client': {root: 'client.exe'},
        }),
      );
      final games = await GameDiscovery.riot(temp.path);
      expect(games.single.launch, 'riot:valorant');
      expect(
        games.single.matches({
          'path': executable.path.replaceAll('//', '/'),
          'window': true,
        }),
        true,
      );
      expect(gamePath(r'\\server\games\\Game.exe'), r'\\server\games\game.exe');
    },
  );
  test(
    'discovers every configured Steam drive and Epic manifest without duplicate or incomplete games',
    () async {
      final temp = await Directory.systemTemp.createTemp('ryhze-library-test-');
      addTearDown(() => temp.delete(recursive: true));
      final first = '${temp.path}/Steam',
          second = '${temp.path}/Other drive/SteamLibrary';
      await Directory('$first/steamapps/common/One').create(recursive: true);
      await Directory('$second/steamapps/common/Two').create(recursive: true);
      String vdfPath(String s) => s.replaceAll(r'\', r'\\');
      await File('$first/steamapps/libraryfolders.vdf').writeAsString(
        '"libraryfolders" { "0" { "path" "${vdfPath(first)}" } "1" { "path" "${vdfPath(second)}" } }',
      );
      await File('$first/steamapps/appmanifest_10.acf').writeAsString(
        '"AppState" { "appid" "10" "name" "Game One" "installdir" "One" }',
      );
      await File('$second/steamapps/appmanifest_20.acf').writeAsString(
        '"AppState" { "appid" "20" "name" "Game Two" "installdir" "Two" }',
      );
      await File('$second/steamapps/appmanifest_30.acf').writeAsString(
        '"AppState" { "appid" "30" "name" "Escape" "installdir" ".." }',
      );
      final epic = await Directory('${temp.path}/Epic manifests').create();
      final epicGame = await Directory(
        '${temp.path}/Another drive/Epic Game',
      ).create(recursive: true);
      final manifest = {
        'AppName': 'abc',
        'DisplayName': 'Epic Game',
        'InstallLocation': epicGame.path,
        'LaunchExecutable': 'Game.exe',
        'CatalogItemId': 'item',
        'CatalogNamespace': 'space',
      };
      await File('${epic.path}/abc.item').writeAsString(jsonEncode(manifest));
      await File('${epic.path}/bad.item').writeAsString('{broken');
      await File('${epic.path}/partial.item').writeAsString(
        jsonEncode({
          ...manifest,
          'AppName': 'partial',
          'bIsIncompleteInstall': true,
        }),
      );
      final games = await GameDiscovery.scan([first, second, first], epic.path);
      expect(
        games.map((g) => g.name),
        unorderedEquals(['Game One', 'Game Two', 'Epic Game']),
      );
      expect(
        games.firstWhere((g) => g.id == 'steam:20').root,
        contains('Other drive'),
      );
      expect(
        games.firstWhere((g) => g.id == 'epic:abc').launch,
        'com.epicgames.launcher://apps/abc?action=launch&silent=true',
      );
    },
  );
  test(
    'matches full game paths and windows, never similarly named directories or shared launcher',
    () {
      final g = LocalGame(
        id: 'steam:1',
        name: 'Game',
        source: 'Steam',
        root: r'D:\Games\Game',
      );
      expect(
        g.matches({'path': r'd:\games\game\bin\game.exe', 'window': true}),
        true,
      );
      expect(
        g.matches({'path': r'D:\Games\Game Two\game.exe', 'window': true}),
        false,
      );
      expect(
        g.matches({'path': r'D:\Games\Game\crashreporter.exe', 'window': true}),
        false,
      );
      expect(
        g.matches({'path': r'D:\Games\Game\background.exe', 'window': false}),
        false,
      );
      expect(
        g.matches({
          'path': r'C:\Program Files\Steam\steam.exe',
          'window': true,
        }),
        false,
      );
    },
  );
  test(
    'permission gates polling; actual activity persists last-played and restores after reopening',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      int calls = 0;
      List<Map<String, dynamic>> processes = [];
      final library = GameLibrary(
        prefs,
        autoPoll: false,
        processReader: () async {
          calls++;
          return processes;
        },
      );
      addTearDown(library.dispose);
      final game = LocalGame(
        id: '1',
        name: 'Game',
        source: 'Manual',
        root: r'D:\Games',
        executable: r'D:\Games\Game.exe',
      );
      library.games = [game];
      await library.refresh();
      expect(calls, 0);
      await library.allow(true);
      await library.refresh();
      expect(game.lastPlayed, isNull);
      processes = [
        {
          'pid': 123,
          'birth': '123',
          'path': r'D:\Games\Game.exe',
          'window': true,
        },
      ];
      await library.refresh();
      expect(library.isRunning(game), true);
      expect(game.lastPlayed, isNotNull);
      final saved = game.lastPlayed;
      await library.refresh();
      expect(game.lastPlayed, saved);
      final reopened = GameLibrary(prefs, autoPoll: false);
      expect(reopened.games.single.lastPlayed, saved);
      reopened.dispose();
      processes = [];
      await library.refresh();
      expect(library.isRunning(game), false);
      await library.allow(false);
      final previous = calls;
      await library.refresh();
      expect(calls, previous);
    },
  );
  test('revoking permission discards an in-flight process snapshot', () async {
    SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
    final prefs = await SharedPreferences.getInstance();
    final pending = Completer<List<Map<String, dynamic>>>();
    final library = GameLibrary(
      prefs,
      autoPoll: false,
      processReader: () => pending.future,
    );
    addTearDown(library.dispose);
    final game = LocalGame(
      id: '1',
      name: 'Game',
      source: 'Manual',
      root: r'D:\Games',
      executable: r'D:\Games\Game.exe',
    );
    library.games = [game];
    final poll = library.refresh();
    await library.allow(false);
    pending.complete([
      {'pid': 1, 'birth': 'a', 'path': game.executable, 'window': true},
    ]);
    await poll;
    expect(library.running, isEmpty);
    expect(game.lastPlayed, isNull);
  });
  test('missing executable and shared launchers cannot be added', () async {
    SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
    final library = GameLibrary(
      await SharedPreferences.getInstance(),
      autoPoll: false,
    );
    addTearDown(library.dispose);
    await expectLater(
      library.addManual('Missing', r'D:\nonexistent\game.exe'),
      throwsStateError,
    );
    await expectLater(
      library.addManual('Steam', r'C:\Steam\steam.exe'),
      throwsStateError,
    );
  });
  test(
    'native control uses the complete identity and visible game window',
    () async {
      SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
      final library = GameLibrary(
        await SharedPreferences.getInstance(),
        autoPoll: false,
      );
      addTearDown(library.dispose);
      final game = LocalGame(
        id: '1',
        name: 'Game',
        source: 'Steam',
        root: r'D:\Game',
      );
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(GameLibrary.channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(GameLibrary.channel, null),
      );
      library.running[game.id] = [
        {'pid': 1, 'path': r'D:\Game\main.exe', 'birth': 'abc', 'window': true},
      ];
      await library.control(game, 'resume');
      expect(calls.single.method, 'resume');
      expect(calls.single.arguments['birth'], 'abc');
    },
  );
  test(
    'official gallery includes all screenshots and trailers, rejects arbitrary media hosts',
    () {
      final media = steamGameMedia({
        'header_image': 'https://cdn.akamai.steamstatic.com/a.jpg',
        'screenshots': [
          {'path_full': 'https://shared.steamstatic.com/1.jpg'},
          {'path_full': 'https://shared.steamstatic.com/2.jpg'},
          {'path_full': 'https://evil.invalid/x.jpg'},
        ],
        'movies': [
          {
            'mp4': {'max': 'http://video.akamai.steamstatic.com/trailer.mp4'},
          },
        ],
      }, '10');
      expect(media.screenshots, hasLength(2));
      expect(media.trailers.single, startsWith('https://'));
      expect(media.store, 'https://store.steampowered.com/app/10/');
      expect(
        officialGameMedia('https://steamstatic.com.evil.invalid/a.jpg'),
        false,
      );
    },
  );
  test(
    'media uses exact title matching and cached official data survives offline',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final game = LocalGame(
        id: 'epic:1',
        name: 'A Game',
        source: 'Epic Games',
        root: r'D:\Game',
      );
      final store = GameMediaStore(
        prefs,
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              request.url.path.contains('storesearch')
                  ? {
                      'items': [
                        {'id': 10, 'name': 'A Game'},
                      ],
                    }
                  : {
                      '10': {
                        'success': true,
                        'data': {
                          'header_image':
                              'https://shared.steamstatic.com/game.jpg',
                          'screenshots': [],
                          'movies': [],
                        },
                      },
                    },
            ),
            200,
          ),
        ),
      );
      addTearDown(store.dispose);
      expect((await store.load(game)).artwork, isNotEmpty);
      final offline = GameMediaStore(
        prefs,
        client: MockClient((_) async => throw const SocketException('Offline')),
      );
      addTearDown(offline.dispose);
      expect((await offline.load(game)).artwork, isNotEmpty);
    },
  );
  test(
    'different non-Latin titles never borrow each other’s artwork',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = GameMediaStore(
        await SharedPreferences.getInstance(),
        client: MockClient((request) async {
          expect(request.url.path, '/api/storesearch/');
          return http.Response(
            jsonEncode({
              'items': [
                {'id': 123, 'name': '另一款游戏'},
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(store.dispose);
      final media = await store.load(
        LocalGame(
          id: 'manual:unicode',
          name: '我的游戏',
          source: 'Manual',
          root: r'D:\Games',
        ),
      );
      expect(media.artwork, isEmpty);
    },
  );
}
