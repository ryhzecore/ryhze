import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import '../test/support.dart';
import '../test/website_parity_test.dart' show capture;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('approved Portal menu renders in the native app', (tester) async {
    MediaKit.ensureInitialized();
    final state = await fixtureState(
      user: const Member('Leo', 'admin', portalAccess: true),
      adminAccess: false,
    );
    await state.prefs.setBool('ambient-sound', false);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: RyhzeApp(state: state),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account and settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI'));
    expect(find.text('AI'), findsOneWidget);
    expect(find.text('Publish'), findsNothing);
    await capture(boundary, 'portal-native-menu');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
