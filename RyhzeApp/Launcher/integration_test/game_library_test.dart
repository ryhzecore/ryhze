import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native start, detection, identity guard, resume, graceful close and force stop',
    (tester) async {
      const fixture = String.fromEnvironment('RYHZE_GAME_FIXTURE');
      expect(Platform.isWindows, true);
      expect(await File(fixture).exists(), true);
      SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
      final prefs = await SharedPreferences.getInstance();
      final library = GameLibrary(prefs, autoPoll: false);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Verifying Windows game controls')),
          ),
        ),
      );
      await library.addManual('Ryhze test game', fixture);
      final game = library.games.single;
      Future<void> waitFor(bool active) async {
        for (int i = 0; i < 30; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 300));
          await library.refresh();
          if (library.isRunning(game) == active) return;
        }
        fail('Game activity did not become $active');
      }

      try {
        await library.launchGame(game);
        await waitFor(true);
        expect(game.lastPlayed, isNotNull);
        final identity = library.running[game.id]!.first;
        await expectLater(
          GameLibrary.channel.invokeMethod<void>('forceStop', {
            ...identity,
            'birth': 'invalid',
          }),
          throwsA(isA<PlatformException>()),
        );
        await library.refresh();
        expect(library.isRunning(game), true);
        await library.control(game, 'resume');
        await library.control(game, 'stop');
        await waitFor(false);
        final reopened = GameLibrary(prefs, autoPoll: false);
        expect(reopened.games.single.lastPlayed, isNotNull);
        reopened.dispose();
        await library.launchGame(game);
        await waitFor(true);
        await library.control(game, 'forceStop');
        await waitFor(false);
        // Detect a game started outside Ryhze as well.
        await Process.start(fixture, [], mode: ProcessStartMode.detached);
        await waitFor(true);
        await library.control(game, 'stop');
        await waitFor(false);
      } finally {
        await library.refresh();
        if (library.isRunning(game)) await library.control(game, 'forceStop');
        library.dispose();
      }
    },
  );
}
