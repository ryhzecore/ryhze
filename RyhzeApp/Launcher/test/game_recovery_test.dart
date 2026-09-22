import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/game_library.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'missing installation and explicit repair preserve identity and added order',
    () async {
      SharedPreferences.setMockInitialValues({GameLibrary.permissionKey: true});
      final prefs = await SharedPreferences.getInstance();
      final folder = await Directory.systemTemp.createTemp(
        'ryhze-recovery-test-',
      );
      final added = DateTime(2025);
      final game = LocalGame(
        id: 'manual:stable',
        name: 'Example',
        source: 'Manual',
        root: '${folder.path}/missing',
        executable: '${folder.path}/missing/game.exe',
        addedAt: added,
      );
      final library = GameLibrary(
        prefs,
        autoPoll: false,
        processReader: () async => [],
      );
      library.games = [game];
      try {
        await library.refresh();
        expect(library.status(game), 'Missing installation');
        await expectLater(library.launchGame(game), throwsStateError);
        expect(library.busy, isEmpty);
        expect(library.launching, isEmpty);
        final executable = await File(
          '${folder.path}/selected.exe',
        ).writeAsBytes([0]);
        await library.addManual('Example', executable.path, previous: game);
        final repaired = library.games.single;
        expect(repaired.id, game.id);
        expect(repaired.addedAt, added);
        expect(repaired.executable, executable.path);
        await library.refresh();
        expect(library.missing, isEmpty);
      } finally {
        library.dispose();
        await folder.delete(recursive: true);
      }
    },
  );
}
