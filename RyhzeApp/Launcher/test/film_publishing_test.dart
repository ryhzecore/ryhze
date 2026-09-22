import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/admin_games.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets(
      'film editor adds imported playback and preserves kind at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final doc = {
          'id': 'film-test',
          'kind': 'film',
          'title': 'Test film',
          'visibility': 'internal',
          'availability': 'available',
          'streams': [],
          'seasons': [],
          'draftRevision': 1,
        };
        Map<String, dynamic>? saved;
        final state = await fixtureState(
          user: const Member('Leo', 'admin'),
          client: MockClient((r) async {
            final path = r.url.path;
            if (path.endsWith('/games')) {
              return http.Response(
                jsonEncode({
                  'games': [doc],
                  'drafts': [],
                }),
                200,
              );
            }
            if (path.endsWith('/games/film-test')) {
              return http.Response(
                jsonEncode({'draft': doc, 'published': doc}),
                200,
              );
            }
            if (path.endsWith('/imports')) {
              return http.Response(
                jsonEncode([
                  {
                    'id': 'job',
                    'state': 'ready',
                    'progress': 100,
                    'url': '/game-assets/11111111-1111-1111-1111-111111111111',
                  },
                ]),
                200,
              );
            }
            if (path.endsWith('/drafts')) {
              saved = jsonDecode(r.body)['document'];
              return http.Response(
                jsonEncode({
                  'draft': {...saved!, 'draftRevision': 2},
                  'published': doc,
                }),
                200,
              );
            }
            return http.Response('[]', 200);
          }),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: ryhzeTheme(),
            home: GamePublishingPage(
              state: state,
              gameId: 'film-test',
              kind: 'film',
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Streaming'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Use for playback'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Use for playback'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Save changes'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Save changes'));
        await tester.pumpAndSettle();
        expect(saved?['kind'], 'film');
        expect(
          (saved?['streams'] as List).single['url'],
          contains('/game-assets/'),
        );
        expect(saved?['seasons'], isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        state.dispose();
      },
    );
  }
}
