import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/engine_versions.dart';

void main() {
  final valid = <String, dynamic>{
    'id': 'RACE-0.0.3-Windows-20260912-183134-906',
    'version': '0.0.3',
    'url':
        '/api/engine/releases/RACE-0.0.3-Windows-20260912-183134-906/download',
    'sha256': 'a' * 64,
    'entrypoint': 'RACE-0.0.3-Windows-20260912-183134-906/RACE.exe',
    'bytes': 20832273,
  };
  test('RACE keeps a release agreement only when its hash matches the text', () {
    const text =
        'RACE ENGINE, INTERNAL DEVELOPMENT LICENCE\n1. This agreement covers RACE.';
    final digest = sha256.convert(utf8.encode(text)).toString();
    final build = EngineBuild.fromJson({
      ...valid,
      'agreement': {'version': 'race-internal-1.0', 'text': text, 'sha256': digest},
    });
    expect(build.agreement?.digest, digest);
    expect(build.toJson()['agreementSha256'], digest);
    expect(build.toJson().containsKey('agreement'), isFalse, reason: 'the text is never persisted with an install');
    expect(EngineBuild.fromJson(valid).agreement, isNull);
    expect(
      () => EngineBuild.fromJson({...valid, 'agreement': {'text': text, 'sha256': 'f' * 64}}),
      throwsFormatException,
      reason: 'a tampered agreement invalidates the release',
    );
  });

  test('RACE preserves exact immutable release identity', () {
    final build = EngineBuild.fromJson(valid);
    expect(build.toJson()['id'], valid['id']);
    expect(build.bytes, 20832273);
  });
  for (final invalid in <Map<String, dynamic>>[
    {'id': '../escape'},
    {'url': 'https://example.com/package.zip'},
    {'entrypoint': 'other/RACE.exe'},
    {'sha256': 'invalid'},
    {'bytes': 0},
  ]) {
    test(
      'RACE rejects invalid package metadata $invalid',
      () => expect(
        () => EngineBuild.fromJson({...valid, ...invalid}),
        throwsFormatException,
      ),
    );
  }
}
