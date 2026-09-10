import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'games.dart';

String gamePath(String path) {
  final value = path
      .replaceAll('/', r'\')
      .replaceAll(RegExp(r'\\+$'), '')
      .toLowerCase();
  final normalized = value.replaceAll(RegExp(r'\\+'), r'\');
  return value.startsWith(r'\\') ? '\\$normalized' : normalized;
}

bool insideGame(String file, String root) =>
    gamePath(file).startsWith('${gamePath(root)}\\');

class LocalGame {
  final String id, name, source, root, executable, launch, storeId, namespace;
  DateTime? lastPlayed;
  LocalGame({
    required this.id,
    required this.name,
    required this.source,
    required this.root,
    this.executable = '',
    this.launch = '',
    this.storeId = '',
    this.namespace = '',
    this.lastPlayed,
  });
  factory LocalGame.fromJson(Map<String, dynamic> j) => LocalGame(
    id: j['id'] as String,
    name: j['name'] as String,
    source: j['source'] as String,
    root: j['root'] as String,
    executable: j['executable'] as String? ?? '',
    launch: j['launch'] as String? ?? '',
    storeId: j['storeId'] as String? ?? '',
    namespace: j['namespace'] as String? ?? '',
    lastPlayed: DateTime.tryParse(j['lastPlayed'] as String? ?? ''),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'source': source,
    'root': root,
    'executable': executable,
    'launch': launch,
    'storeId': storeId,
    'namespace': namespace,
    'lastPlayed': lastPlayed?.toIso8601String(),
  };
  bool matches(Map<String, dynamic> process) {
    final path = process['path'] as String? ?? '';
    if (executable.isNotEmpty && gamePath(path) == gamePath(executable)) {
      return true;
    }
    if (source == 'Manual' ||
        !insideGame(path, root) ||
        process['window'] != true) {
      return false;
    }
    final name = gamePath(path).split(r'\').last;
    return !RegExp(
      r'crash|report|unins|setup|redist|helper|launcher|webhelper|anticheat',
      caseSensitive: false,
    ).hasMatch(name);
  }
}

// Valve's text KeyValues format: quoted strings, nested objects and line comments.
Map<String, dynamic> parseGameVdf(String source) {
  final tokens = RegExp(r'"((?:\\.|[^"\\])*)"|([{}])|//[^\r\n]*')
      .allMatches(source)
      .where((m) => !m[0]!.startsWith('//'))
      .map((m) => m[2] ?? m[1]!.replaceAll(r'\\', r'\').replaceAll(r'\"', '"'))
      .toList();
  int index = 0;
  Map<String, dynamic> object() {
    final result = <String, dynamic>{};
    while (index < tokens.length) {
      final key = tokens[index++];
      if (key == '}') break;
      if (index >= tokens.length) break;
      final value = tokens[index++];
      result[key.toLowerCase()] = value == '{' ? object() : value;
    }
    return result;
  }

  return object();
}

class GameDiscovery {
  static Future<List<LocalGame>> riot(String programData) async {
    try {
      final data =
          jsonDecode(
                await File(
                  '$programData/Riot Games/RiotClientInstalls.json',
                ).readAsString(),
              )
              as Map;
      final associated = data['associated_client'];
      if (associated is! Map) return [];
      for (final path in associated.keys.whereType<String>()) {
        final executable =
            '$path/ShooterGame/Binaries/Win64/VALORANT-Win64-Shipping.exe';
        if (await File(executable).exists()) {
          return [
            LocalGame(
              id: 'riot:valorant',
              name: 'VALORANT',
              source: 'Riot Games',
              root: path,
              executable: executable,
              launch: 'riot:valorant',
            ),
          ];
        }
      }
    } catch (_) {
      /* Riot Client is optional. */
    }
    return [];
  }

  static Future<List<LocalGame>> scan(
    List<String> steamRoots,
    String epicFolder,
  ) async {
    final games = <String, LocalGame>{};
    final libraries = <String, String>{};
    for (final root in steamRoots) {
      libraries[gamePath(root)] = root;
      try {
        final file = File('$root/steamapps/libraryfolders.vdf');
        if (!await file.exists()) continue;
        final data = parseGameVdf(await file.readAsString())['libraryfolders'];
        if (data is Map) {
          for (final entry in data.entries) {
            if (!RegExp(r'^\d+$').hasMatch(entry.key.toString())) continue;
            final value = entry.value is Map
                ? entry.value['path']
                : entry.value;
            if (value is String) libraries[gamePath(value)] = value;
          }
        }
      } on FileSystemException {
        /* A missing drive must not hide other libraries. */
      }
    }
    for (final root in libraries.values) {
      final folder = Directory('$root/steamapps');
      try {
        if (!await folder.exists()) continue;
        await for (final entity in folder.list(followLinks: false)) {
          if (entity is! File ||
              !RegExp(r'appmanifest_\d+\.acf$').hasMatch(entity.path)) {
            continue;
          }
          try {
            final app = parseGameVdf(await entity.readAsString())['appstate'];
            if (app is! Map) continue;
            final id = app['appid'],
                name = app['name'],
                install = app['installdir'];
            if (id is! String ||
                !RegExp(r'^\d+$').hasMatch(id) ||
                name is! String ||
                install is! String ||
                install.contains(RegExp(r'[/\\]')) ||
                install == '..') {
              continue;
            }
            if (RegExp(
              r'Steamworks Common Redistributables|Steam Linux Runtime|Proton',
              caseSensitive: false,
            ).hasMatch(name)) {
              continue;
            }
            final path = '$root/steamapps/common/$install';
            if (!await Directory(path).exists()) continue;
            games['steam:$id'] = LocalGame(
              id: 'steam:$id',
              name: name,
              source: 'Steam',
              root: path,
              launch: 'steam://rungameid/$id',
              storeId: id,
            );
          } on FileSystemException {
            continue;
          }
        }
      } on FileSystemException {
        continue;
      }
    }
    try {
      final folder = Directory(epicFolder);
      if (await folder.exists()) {
        await for (final file in folder.list(followLinks: false)) {
          if (file is! File || !file.path.endsWith('.item')) continue;
          try {
            final data =
                jsonDecode(await file.readAsString()) as Map<String, dynamic>;
            final id = data['AppName'],
                root = data['InstallLocation'],
                name = data['DisplayName'];
            if (id is! String ||
                root is! String ||
                name is! String ||
                data['bIsIncompleteInstall'] == true ||
                !await Directory(root).exists()) {
              continue;
            }
            if (data['MainGameAppName'] is String &&
                data['MainGameAppName'] != id) {
              continue;
            }
            final exe = '$root/${data['LaunchExecutable'] ?? ''}';
            games['epic:$id'] = LocalGame(
              id: 'epic:$id',
              name: name,
              source: 'Epic Games',
              root: root,
              executable:
                  insideGame(exe, root) && exe.toLowerCase().endsWith('.exe')
                  ? exe
                  : '',
              launch:
                  'com.epicgames.launcher://apps/${Uri.encodeComponent(id)}?action=launch&silent=true',
              storeId: data['CatalogItemId'] as String? ?? '',
              namespace: data['CatalogNamespace'] as String? ?? '',
            );
          } catch (_) {
            continue;
          }
        }
      }
    } on FileSystemException {
      /* Epic is optional. */
    }
    return games.values.toList();
  }
}

class GameLibrary extends ChangeNotifier {
  static const channel = MethodChannel('ryhze/game_library');
  static const permissionKey = 'game-library-permission-v1';
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  final SharedPreferences prefs;
  final Future<List<Map<String, dynamic>>> Function()? processReader;
  final bool autoPoll;
  List<LocalGame> games = [];
  Map<String, List<Map<String, dynamic>>> running = {};
  final Map<String, DateTime> launching = {};
  final Set<String> busy = {};
  bool scanning = false, _polling = false, _disposed = false;
  int _generation = 0;
  String? error;
  Timer? _timer;
  GameLibrary(this.prefs, {this.processReader, this.autoPoll = true}) {
    try {
      final saved =
          jsonDecode(prefs.getString('game-library-v1') ?? '[]') as List;
      games = saved
          .map((e) => LocalGame.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      error =
          'The saved library could not be read. Scan again to restore your games.';
    }
  }
  bool? get permission => prefs.getBool(permissionKey);
  List<LocalGame> get sorted => [...games]
    ..sort((a, b) {
      final active = (isRunning(b) ? 1 : 0).compareTo(isRunning(a) ? 1 : 0);
      if (active != 0) return active;
      final last = (b.lastPlayed?.millisecondsSinceEpoch ?? 0).compareTo(
        a.lastPlayed?.millisecondsSinceEpoch ?? 0,
      );
      return last != 0
          ? last
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  void emit() {
    if (!_disposed) notifyListeners();
  }

  Future<void> save() async {
    if (!await prefs.setString(
      'game-library-v1',
      jsonEncode(games.map((g) => g.toJson()).toList()),
    )) {
      throw StateError(
        'Windows could not save your game library. Please try again.',
      );
    }
  }

  void start() {
    if (permission != true || !autoPoll || _disposed) return;
    _timer ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(refresh()),
    );
    unawaited(refresh());
  }

  Future<void> allow(bool value) async {
    if (!await prefs.setBool(permissionKey, value)) {
      throw StateError('Your permission choice could not be saved.');
    }
    _generation++;
    if (value) {
      start();
    } else {
      _timer?.cancel();
      _timer = null;
      running.clear();
      launching.clear();
    }
    emit();
  }

  Future<void> scan({String? extraSteamRoot}) async {
    if (permission != true || scanning) return;
    final generation = _generation;
    scanning = true;
    error = null;
    emit();
    try {
      final roots =
          await channel.invokeMapMethod<String, dynamic>('roots') ?? {};
      final savedRoots = prefs.getStringList('game-library-steam-roots') ?? [];
      if (extraSteamRoot != null) {
        if (!await Directory('$extraSteamRoot/steamapps').exists()) {
          throw StateError(
            'Choose a Steam library folder containing steamapps.',
          );
        }
        if (!savedRoots.contains(extraSteamRoot)) {
          savedRoots.add(extraSteamRoot);
        }
        await prefs.setStringList('game-library-steam-roots', savedRoots);
      }
      final discovered = await GameDiscovery.scan(
        [
          ...List<String>.from(roots['steam'] as List? ?? []),
          ...savedRoots,
          '${Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)'}/Steam',
        ],
        '${Platform.environment['PROGRAMDATA'] ?? r'C:\ProgramData'}/Epic/EpicGamesLauncher/Data/Manifests',
      );
      discovered.addAll(
        await GameDiscovery.riot(
          Platform.environment['PROGRAMDATA'] ?? r'C:\ProgramData',
        ),
      );
      if (_disposed || generation != _generation || permission != true) return;
      final hidden = (prefs.getStringList('game-library-hidden') ?? []).toSet();
      final merged = {for (final g in games) g.id: g};
      for (final game in discovered) {
        if (hidden.contains(game.id)) continue;
        game.lastPlayed = merged[game.id]?.lastPlayed;
        // A manually repaired executable takes precedence over store metadata.
        final previous = merged[game.id];
        merged[game.id] =
            previous != null &&
                prefs
                        .getStringList('game-library-repaired')
                        ?.contains(game.id) ==
                    true
            ? previous
            : game;
      }
      games = merged.values.toList();
      await save();
      await refresh();
    } catch (e) {
      error = e.toString();
    } finally {
      scanning = false;
      emit();
    }
  }

  bool isRunning(LocalGame game) => running[game.id]?.isNotEmpty == true;
  Future<void> refresh() async {
    if (permission != true || _polling || _disposed) return;
    final generation = _generation;
    _polling = true;
    try {
      final processes = processReader != null
          ? await processReader!()
          : (await channel.invokeListMethod<dynamic>('processes') ?? [])
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList();
      if (_disposed || generation != _generation || permission != true) return;
      final next = <String, List<Map<String, dynamic>>>{};
      bool changed = false;
      final now = DateTime.now();
      for (final game in games) {
        final matches = processes.where(game.matches).toList();
        if (matches.isNotEmpty) {
          next[game.id] = matches;
          launching.remove(game.id);
          if (!isRunning(game)) {
            game.lastPlayed = now;
            changed = true;
          }
        } else if (isRunning(game)) {
          game.lastPlayed = now;
          changed = true;
        }
      }
      running = next;
      for (final id in launching.keys.toList()) {
        if (now.difference(launching[id]!) > const Duration(seconds: 90)) {
          launching.remove(id);
          error =
              'The game has not been detected yet. Check its launcher, or edit the game executable if its path changed.';
        }
      }
      if (changed) await save();
      emit();
    } catch (e) {
      error = 'Game activity is unavailable: $e';
      emit();
    } finally {
      _polling = false;
    }
  }

  Future<void> launchGame(LocalGame game) async {
    if (permission != true ||
        busy.contains(game.id) ||
        launching.containsKey(game.id)) {
      return;
    }
    busy.add(game.id);
    error = null;
    emit();
    try {
      await refresh();
      if (permission != true || _disposed) return;
      if (isRunning(game)) {
        await control(game, 'resume');
        return;
      }
      if (!await Directory(game.root).exists()) {
        throw StateError(
          'This game drive or folder is unavailable. Reconnect it or edit the game path.',
        );
      }
      if (permission != true || _disposed) return;
      if (game.launch == 'riot:valorant') {
        final client = await Games.riotClient();
        if (client == null) {
          throw StateError(
            'Riot Client is unavailable. Install or repair Riot Client first.',
          );
        }
        await Games.launchValorant(client);
      } else if (game.launch.startsWith('steam://rungameid/') ||
          game.launch.startsWith('com.epicgames.launcher://apps/')) {
        if (!await launchUrl(
          Uri.parse(game.launch),
          mode: LaunchMode.externalApplication,
        )) {
          throw StateError(
            'The original launcher could not open. Check that it is installed.',
          );
        }
      } else {
        if (!game.executable.toLowerCase().endsWith('.exe') ||
            !await File(game.executable).exists()) {
          throw StateError('Game executable not found. Edit the game path.');
        }
        await Process.start(
          game.executable,
          [],
          workingDirectory: File(game.executable).parent.path,
          mode: ProcessStartMode.detached,
        );
      }
      launching[game.id] = DateTime.now();
    } finally {
      busy.remove(game.id);
      emit();
    }
  }

  Future<void> control(LocalGame game, String action) async {
    if (permission != true) return;
    final processes = running[game.id] ?? [];
    if (processes.isEmpty) throw StateError('This game is no longer running.');
    if (action == 'resume') {
      final visible = processes.where((p) => p['window'] == true);
      await channel.invokeMethod<void>(
        action,
        visible.isEmpty ? processes.first : visible.first,
      );
    } else {
      for (final process in processes) {
        await channel.invokeMethod<void>(action, process);
      }
    }
  }

  Future<void> addManual(
    String name,
    String executable, {
    LocalGame? previous,
    String steamId = '',
  }) async {
    if (permission != true) return;
    final path = executable.trim().replaceAll(RegExp(r'^"|"$'), '');
    if (name.trim().isEmpty) throw StateError('Enter a game name.');
    if (RegExp(
      r'^(steam|steamwebhelper|epicgameslauncher|riotclientservices|explorer|cmd|powershell|pwsh)\.exe$',
      caseSensitive: false,
    ).hasMatch(gamePath(path).split(r'\').last)) {
      throw StateError(
        'Choose the game executable, not a shared launcher or Windows tool.',
      );
    }
    if (!RegExp(r'^(?:[A-Za-z]:[/\\]|\\\\)').hasMatch(path) ||
        !path.toLowerCase().endsWith('.exe') ||
        !await File(path).exists()) {
      throw StateError('Select an existing game .exe using its full path.');
    }
    if (steamId.isNotEmpty && !RegExp(r'^\d+$').hasMatch(steamId)) {
      throw StateError('Enter the numeric Steam app ID, or leave it empty.');
    }
    if (games.any(
      (g) => g.id != previous?.id && gamePath(g.executable) == gamePath(path),
    )) {
      throw StateError('That executable is already in your library.');
    }
    final game = LocalGame(
      id: previous?.id ?? 'manual:${gamePath(path)}',
      name: name.trim(),
      source: previous?.source ?? 'Manual',
      root: previous != null && insideGame(path, previous.root)
          ? previous.root
          : File(path).parent.path,
      executable: path,
      launch: previous?.launch ?? '',
      storeId: previous?.source == 'Epic Games' ? previous!.storeId : steamId,
      namespace: previous?.namespace ?? '',
      lastPlayed: previous?.lastPlayed,
    );
    games = [...games.where((g) => g.id != game.id), game];
    if (previous != null) {
      await prefs.setStringList('game-library-repaired', [
        ...?prefs.getStringList('game-library-repaired'),
        game.id,
      ]);
    }
    await save();
    emit();
    await refresh();
  }

  Future<void> remove(LocalGame game) async {
    games.removeWhere((g) => g.id == game.id);
    running.remove(game.id);
    launching.remove(game.id);
    await prefs.setStringList('game-library-hidden', [
      ...?prefs.getStringList('game-library-hidden'),
      game.id,
    ]);
    await save();
    emit();
  }

  Future<void> clearHistory() async {
    for (final game in games) {
      game.lastPlayed = null;
    }
    await save();
    emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _timer?.cancel();
    super.dispose();
  }
}
