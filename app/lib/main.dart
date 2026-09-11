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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = RyhzeState(RyhzeApi(), prefs);
  final updates = AppUpdates();
  runApp(
    RyhzeApp(
      state: state,
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
  const RyhzeApp({
    super.key,
    required this.state,
    this.updates,
    this.gameLibrary,
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
        child: MotionSettings(reduced: state.reduced, child: child!),
      ),
    ),
    home: RyhzeShell(state: state, updates: updates, gameLibrary: gameLibrary),
  );
}
