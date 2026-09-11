import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/updates.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/updates.dart';

void main() {
  late SimpleKeyPair key;
  late String publicKey;
  late Directory folder;
  final package = utf8.encode(
    'An update package fixture with a verifiable digest.',
  );
  late Map<String, Object> release;
  setUpAll(() async {
    key = await Ed25519().newKeyPair();
    publicKey = base64Encode((await key.extractPublicKey()).bytes);
  });
  setUp(() async {
    folder = await Directory.systemTemp.createTemp('ryhze-update-test-');
    release = {
      'platform': 'windows',
      'version': '1.0.4',
      'build': 5,
      'path': '/releases/1.0.4/Ryhze-1.0.4-Windows-Setup.exe',
      'bytes': package.length,
      'sha256': hashes.sha256.convert(package).toString(),
      'notes': 'A verified test update.',
    };
  });
  tearDown(() async {
    await folder.delete(recursive: true);
  });

  Future<String> signed({Map<String, Object>? value, String? product}) async {
    final payload = utf8.encode(
      jsonEncode({
        'schema': 1,
        if (product != null) 'product': product,
        'releases': [value ?? release],
      }),
    );
    final signature = await Ed25519().sign(payload, keyPair: key);
    return jsonEncode({
      'keyId': 'ryhze-updates-2026',
      'payload': base64Encode(payload),
      'signature': base64Encode(signature.bytes),
    });
  }

  test(
    'RACE accepts only its signed private release path and product',
    () async {
      final race = {
        ...release,
        'path': '/api/admin/race/releases/1.0.4/RACE-1.0.4-Windows-Setup.exe',
      };
      final envelope = await signed(value: race, product: 'race');
      expect(
        (await AppRelease.verify(
          envelope,
          'windows',
          publicKey: publicKey,
          product: 'RACE',
        ))!.filename,
        'RACE-1.0.4-Windows-Setup.exe',
      );
      await expectLater(
        AppRelease.verify(envelope, 'windows', publicKey: publicKey),
        throwsFormatException,
      );
      await expectLater(
        AppRelease.verify(
          await signed(value: race),
          'windows',
          publicKey: publicKey,
          product: 'RACE',
        ),
        throwsFormatException,
      );
      await expectLater(
        AppRelease.verify(
          await signed(),
          'windows',
          publicKey: publicKey,
          product: 'RACE',
        ),
        throwsFormatException,
      );
    },
  );

  AppUpdates controller(
    String index, {
    List<int>? data,
    int status = 200,
    Future<String?> Function(File, AppRelease)? install,
    void Function(http.Request)? inspect,
  }) => AppUpdates(
    currentBuild: 4,
    platform: 'windows',
    publicKey: publicKey,
    directory: () async => folder,
    installer: install ?? (_, _) async => null,
    clientFactory: () => MockClient((request) async {
      inspect?.call(request);
      return request.url.path == '/stable.json'
          ? http.Response(index, status)
          : http.Response.bytes(data ?? package, 200);
    }),
  );

  test(
    'accepts the correct signed release and no credentials are sent',
    () async {
      final updates = controller(
        await signed(),
        inspect: (request) {
          expect(request.url.origin, updateOrigin);
          expect(request.followRedirects, false);
          expect(request.headers.containsKey('Authorization'), false);
        },
      );
      addTearDown(updates.dispose);
      await updates.check();
      expect(updates.phase, UpdatePhase.available);
      expect(updates.showBanner, true);
      updates.dismiss();
      expect(updates.showBanner, false);
      expect(updates.available, true);
      await updates.check();
      expect(updates.showBanner, false);
    },
  );
  test('rejects a modified signed payload', () async {
    final envelope = jsonDecode(await signed()) as Map<String, dynamic>;
    final payload = jsonDecode(
      utf8.decode(base64Decode(envelope['payload'] as String)),
    );
    payload['releases'][0]['version'] = '9.0.0';
    envelope['payload'] = base64Encode(utf8.encode(jsonEncode(payload)));
    final updates = controller(jsonEncode(envelope));
    addTearDown(updates.dispose);
    await updates.check();
    expect(updates.phase, UpdatePhase.failed);
    expect(updates.available, false);
  });
  for (final field in ['path', 'bytes', 'sha256']) {
    test('rejects signed invalid $field', () async {
      release[field] = switch (field) {
        'path' => 'https://untrusted.example/package.exe',
        'bytes' => -1,
        _ => 'invalid-hash',
      };
      final updates = controller(await signed());
      addTearDown(updates.dispose);
      await updates.check();
      expect(updates.phase, UpdatePhase.failed);
      expect(updates.available, false);
    });
  }
  for (final build in [2, 3, 4]) {
    test('never offers build $build over installed build 4', () async {
      release['build'] = build;
      final updates = controller(await signed());
      addTearDown(updates.dispose);
      await updates.check();
      expect(updates.phase, UpdatePhase.current);
      expect(updates.available, false);
    });
  }
  test(
    'downloads, verifies, restores and installs the exact signed package',
    () async {
      var installed = 0;
      final index = await signed();
      final updates = controller(index);
      addTearDown(updates.dispose);
      await updates.check();
      await updates.download();
      expect(updates.phase, UpdatePhase.ready);
      expect(updates.progress, 1);
      final restored = controller(
        index,
        install: (file, release) async {
          expect(await file.readAsBytes(), package);
          expect(release.build, 5);
          installed++;
          return 'Installation requested';
        },
      );
      addTearDown(restored.dispose);
      await restored.check();
      expect(restored.phase, UpdatePhase.ready);
      await restored.install();
      expect(installed, 1);
      expect(restored.instruction, 'Installation requested');
      expect(
        folder.listSync().whereType<File>().any(
          (f) => f.path.endsWith('.part'),
        ),
        false,
      );
    },
  );
  test(
    'rejects corruption of equal byte length and removes temporary files',
    () async {
      final bad = [...package]..[0] = 0;
      final updates = controller(await signed(), data: bad);
      addTearDown(updates.dispose);
      await updates.check();
      await updates.download();
      expect(updates.phase, UpdatePhase.failed);
      expect(folder.listSync(), isEmpty);
    },
  );
  test('rejects truncated packages', () async {
    final updates = controller(await signed(), data: package.sublist(0, 4));
    addTearDown(updates.dispose);
    await updates.check();
    await updates.download();
    expect(updates.phase, UpdatePhase.failed);
    expect(folder.listSync(), isEmpty);
  });
  test(
    'rechecks package before installation and prevents a changed file',
    () async {
      var installs = 0;
      final updates = controller(
        await signed(),
        install: (_, _) async {
          installs++;
          return null;
        },
      );
      addTearDown(updates.dispose);
      await updates.check();
      await updates.download();
      await File(
        '${folder.path}/${updates.release!.filename}',
      ).writeAsBytes([...package]..[1] = 0);
      await updates.install();
      expect(installs, 0);
      expect(updates.phase, UpdatePhase.available);
      expect(updates.error, isNotNull);
    },
  );
  test('network and redirect failures stay retryable', () async {
    for (final status in [302, 503]) {
      final updates = controller('', status: status);
      await updates.check();
      expect(updates.phase, UpdatePhase.failed);
      expect(updates.busy, false);
      expect(updates.error, isNotNull);
      updates.dispose();
    }
  });
  test('cancel prevents install and safely cleans up before retry', () async {
    final index = await signed();
    late AppUpdates updates;
    updates = AppUpdates(
      currentBuild: 4,
      platform: 'windows',
      publicKey: publicKey,
      directory: () async => folder,
      clientFactory: () => MockClient.streaming((request, _) async {
        if (request.url.path == '/stable.json') {
          return http.StreamedResponse(Stream.value(utf8.encode(index)), 200);
        }
        return http.StreamedResponse(() async* {
          yield package.sublist(0, 5);
          updates.cancelDownload();
          yield package.sublist(5);
        }(), 200);
      }),
    );
    addTearDown(updates.dispose);
    await updates.check();
    await updates.download();
    expect(updates.phase, UpdatePhase.available);
    expect(updates.busy, false);
    expect(folder.listSync(), isEmpty);
  });
  test('unsupported platforms do not contact the update service', () async {
    final updates = AppUpdates(
      platform: 'ios',
      clientFactory: () => throw StateError('Must not contact service'),
    );
    addTearDown(updates.dispose);
    await updates.check();
    expect(updates.phase, UpdatePhase.idle);
  });
  for (final width in [320.0, 1280.0]) {
    testWidgets('update panel fits $width and shows download then install', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late AppUpdates updates;
      await tester.runAsync(() async {
        updates = controller(await signed());
        await updates.check();
      });
      addTearDown(updates.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(body: UpdatePanel(updates: updates)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Update available'), findsOneWidget);
      expect(find.text('Download update'), findsOneWidget);
      await tester.runAsync(updates.download);
      await tester.pumpAndSettle();
      expect(find.text('Install and restart'), findsOneWidget);
      expect(tester.takeException(), isNull);
      updates.dismiss();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UpdateBanner(updates: updates, onOpen: () {}),
          ),
        ),
      );
      expect(find.text('Ryhze update available'), findsNothing);
    });
  }
}
