import 'dart:convert';
import 'dart:io';

class SteamDeckStartup {
  const SteamDeckStartup();
  Future<bool?> read() async {
    final launcher = (await _invoke(['--status']))['launcher'];
    return launcher == 'ryhze' ? true : launcher == 'steam' ? false : null;
  }
  Future<bool> setEnabled(bool enabled) async {
    final result = await _invoke(['--set', enabled ? 'ryhze' : 'steam']);
    if (result['launcher'] != (enabled ? 'ryhze' : 'steam')) {
      throw StateError('SteamOS did not confirm the Launch Home setting.');
    }
    return enabled;
  }

  Future<Map<String, dynamic>> _invoke(List<String> arguments) async {
    if (!Platform.isLinux) {
      throw StateError('Launch Home is available on SteamOS.');
    }
    final root = File(Platform.resolvedExecutable).parent.parent;
    final script = File('${root.path}/boot_settings.py');
    if (!await script.exists()) {
      throw StateError('Install the SteamOS package to enable Launch Home.');
    }
    final result = await Process.run('/usr/bin/python3', [
      script.path,
      ...arguments,
    ]);
    final data = jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
    if (result.exitCode != 0 || data['error'] != null) {
      throw StateError(
        data['error']?.toString() ?? 'SteamOS could not save Launch Home.',
      );
    }
    return data;
  }
}
