import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/core/game_media.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/engine.dart';
import '../test/support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets(
    'native installed game expansion frame timings and RACE discovery',
    (tester) async {
      final state = await fixtureState();
      await state.prefs.setBool(GameLibrary.permissionKey, true);
      final game = LocalGame(
        id: 'steam:1091500',
        name: 'Cyberpunk 2077',
        source: 'Steam',
        root: r'D:\Games\Cyberpunk',
        storeId: '1091500',
      );
      final media = GameMediaStore(state.prefs);
      await media.load(game);
      final library = GameLibrary(state.prefs, autoPoll: false)..games = [game];
      await tester.pumpWidget(RyhzeApp(state: state, gameLibrary: library));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Game library'));
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(seconds: 2));
      final results = <Map<String, Object>>[];
      for (var pass = 0; pass < 3; pass++) {
        final timings = <FrameTiming>[];
        void collect(List<FrameTiming> values) => timings.addAll(values);
        SchedulerBinding.instance.addTimingsCallback(collect);
        await tester.tap(find.text('Cyberpunk 2077'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        SchedulerBinding.instance.removeTimingsCallback(collect);
        results.add({
          'pass': pass,
          'buildUs': timings
              .map((f) => f.buildDuration.inMicroseconds)
              .toList(),
          'rasterUs': timings
              .map((f) => f.rasterDuration.inMicroseconds)
              .toList(),
        });
      }
      final race = await raceInstallation();
      final report = {
        'viewport': [
          tester.view.physicalSize.width,
          tester.view.physicalSize.height,
        ],
        'dpr': tester.view.devicePixelRatio,
        'race': race,
        'passes': results,
      };
      const output = String.fromEnvironment(
        'PERFORMANCE_OUTPUT',
        defaultValue: 'C:/Test123/.private/qa/stutter/baseline.json',
      );
      await File(output).writeAsString(jsonEncode(report));
      expect(race?['executable'], isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      media.dispose();
      state.dispose();
    },
  );
}
