import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/steam_launch_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/steam');
  final calls = <MethodCall>[];
  var time = DateTime(2026);
  late SteamLaunchSessions sessions;
  setUp(() {
    time = DateTime(2026);
    calls.clear();
    sessions = SteamLaunchSessions(channel, clock: () => time);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  test('validates Steam IDs before invoking native launch', () async {
    for (final uri in [
      'steam://rungameid/0',
      'steam://rungameid/12;echo',
      'https://steam/123',
    ]) {
      await expectLater(sessions.launch('game', uri), throwsArgumentError);
    }
    expect(calls, isEmpty);
    await sessions.launch('game', 'steam://rungameid/123');
    expect(calls.single.method, 'launchSteam');
    expect(calls.single.arguments, {'appId': '123'});
  });
  test(
    'ignores unrelated games and confirms exit across separated samples',
    () async {
      await sessions.launch('game', 'steam://rungameid/123');
      await sessions.refresh({'unrelated'});
      expect(calls.last.arguments['finished'], false);
      await sessions.refresh({'game'});
      await sessions.refresh({});
      time = time.add(const Duration(seconds: 5));
      await sessions.refresh({'game'}); // transient launcher handover recovered
      expect(calls.last.arguments['finished'], false);
      await sessions.refresh({});
      await sessions.refresh({}); // same instant cannot count as confirmed exit
      expect(calls.last.arguments['finished'], false);
      time = time.add(const Duration(seconds: 5));
      await sessions.refresh({});
      expect(calls.last.arguments, {
        'appId': '123',
        'running': false,
        'finished': true,
      });
      final length = calls.length;
      await sessions.refresh({});
      expect(calls.length, length);
    },
  );
  test(
    'launch timeout cancels suppression without a false game exit',
    () async {
      await sessions.launch('game', 'steam://rungameid/123');
      time = time.add(const Duration(seconds: 91));
      await sessions.refresh({});
      expect(calls.last.method, 'cancelSteamSession');
      expect(calls.where((c) => c.arguments['finished'] == true), isEmpty);
    },
  );
  test(
    'multiple launches have independent lifetimes and cancel cleanly',
    () async {
      await sessions.launch('one', 'steam://rungameid/123');
      await sessions.launch('two', 'steam://rungameid/456');
      await sessions.cancel('one');
      await sessions.refresh({'two'});
      expect(calls.last.arguments['appId'], '456');
      await sessions.cancelAll();
      expect(calls.last.arguments, {'appId': '456'});
      final length = calls.length;
      await sessions.refresh({});
      expect(calls.length, length);
    },
  );
  test('failed native launch never creates a tracked session', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          throw PlatformException(code: 'steam');
        });
    await expectLater(
      sessions.launch('game', 'steam://rungameid/123'),
      throwsA(isA<PlatformException>()),
    );
    await sessions.refresh({'game'});
    expect(calls.length, 1);
  });
}
