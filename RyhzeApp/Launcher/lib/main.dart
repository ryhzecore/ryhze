import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api.dart';
import 'core/state.dart';
import 'core/updates.dart';
import 'core/game_library.dart';
import 'ui/design.dart';
import 'ui/shell.dart';
import 'ui/brand_intro.dart';
import 'ui/launcher_setup.dart';
import 'ui/desktop_window.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = RyhzeState(RyhzeApi(), prefs);
  final updates = AppUpdates();
  runApp(
    RyhzeApp(
      state: state,
      showLaunchIntro: true,
      bigPicture: arguments.contains('--big-picture'),
      setupLauncher: arguments.contains('--setup-launcher'),
      updates: updates,
      gameLibrary: GameLibrary.supported ? GameLibrary(prefs) : null,
    ),
  );
  updates.start();
  await state.initialize();
}

class RyhzeApp extends StatelessWidget {
  final RyhzeState state;
  final AppUpdates? updates;
  final GameLibrary? gameLibrary;
  final bool showLaunchIntro;
  final bool bigPicture;
  final bool setupLauncher;
  const RyhzeApp({
    super.key,
    required this.state,
    this.updates,
    this.gameLibrary,
    this.showLaunchIntro = false,
    this.bigPicture = false,
    this.setupLauncher = false,
  });
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ryhze',
    debugShowCheckedModeBanner: false,
    theme: ryhzeTheme(),
    builder: (context, child) => ListenableBuilder(
      listenable: state,
      builder: (_, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: canvas,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: canvas,
          systemNavigationBarDividerColor: canvas,
          systemNavigationBarIconBrightness: Brightness.light,
          systemNavigationBarContrastEnforced: false,
        ),
        child: MotionSettings(
          reduced: state.reduced,
          child: DesktopWindow(initialFullscreen: bigPicture, child: child!),
        ),
      ),
    ),
    home: showLaunchIntro
        ? ListenableBuilder(
            listenable: state,
            builder: (_, _) => BrandIntro(
              ready: !state.loading,
              sound: state.sound,
              reduced: state.reduced,
              builder: (playing) => LauncherSetupGate(
                requested: setupLauncher,
                ready: !playing,
                builder: (pending) => RyhzeShell(
                  state: state,
                  updates: updates,
                  gameLibrary: gameLibrary,
                  startupBlocked: playing || pending,
                  initialBigPicture: bigPicture,
                ),
              ),
            ),
          )
        : LauncherSetupGate(
            requested: setupLauncher,
            ready: true,
            builder: (pending) => RyhzeShell(
              state: state,
              updates: updates,
              gameLibrary: gameLibrary,
              startupBlocked: pending,
              initialBigPicture: bigPicture,
            ),
          ),
  );
}
