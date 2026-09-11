import 'dart:io';
import 'package:flutter/services.dart';

const raceDirectoryKey = 'race-install-directory';
const raceChannel = MethodChannel('ryhze/game_library');

Future<Map<String, dynamic>?> raceInstallation({
  String? directory,
  bool strict = false,
}) async {
  if (!Platform.isWindows) return null;
  var value = await raceChannel.invokeMapMethod<String, dynamic>(
    'raceInstallation',
    {'path': directory ?? ''},
  );
  if (value == null && !strict && directory != null && directory.isNotEmpty) {
    value = await raceChannel.invokeMapMethod<String, dynamic>(
      'raceInstallation',
      {'path': ''},
    );
  }
  if (value == null) return null;
  if (value['executable'] is! String ||
      value['path'] is! String ||
      value['version'] is! String) {
    throw const FormatException(
      'Windows returned an invalid RACE installation.',
    );
  }
  return value;
}
