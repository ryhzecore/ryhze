import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/updates.dart';

void main() {
  const input = String.fromEnvironment('RYHZE_BUILD34_FEED');
  test(
    'build 34 signed release upgrades 32 and 33 while retaining the 0.1.0 label',
    () async {
      final file = File(input);
      final envelope = await file.readAsString();
      for (final platform in ['windows', 'android', 'linux']) {
        final release = await AppRelease.verify(envelope, platform);
        expect(release, isNotNull);
        if (platform == 'linux') {
          expect(release!.build, 32);
        } else {
          expect(release!.version, '0.1.0');
          expect(release.build, 34);
          expect(release.path, contains('-build34-'));
          for (final current in [32, 33]) {
            final updates = AppUpdates(
              platform: platform,
              currentBuild: current,
            )..release = release;
            expect(updates.available, isTrue);
            updates.dispose();
          }
        }
      }
      await File('${file.parent.path}/parser-receipt.json').writeAsString(
        jsonEncode({
          'passed': true,
          'platforms': ['windows', 'android', 'linux'],
          'upgradesFrom': [32, 33],
          'feedSha256': sha256.convert(utf8.encode(envelope)).toString(),
        }),
      );
    },
    skip: input.isEmpty
        ? 'Requires the signed build 34 release candidate.'
        : false,
  );
}
