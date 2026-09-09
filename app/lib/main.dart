import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/api.dart';
import 'core/state.dart';
import 'core/updates.dart';
import 'ui/design.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final state = RyhzeState(RyhzeApi(), prefs);
  final updates = AppUpdates();
  runApp(RyhzeApp(state: state, updates: updates));
  updates.start();
  await state.initialize();
}

class RyhzeApp extends StatelessWidget {
  final RyhzeState state;
  final AppUpdates? updates;
  const RyhzeApp({super.key, required this.state, this.updates});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Ryhze',
    debugShowCheckedModeBanner: false,
    theme: ryhzeTheme(),
    builder: (context, child) => ListenableBuilder(
      listenable: state,
      builder: (_, _) => MotionSettings(reduced: state.reduced, child: child!),
    ),
    home: RyhzeShell(state: state, updates: updates),
  );
}
