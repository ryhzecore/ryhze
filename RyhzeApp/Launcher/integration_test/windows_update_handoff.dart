// Destructive only to an explicitly opted-in, isolated QA installation.
// Build this entry point in debug mode, copy its complete runner directory into
// .private/qa/, and launch that copy. Never distribute this test entry point.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ryhze/core/updates.dart';

Future<void> main() async {
  if (!Platform.isWindows ||
      !const bool.fromEnvironment('RYHZE_UPDATE_QA') ||
      !Platform.resolvedExecutable
          .replaceAll('\\', '/')
          .contains('/.private/qa/')) {
    throw StateError('Use an explicitly enabled isolated Windows QA copy.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: Text('Verifying the Ryhze update installation')),
      ),
    ),
  );
  final updates = AppUpdates(
    currentBuild: const int.fromEnvironment(
      'RYHZE_TEST_INSTALLED_BUILD',
      defaultValue: 2,
    ),
  );
  await updates.check();
  await updates.download();
  if (updates.phase == UpdatePhase.ready) await updates.install();
  // A successful Windows handoff exits this process and reopens the installed
  // release. Returning here means the test did not complete.
  stderr.writeln(updates.error ?? 'No newer installable release was found.');
  exit(1);
}
