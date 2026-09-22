import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/linux_games.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Linux roots include native Steam, XDG data and Flatpak', () {
    expect(
      LinuxGames.steamRoots({'HOME': '/home/deck', 'XDG_DATA_HOME': '/data'}),
      [
        '/home/deck/.steam/steam',
        '/home/deck/.steam/root',
        '/data/Steam',
        '/home/deck/.var/app/com.valvesoftware.Steam/.local/share/Steam',
      ],
    );
    expect(LinuxGames.steamRoots({}), isEmpty);
  });

  test(
    'Linux paths remain case sensitive and respect directory boundaries',
    () {
      expect(gamePath('/Games/Portal'), '/Games/Portal');
      expect(insideGame('/Games/Portal/game', '/Games/Portal'), isTrue);
      expect(insideGame('/Games/portal/game', '/Games/Portal'), isFalse);
      expect(insideGame('/Games/Portal2/game', '/Games/Portal'), isFalse);
      expect(insideGame('/Games/Portal/game', ''), isFalse);
      expect(gamePath(r'C:\Games\PORTAL'), r'c:\games\portal');
    },
  );

  test(
    'Steam identity detects Proton game processes outside the native root',
    () {
      final game = LocalGame(
        id: 'steam:620',
        name: 'Portal 2',
        source: 'Steam',
        root: '/Games/Portal 2',
        storeId: '620',
      );
      expect(game.matches({'path': '/usr/bin/wine', 'steamId': '620'}), isTrue);
      expect(
        game.matches({'path': '/usr/bin/wine', 'steamId': '999'}),
        isFalse,
      );
    },
  );

  test(
    'Steam discovers an external library and excludes Proton runtimes',
    () async {
      final temp = await Directory.systemTemp.createTemp('ryhze-deck-test-');
      addTearDown(() => temp.delete(recursive: true));
      final main = Directory('${temp.path}/Steam/steamapps');
      final sd = Directory('${temp.path}/Micro SD/steamapps');
      await main.create(recursive: true);
      await Directory('${sd.path}/common/Portal 2').create(recursive: true);
      await Directory('${sd.path}/common/Proton').create(recursive: true);
      final external = sd.parent.path.replaceAll(r'\', '/');
      await File(
        '${main.path}/libraryfolders.vdf',
      ).writeAsString('"libraryfolders" { "1" { "path" "$external" } }');
      await File('${sd.path}/appmanifest_620.acf').writeAsString(
        '"AppState" { "appid" "620" "name" "Portal 2" "installdir" "Portal 2" }',
      );
      await File('${sd.path}/appmanifest_100.acf').writeAsString(
        '"AppState" { "appid" "100" "name" "Proton 9" "installdir" "Proton" }',
      );
      final games = await GameDiscovery.scan([
        main.parent.path,
      ], '${temp.path}/no-epic');
      expect(games.map((g) => g.name), ['Portal 2']);
      expect(games.single.launch, 'steam://rungameid/620');
      SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final library = GameLibrary(
        await SharedPreferences.getInstance(),
        autoPoll: false,
        processReader: () async => [],
      );
      addTearDown(library.dispose);
      expect(GameLibrary.supported, isTrue);
      await library.scan(extraSteamRoot: main.parent.path);
      expect(library.error, isNull);
      expect(library.games.map((g) => g.name), ['Portal 2']);
    },
  );
}
