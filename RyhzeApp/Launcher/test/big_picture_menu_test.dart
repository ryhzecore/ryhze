import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ryhze/ui/big_picture.dart';
import 'website_parity_test.dart' show capture;
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/core/game_library.dart';
import 'package:ryhze/ui/shell.dart';
import 'package:ryhze/ui/personal_library.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/report_bug.dart';
import 'package:ryhze/ui/title_card.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'support.dart';
import 'big_picture_test.dart' show TestLibrary, controller;

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
  });
  testWidgets(
    'controller hover follows icon, text and toggle controls and clears on exit',
    (tester) async {
      final icon = FocusNode(), text = FocusNode(), toggle = FocusNode();
      addTearDown(icon.dispose);
      addTearDown(text.dispose);
      addTearDown(toggle.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: BigPicture(
            onExit: () {},
            child: Scaffold(
              body: Column(
                children: [
                  IconButton(
                    key: const ValueKey('icon'),
                    focusNode: icon,
                    onPressed: () {},
                    icon: const Icon(Icons.search),
                  ),
                  Transform.scale(
                    scale: 1.15,
                    child: TextButton(
                      key: const ValueKey('text'),
                      focusNode: text,
                      onPressed: () {},
                      child: const Text('Report Bug'),
                    ),
                  ),
                  SwitchListTile(
                    key: const ValueKey('toggle'),
                    focusNode: toggle,
                    value: false,
                    onChanged: (_) {},
                    title: const Text('Ambient sound'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      for (final control in [
        (icon, 'icon'),
        (text, 'text'),
        (toggle, 'toggle'),
      ]) {
        control.$1.requestFocus();
        await tester.pumpAndSettle();
        final ring = find.byKey(const ValueKey('controller-selection-hover'));
        expect(ring, findsOneWidget);
        if (control.$2 == 'text') {
          expect(
            tester.getSize(ring).width,
            closeTo(
              tester.getRect(find.byKey(const ValueKey('text'))).width,
              .01,
            ),
          );
        }
        expect(
          tester
              .getRect(ring)
              .contains(tester.getCenter(find.byKey(ValueKey(control.$2)))),
          isTrue,
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('controller-selection-hover')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Big Picture card uses hover lift without an outline and keeps regular focus',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState();
      addTearDown(state.dispose);
      for (final full in [true, false]) {
        final screenshot = GlobalKey();
        final card = Center(
          child: SizedBox(
            width: 340,
            child: RyhzeTitleCard(
              title: sample,
              state: state,
              onOpen: () {},
              onSave: () {},
              artwork: const ColoredBox(color: Color(0xff22192f)),
            ),
          ),
        );
        await tester.pumpWidget(
          RepaintBoundary(
            key: screenshot,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ryhzeTheme(),
              home: Scaffold(
                body: full ? BigPicture(onExit: () {}, child: card) : card,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final artwork = find.byKey(ValueKey('card-open-${sample.id}'));
        // Native Windows retains pointer highlight mode after earlier taps.
        // Exercise keyboard mode before checking its visible focus border.
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        tester.widget<InkWell>(artwork).focusNode!.requestFocus();
        await tester.pumpAndSettle();
        final frame = tester
            .widgetList<Container>(
              find.descendant(of: artwork, matching: find.byType(Container)),
            )
            .map((w) => w.foregroundDecoration)
            .whereType<ShapeDecoration>()
            .single;
        final nativeBorder = frame.shape as RoundedSuperellipseBorder;
        expect(
          nativeBorder.side.color,
          full ? const Color(0x1affffff) : Colors.white,
        );
        final ring = find.byKey(const ValueKey('controller-selection-hover'));
        expect(ring, findsNothing);
        if (full) {
          final lift = tester.widget<AnimatedContainer>(
            find.byKey(ValueKey('card-lift-${sample.id}')),
          );
          expect(lift.transform!.getTranslation().y, -3);
          expect(
            tester
                .widget<AnimatedScale>(
                  find.byKey(ValueKey('card-scale-${sample.id}')),
                )
                .scale,
            1.025,
          );
          await tester.runAsync(
            () => capture(screenshot, 'steamdeck-card-hover-focus'),
          );
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
  testWidgets('category options use text hover on controller focus', (
    tester,
  ) async {
    String selected = 'all';
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: BigPicture(
          onExit: () {},
          child: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: RyhzeDropdown<String>(
                  value: selected,
                  onChanged: (value) => selected = value!,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All games')),
                    DropdownMenuItem(value: 'action', child: Text('Action')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('All games'));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('controller-selection-ring')),
      findsNothing,
    );
    expect(
      tester
          .widget<AnimatedDefaultTextStyle>(
            find.byKey(const ValueKey('menu-option-action')),
          )
          .style
          .color,
      Colors.white,
    );
    expect(
      find.byKey(const ValueKey('controller-selection-hover')),
      findsNothing,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(selected, 'action');
    expect(tester.takeException(), isNull);
  });
  for (final full in [true, false]) {
    testWidgets('settings sign out visibility with Big Picture $full', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState(user: const Member('player', 'viewer'));
      addTearDown(state.dispose);
      await state.prefs.setBool('ambient-sound', false);
      await state.prefs.setBool(GameLibrary.permissionKey, true);
      final library = TestLibrary(state.prefs);
      library.games = [
        LocalGame(id: 'one', name: 'One', source: 'Manual', root: '/games/one'),
      ];
      final screenshot = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: screenshot,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ryhzeTheme(),
            home: RyhzeShell(
              state: state,
              gameLibrary: library,
              initialBigPicture: full,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Account and settings'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), full ? findsNothing : findsOneWidget);
      expect(state.user?.username, 'player');
      expect(
        find.ancestor(
          of: find.text('Ryhze home'),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Our story'),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
      expect(
        find.ancestor(
          of: find.text('Get in touch'),
          matching: find.byType(ListTile),
        ),
        findsNothing,
      );
      expect(find.text('Report Bug'), findsOneWidget);
      expect(find.text('Ambient sound'), findsOneWidget);
      if (full) {
        expect(
          find.byKey(const ValueKey('controller-selection-hover')),
          findsNothing,
        );
        final selectedText = tester.widget<AnimatedDefaultTextStyle>(
          find
              .ancestor(
                of: find.text('Games Library'),
                matching: find.byType(AnimatedDefaultTextStyle),
              )
              .first,
        );
        expect(selectedText.style.fontWeight, FontWeight.w600);
        expect(selectedText.style.color, const Color(0xffd6c3ff));
        await tester.runAsync(
          () => capture(screenshot, 'steamdeck-controller-settings'),
        );
      }
      await tester.ensureVisible(find.text('Report Bug'));
      await tester.tap(find.text('Report Bug'));
      await tester.pumpAndSettle();
      expect(find.byType(ReportBugPanel), findsOneWidget);
      expect(find.text('support@ryhze.com'), findsOneWidget);
      expect(find.text('Open email'), findsOneWidget);
      if (full) {
        await tester.runAsync(
          () => capture(screenshot, 'steamdeck-report-bug'),
        );
      }
      if (full) {
        expect(
          find.byKey(const ValueKey('controller-selection-hover')),
          findsOneWidget,
        );
        await controller(tester, 'back');
      } else {
        await tester.tap(find.byTooltip('Close bug report'));
        await tester.pumpAndSettle();
      }
      expect(find.byType(ReportBugPanel), findsNothing);
      await tester.tap(find.byTooltip('Account and settings'));
      await tester.pumpAndSettle();
      if (full) {
        await controller(tester, 'select');
        expect(find.text('Welcome, player'), findsNothing);
        expect(find.byType(PersonalLibrary), findsOneWidget);
        await controller(tester, 'back');
        expect(find.byType(PersonalLibrary), findsNothing);
        expect(find.text('Leave Big Picture?'), findsNothing);
        await controller(tester, 'back');
        expect(find.text('Leave Big Picture?'), findsOneWidget);
        await tester.tap(find.text('Keep playing'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
