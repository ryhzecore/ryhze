import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/portal.dart';
import '../test/native_ai_test.dart' show AiServer, owner;
import '../test/support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native AI history, tools, keyboard and access removal on device',
    (tester) async {
      final server = AiServer();
      final state = await fixtureState(user: owner, client: server.client);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: PortalPage(state: state),
        ),
      );
      await tester.pumpAndSettle();
      if (tester.view.physicalSize.width / tester.view.devicePixelRatio < 800) {
        await tester.tap(find.byTooltip('Conversations'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Release planning').first);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Check upgrades, account access and mobile layouts before publishing.',
        ),
        findsOneWidget,
      );
      for (final tab in [
        'Memory',
        'Sources',
        'Models',
        'Reports',
        'Knowledge',
      ]) {
        await tester.ensureVisible(find.text(tab).first);
        await tester.tap(find.text(tab).first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.drag(find.byType(ListView).first, const Offset(1200, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chat').first);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Message Gideon'),
        'Native device check',
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(server.submissions.length, 1);
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sign in with your approved account'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
