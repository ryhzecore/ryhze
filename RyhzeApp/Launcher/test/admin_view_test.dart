import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/admin_games.dart';
import 'support.dart';

void main() {
  testWidgets('invited developer sees Engine without administrator controls', (
    tester,
  ) async {
    final state = await fixtureState(
      user: const Member('invited-developer', 'viewer', developerAccess: true),
      adminAccess: false,
    );
    await tester.pumpWidget(RyhzeApp(state: state));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('browse-engine')), findsOneWidget);
    expect(state.engineAccess, isTrue);
    expect(state.publishingAccess, isFalse);
    await tester.tap(find.byKey(const ValueKey('browse-engine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('card-open-race-engine')), findsOneWidget);
    await tester.tap(find.byTooltip('Account and settings'));
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsNothing);
    expect(find.byKey(const ValueKey('admin-access-toggle')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  test(
    'normal view gates privileged access without deleting account data',
    () async {
      final state = await fixtureState(
        user: Member.fromJson({
          'username': 'Leo',
          'role': 'admin',
          'portalAccess': true,
          'developerAccess': true,
          'launcherAdmin': true,
        }),
      );
      state.titles.add(
        const RyhzeTitle(
          id: 'private',
          title: 'Private',
          kind: 'game',
          label: '',
          status: '',
          description: '',
          internal: true,
        ),
      );
      expect(state.engineAccess, true);
      expect(state.portalAccess, true);
      final count = state.titles.length;
      final pending = state.setAdminAccess(false);
      expect(state.engineAccess, false);
      expect(state.portalAccess, false);
      expect(state.publishingAccess, false);
      expect(state.visibleTitles.any((title) => title.internal), false);
      expect(state.titles.length, count);
      await pending;
      await state.setAdminAccess(true);
      expect(state.visibleTitles.length, count);
      state.user = Member.fromJson({
        'username': 'developer',
        'role': 'viewer',
        'developerAccess': true,
        'portalAccess': true,
      });
      expect(state.engineAccess, true);
      expect(state.portalAccess, true);
      expect(state.publishingAccess, false);
      state.dispose();
    },
  );
  testWidgets(
    'open publisher disappears immediately when admin mode is disabled',
    (tester) async {
      final state = await fixtureState(user: const Member('Leo', 'admin'));
      await tester.pumpWidget(
        MaterialApp(home: GamePublishingPage(state: state)),
      );
      await tester.pumpAndSettle();
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.text('Administrator access is off.'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );

  testWidgets(
    'admin menu defaults to normal view and reveals Publish only when enabled',
    (tester) async {
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        adminAccess: false,
      );
      expect(state.adminAccess, false);
      await tester.pumpWidget(RyhzeApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Publish'), findsNothing);
      expect(find.text('Normal user view'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-access-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-access-toggle')));
      await tester.pumpAndSettle();
      expect(state.adminAccess, true);
      expect(find.text('Publish'), findsOneWidget);
      expect(find.text('Manage members'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('admin-access-toggle')),
      );
      await tester.tap(find.byKey(const ValueKey('admin-access-toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Publish'), findsNothing);
      expect(state.user?.role, 'admin');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets('regular users have no admin view switch or Publish menu', (
    tester,
  ) async {
    final state = await fixtureState(user: const Member('viewer', 'viewer'));
    await state.setAdminAccess(true);
    expect(state.adminAccess, false);
    await tester.pumpWidget(RyhzeApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Account and settings'));
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsNothing);
    expect(find.byKey(const ValueKey('admin-access-toggle')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
}
