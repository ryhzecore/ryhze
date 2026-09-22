import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ryhze/core/updates.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/updates.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'production signed index, complete internet download and native update screen',
    (tester) async {
      final folder = await Directory(
        '${(await getTemporaryDirectory()).path}/ryhze-live-update-qa',
      ).create(recursive: true);
      final current = AppUpdates(directory: () async => folder);
      await current.check();
      expect(current.phase, UpdatePhase.current);
      current.dispose();
      var installRequests = 0;
      final updates = AppUpdates(
        currentBuild: 2,
        directory: () async => folder,
        installer: (file, release) async {
          expect(await file.length(), release.bytes);
          installRequests++;
          return 'Verified installation handoff';
        },
      );
      await updates.check();
      expect(updates.phase, UpdatePhase.available);
      expect(updates.release!.build, appBuild);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: Scaffold(body: UpdatePanel(updates: updates)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Download update'), findsOneWidget);
      await updates.download();
      expect(updates.phase, UpdatePhase.ready);
      await tester.pumpAndSettle();
      expect(
        find.text(
          Platform.isWindows ? 'Install and restart' : 'Install update',
        ),
        findsOneWidget,
      );
      await updates.install();
      expect(installRequests, 1);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      updates.dispose();
      await tester.pumpWidget(const SizedBox());
      await folder.delete(recursive: true);
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
