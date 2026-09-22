import 'dart:convert';
import 'dart:io';

/// Steam remains responsible for Proton, Steam Input, DRM and game updates.
class LinuxGames {
  static List<String> steamRoots(Map<String, String> env) {
    final home = env['HOME'];
    if (home == null || home.isEmpty) return [];
    return [
      '$home/.steam/steam',
      '$home/.steam/root',
      '${env['XDG_DATA_HOME'] ?? '$home/.local/share'}/Steam',
      '$home/.var/app/com.valvesoftware.Steam/.local/share/Steam',
    ];
  }

  static Future<bool> isExecutable(String path) async {
    if (!path.startsWith('/') || path.toLowerCase().endsWith('.exe')) {
      return false;
    }
    final stat = await File(path).stat();
    return stat.type == FileSystemEntityType.file && (stat.mode & 0x49) != 0;
  }

  static Future<List<Map<String, dynamic>>> processes({
    String procRoot = '/proc',
  }) async {
    final result = <Map<String, dynamic>>[];
    await for (final entry in Directory(procRoot).list(followLinks: false)) {
      final pid = int.tryParse(entry.path.split('/').last);
      if (pid == null) continue;
      try {
        final path = await Link('${entry.path}/exe').target();
        final name = path.split('/').last;
        // Ignore launcher/runtime helpers which inherit SteamAppId.
        if (RegExp(
          r'^(steam|steamwebhelper|steamservice|pressure-vessel.*|wineserver.*|proton|.*crash.*|.*helper.*|sh|bash|python[0-9.]*)$',
          caseSensitive: false,
        ).hasMatch(name)) {
          continue;
        }
        if (name.toLowerCase().contains('wine')) {
          final command = utf8
              .decode(
                await File('${entry.path}/cmdline').readAsBytes(),
                allowMalformed: true,
              )
              .split('\x00');
          final programs = command.where(
            (arg) => arg.toLowerCase().endsWith('.exe'),
          );
          if (programs.isEmpty ||
              programs.every(
                (arg) => RegExp(
                  r'(services|explorer|winedevice|rpcss|plugplay|svchost|conhost|steam|.*crash.*|.*helper.*)\.exe$',
                  caseSensitive: false,
                ).hasMatch(arg),
              )) {
            continue;
          }
        }
        final bytes = await File('${entry.path}/environ').readAsBytes();
        final env = utf8.decode(bytes, allowMalformed: true).split('\x00');
        String id = '';
        for (final value in env) {
          if (RegExp(
            r'^(SteamAppId|STEAM_COMPAT_APP_ID)=\d+$',
          ).hasMatch(value)) {
            id = value.substring(value.indexOf('=') + 1);
            if (id != '0') break;
          }
        }
        result.add({
          'pid': pid,
          'path': path,
          'window': false,
          if (id != '0' && id.isNotEmpty) 'steamId': id,
        });
      } on FileSystemException {
        // Other users' processes and processes exiting during the scan are normal.
      }
    }
    return result;
  }
}
