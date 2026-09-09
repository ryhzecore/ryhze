import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/state.dart';
import 'package:ryhze/core/games.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/playback_bar.dart';

class VolatileSession implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async {
    value = v;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  testWidgets('native secure storage and production discovery', (tester) async {
    const storage = FlutterSecureStorage();
    final key = 'ryhze-qa-${DateTime.now().microsecondsSinceEpoch}';
    try {
      await storage.write(key: key, value: 'storage-test');
      expect(await storage.read(key: key), 'storage-test');
    } finally {
      await storage.delete(key: key);
    }
    final api = RyhzeApi(store: VolatileSession());
    await api.connect();
    final data = await api.request('/api/discover') as List;
    expect(data.any((t) => t['id'] == 'larcenous-driftscape'), true);
    expect(await Games.riotClient(), Platform.isWindows ? isNotNull : isNull);
    api.close();
  });
  testWidgets(
    'authenticated native playback, seek, pause, resume and title navigation',
    (tester) async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final video = File(
        const String.fromEnvironment(
          'RYHZE_TEST_VIDEO',
          defaultValue: 'C:/Test123/app/.private/qa/playback.mp4',
        ),
      );
      const fixtureUrl = String.fromEnvironment('RYHZE_TEST_VIDEO_URL');
      final bytes = fixtureUrl.isEmpty
          ? await video.readAsBytes()
          : (await http.get(Uri.parse(fixtureUrl))).bodyBytes;
      final token = 'b' * 64;
      var authenticatedMediaRequests = 0;
      server.listen((request) async {
        final r = request.response;
        final authenticated =
            request.headers.value('cookie') == '__Host-ryhze_session=$token';
        if (request.uri.path.startsWith('/media/')) {
          if (!authenticated) {
            r.statusCode = 401;
            await r.close();
            return;
          }
          authenticatedMediaRequests++;
          r.headers.contentType = ContentType('video', 'mp4');
          r.headers.set('Accept-Ranges', 'bytes');
          var start = 0, end = bytes.length - 1;
          final range = RegExp(
            r'bytes=(\d+)-(\d*)',
          ).firstMatch(request.headers.value('range') ?? '');
          if (range != null) {
            start = int.parse(range[1]!);
            if (range[2]!.isNotEmpty) {
              end = int.parse(range[2]!).clamp(start, bytes.length - 1);
            }
            r.statusCode = 206;
            r.headers.set('Content-Range', 'bytes $start-$end/${bytes.length}');
          }
          r.contentLength = end - start + 1;
          if (request.method != 'HEAD') r.add(bytes.sublist(start, end + 1));
          await r.close();
          return;
        }
        r.headers.contentType = ContentType.json;
        if (request.uri.path == '/api/login') {
          r.headers.set(
            'Set-Cookie',
            '__Host-ryhze_session=$token; Path=/; Secure; HttpOnly',
          );
          r.write('{"user":{"username":"native-qa","role":"viewer"}}');
        } else if (request.uri.path == '/api/session') {
          r.statusCode = authenticated ? 200 : 401;
          r.write(
            authenticated
                ? '{"user":{"username":"native-qa","role":"viewer"}}'
                : '{"error":"Sign in required."}',
          );
        } else {
          r.write(
            jsonEncode([
              {
                'id': 'native-film',
                'title': 'Native playback verification',
                'kind': 'film',
                'label': 'Ryhze QA',
                'status': 'Test fixture',
                'description':
                    'A generated test pattern used only for local verification.',
                'image': '/art/san-coronado.png',
                'preview': '/media/Films/test.mp4',
                'streams': [
                  {'url': '/media/Films/test.mp4'},
                ],
              },
            ]),
          );
        }
        await r.close();
      });
      final api = RyhzeApi(
        origin: Uri.parse('http://127.0.0.1:${server.port}'),
        store: VolatileSession(),
      );
      SharedPreferences.setMockInitialValues({});
      final state = RyhzeState(api, await SharedPreferences.getInstance());
      await state.login('native-qa', 'local-test-only', false);
      final p = Player();
      try {
        await p.open(
          Media(
            api.media('/media/Films/test.mp4').toString(),
            httpHeaders: api.authHeaders,
          ),
        );
        await p.stream.duration
            .firstWhere((d) => d.inSeconds >= 10)
            .timeout(const Duration(seconds: 20));
        await p.seek(const Duration(seconds: 5));
        await p.pause();
        expect(p.state.duration.inSeconds, greaterThanOrEqualTo(10));
        await p.play();
        await p.stream.position
            .firstWhere((d) => d.inSeconds >= 6)
            .timeout(const Duration(seconds: 15));
        expect(authenticatedMediaRequests, greaterThan(0));
      } finally {
        await p.dispose();
      }
      await tester.pumpWidget(RyhzeApp(state: state));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.tap(find.text('Films').first, pointer: 101);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      final card = find.byKey(const ValueKey('card-open-native-film'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      final beforePreview = authenticatedMediaRequests;
      final mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
        pointer: 931,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(tester.getCenter(card));
      for (var i = 0; i < 40 && find.byType(Video).evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(Video), findsOneWidget);
      expect(authenticatedMediaRequests, greaterThan(beforePreview));
      await mouse.moveTo(const Offset(1, 1));
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byType(Video), findsNothing);
      await mouse.removePointer();
      await tester.tap(card, pointer: 102);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.ensureVisible(find.text('Play').first);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.tap(find.text('Play').first, pointer: 103);
      for (
        var i = 0;
        i < 30 && find.byTooltip('Pause').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byTooltip('Pause'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Pause'));
      await tester.tap(find.byTooltip('Pause'), pointer: 104);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('Play'), findsOneWidget);
      debugPrint('QA: Opening playback options');
      await tester.tap(find.byTooltip('Playback options'), pointer: 107);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      final speedOption = find.byWidgetPredicate(
        (widget) =>
            widget is CheckedPopupMenuItem<String> && widget.value == '1.5',
      );
      await tester.ensureVisible(speedOption);
      await tester.tap(speedOption, pointer: 108);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(
        tester.widget<PlaybackBar>(find.byType(PlaybackBar)).player.state.rate,
        1.5,
      );
      debugPrint('QA: Checking compact player');
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.ensureVisible(find.byTooltip('Full screen'));
      debugPrint('QA: Entering full screen');
      await tester.tap(find.byTooltip('Full screen'), pointer: 109);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.byTooltip('Exit full screen'), findsOneWidget);
      debugPrint('QA: Leaving full screen');
      await tester.tap(find.byTooltip('Exit full screen'), pointer: 110);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(tester.takeException(), isNull);
      debugPrint('QA: Returning to artwork');
      await tester.tap(find.byTooltip('Return to artwork'), pointer: 105);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      await tester.tap(find.text('Back'), pointer: 106);
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 20),
      );
      expect(find.text('Explore the film'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      api.close();
      await server.close(force: true);
    },
  );
}
