import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/artwork_hero.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/option_menu.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

void main() {
  setUpAll(() async {
    for (final font in [
      ('Inter', 'Inter'),
      ('Space Grotesk', 'SpaceGrotesk'),
      ('MaterialIcons', 'MaterialIcons-Regular'),
    ]) {
      await (FontLoader(font.$1)..addFont(
            rootBundle.load(
              font.$1 == 'MaterialIcons'
                  ? 'fonts/${font.$2}.otf'
                  : 'assets/fonts/${font.$2}.ttf',
            ),
          ))
          .load();
    }
  });
  for (final kind in ['game', 'film']) {
    testWidgets('$kind uses connected frame without fading its artwork', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final state = await fixtureState(
        user: const Member('List tester', 'admin'),
      );
      final title = RyhzeTitle(
        id: 'consistent-$kind',
        title: 'Consistent $kind',
        kind: kind,
        label: 'Ryhze',
        status: 'In development',
        description: 'Test',
        image: sample.image,
      );
      state.titles = [title];
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: RyhzeApp(state: state),
        ),
      );
      await tester.pumpAndSettle();
      if (kind == 'film') {
        await tester.tap(find.byKey(const ValueKey('browse-films')));
        await tester.pumpAndSettle();
      }
      final card = find.byKey(ValueKey('card-open-${title.id}'));
      await tester.ensureVisible(card);
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/art/san-coronado.png'),
          tester.element(card),
        ),
      );
      await tester.pump();
      await tester.tap(card);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.byType(GameFrameTransition), findsOneWidget);
      final art = find.byKey(const ValueKey('detail-artwork-section'));
      expect(art, findsOneWidget);
      expect(
        find.ancestor(of: art, matching: find.byType(DetailControlsReveal)),
        findsNothing,
      );
      await tester.runAsync(() => capture(key, '$kind-opening-0.1.9'));
      await tester.pumpAndSettle();
      final artworkFrame = find
          .descendant(of: art, matching: find.byType(AspectRatio))
          .first;
      final detailTitle = find.text(title.title).last;
      expect(
        tester.getTopLeft(artworkFrame).dx,
        closeTo(tester.getTopLeft(detailTitle).dx, .5),
        reason: 'Artwork and title share the detail gutter',
      );
      await tester.runAsync(() => capture(key, '$kind-open-0.1.9'));
      expect(find.byTooltip('Add to list'), findsOneWidget);
      await tester.tap(find.byTooltip('Add to list'));
      await tester.pumpAndSettle();
      expect(state.saved, contains(title.id));
      expect(find.byTooltip('Remove from list'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove from list'));
      await tester.pumpAndSettle();
      expect(state.saved, isNot(contains(title.id)));
      await tester.tap(find.text('Back').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      await tester.runAsync(() => capture(key, '$kind-closing-0.1.9'));
      await tester.pumpAndSettle();
      expect(find.byType(GameFrameTransition), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  testWidgets('options overlap their trigger and hover changes only text', (
    tester,
  ) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Scaffold(
          body: RepaintBoundary(
            key: key,
            child: Center(
              child: SizedBox(
                width: 250,
                child: RyhzeDropdown<String>(
                  value: 'All games',
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'All games',
                      child: Text('All games'),
                    ),
                    DropdownMenuItem(
                      value: 'Open world',
                      child: Text('Open world'),
                    ),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final trigger = tester.getRect(find.byType(RyhzeDropdown<String>));
    await tester.tap(find.byType(RyhzeDropdown<String>));
    await tester.pumpAndSettle();
    expect(
      tester
          .getRect(find.byType(RyhzeMenuItem<String>).first)
          .overlaps(trigger),
      isTrue,
    );
    final option = find.text('Open world');
    expect(DefaultTextStyle.of(tester.element(option)).style.color, muted);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(option));
    await tester.pumpAndSettle();
    expect(
      DefaultTextStyle.of(tester.element(option)).style.color,
      Colors.white,
    );
    expect(Theme.of(tester.element(option)).hoverColor, Colors.transparent);
    expect(Theme.of(tester.element(option)).highlightColor, Colors.transparent);
    await tester.runAsync(() => capture(key, 'options-hover-0.1.9'));
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });
}
