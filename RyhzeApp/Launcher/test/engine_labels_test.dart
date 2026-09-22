import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/engine_versions.dart';

EngineBuild build(String version, {String? id}) {
  final key = id ?? 'RACE-$version-Windows';
  return EngineBuild.fromJson({
    'id': key,
    'version': version,
    'url': '/api/engine/releases/$key/download',
    'sha256': 'a' * 64,
    'bytes': 1,
    'entrypoint': '$key/RACE.exe',
  });
}

void main() {
  test('friendly version labels retain exact installation identities', () {
    for (final entry in {
      '0.0.8': 'Game Export',
      '0.0.7': 'Source Backup',
      '0.0.6': 'Project Presets',
      '0.0.5': 'Scripted Sandbox',
      '0.0.4': 'Rotation Fixes',
    }.entries) {
      final release = build(entry.key);
      expect(release.displayLabel, 'V${entry.key} - ${entry.value}');
      expect(release.toJson()['id'], 'RACE-${entry.key}-Windows');
      expect(release.displayLabel, isNot(contains('Stable')));
    }
  });
  test('historical revisions are distinct without visible timestamps', () {
    final labels =
        [
              '20260912-201847-989',
              '20260912-185827-636',
              '20260912-183134-906',
              '20260912-181213-927',
            ]
            .map(
              (revision) => build(
                '0.0.3',
                id: 'RACE-0.0.3-Windows-$revision',
              ).displayLabel,
            )
            .toList();
    expect(labels.toSet().length, 4);
    expect(
      labels.every(
        (label) => !label.contains('20260912') && !label.contains('Windows'),
      ),
      isTrue,
    );
  });
  test('local labels use detected version without inventing release status', () {
    expect(
      localEngineVersionDescription('0.2.0'),
      'Executable reports 0.2.0. This local installation is not a verified release.',
    );
    expect(
      localEngineVersionDescription('RACE 0.0.7'),
      'Executable reports 0.0.7. This local installation is not a verified release.',
    );
    expect(localEngineVersionDescription(null), contains('version unknown'));
    expect(
      localEngineVersionDescription('Unknown'),
      contains('version unknown'),
    );
  });
}
