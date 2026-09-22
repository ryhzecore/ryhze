import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ryhze/ui/big_picture.dart';
import 'package:ryhze/ui/game_shelf.dart';

void main() {
  for (final controllerFirst in [true, false]) {
    testWidgets(
      'one step for paired input, controller first: $controllerFirst',
      (tester) async {
        final nodes = <FocusNode>[];
        await tester.pumpWidget(
          MaterialApp(
            home: BigPicture(
              onExit: () {},
              child: Scaffold(
                body: GameShelf(
                  children: [
                    for (var i = 0; i < 6; i++)
                      Builder(
                        key: ValueKey(i),
                        builder: (context) {
                          final item = GameShelfItem.maybeOf(context)!;
                          if (!nodes.contains(item.focusNode)) {
                            nodes.add(item.focusNode);
                          }
                          return TextButton(
                            focusNode: item.focusNode,
                            onPressed: () {},
                            child: Text('Game $i'),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(nodes[0].hasPrimaryFocus, true);
        Future<void> native() async {
          tester.binding.channelBuffers.push(
            'ryhze/desktop',
            const StandardMethodCodec().encodeMethodCall(
              const MethodCall('controller', 'right'),
            ),
            (_) {},
          );
          await tester.pump();
        }

        Future<void> keyboard() async {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
        }

        if (controllerFirst) {
          await native();
          await keyboard();
        } else {
          await keyboard();
          await native();
        }
        expect(nodes[1].hasPrimaryFocus, true);
        // A separate rapid press from the winning source is still one more step.
        if (controllerFirst) {
          await native();
        } else {
          await keyboard();
        }
        expect(nodes[2].hasPrimaryFocus, true);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Next game'));
        await tester.pumpAndSettle();
        expect(nodes[3].hasPrimaryFocus, true);
        FocusNode footerFocus(String label, IconData icon) => Focus.of(
          tester.element(
            find.descendant(
              of: find.byTooltip(label),
              matching: find.byIcon(icon),
            ),
          ),
        );
        final previous = footerFocus('Previous game', Icons.chevron_left);
        footerFocus('Next game', Icons.chevron_right).requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(previous.hasPrimaryFocus, true);
        expect(nodes.any((node) => node.hasPrimaryFocus), false);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('horizontal game selection does not move the page vertically', (
    tester,
  ) async {
    final outer = ScrollController();
    addTearDown(outer.dispose);
    final nodes = <FocusNode>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            controller: outer,
            child: Column(
              children: [
                const SizedBox(height: 160),
                GameShelf(
                  children: [
                    for (var i = 0; i < 8; i++)
                      Builder(
                        key: ValueKey(i),
                        builder: (context) {
                          final focus = GameShelfItem.maybeOf(
                            context,
                          )!.focusNode;
                          if (!nodes.contains(focus)) {
                            nodes.add(focus);
                          }
                          return TextButton(
                            focusNode: focus,
                            onPressed: () {},
                            child: Text('Game $i'),
                          );
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(outer.offset, 0);
    nodes[6].requestFocus();
    await tester.pumpAndSettle();
    expect(outer.offset, 0);
    expect(nodes[6].hasPrimaryFocus, true);
  });
}
