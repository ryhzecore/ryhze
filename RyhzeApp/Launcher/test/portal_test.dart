import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'support.dart';

void main() {
  for (final member in [
    Member.fromJson({'username': 'Leo', 'role': 'admin', 'portalAccess': true}),
    const Member('Leo', 'admin'),
    const Member('Andru', 'admin'),
    const Member('viewer', 'viewer'),
  ]) {
    testWidgets(
      'Portal menu follows authenticated access for ${member.username}: ${member.portalAccess}',
      (tester) async {
        final state = await fixtureState(user: member, adminAccess: false);
        await tester.pumpWidget(RyhzeApp(state: state));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Account and settings'));
        await tester.pumpAndSettle();
        expect(
          find.text('AI'),
          state.portalAccess ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
