import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/admin_games.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';
import 'package:ryhze/ui/option_menu.dart';

void main() {
  for (final width in [390.0, 1280.0]) {
    testWidgets('publish defaults to latest build and can revert at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final doc = {
        'id': 'qa-game',
        'kind': 'game',
        'title': 'QA game',
        'visibility': 'internal',
        'availability': 'available',
        'categories': [],
        'facts': [],
        'screenshots': [],
        'releases': ['old'],
        'draftRevision': 1,
      };
      Map<String, dynamic>? submitted;
      final client = MockClient((r) async {
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
        if (path.endsWith('/games/qa-game')) {
          return http.Response(
            jsonEncode({'draft': doc, 'published': doc}),
            200,
          );
        }
        if (path.endsWith('/drafts')) {
          return http.Response(
            jsonEncode({
              'draft': {...doc, 'draftRevision': 2},
              'published': doc,
            }),
            200,
          );
        }
        if (path.endsWith('/releases')) {
          return http.Response(
            jsonEncode([
              {
                'id': 'new',
                'version': '1.1.0',
                'platform': 'windows',
                'state': 'verified',
              },
              {
                'id': 'old',
                'version': '1.0.0',
                'platform': 'windows',
                'state': 'verified',
              },
            ]),
            200,
          );
        }
        if (path.endsWith('/publish')) {
          submitted = jsonDecode(r.body);
          return http.Response('{}', 200);
        }
        if (path.startsWith('/api/admin/publishing/')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 200);
      });
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: client,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: GamePublishingPage(state: state, gameId: 'qa-game'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Review & publish'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Review & publish'));
      await tester.pumpAndSettle();
      expect(find.text('1.1.0 - Latest build'), findsOneWidget);
      final picker = find.ancestor(
        of: find.text('1.1.0 - Latest build'),
        matching: find.byType(RyhzeDropdown<String>),
      );
      await tester.ensureVisible(picker);
      await tester.tap(picker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.0.0').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Publish now'));
      await tester.pumpAndSettle();
      expect(submitted?['releaseIds'], ['old']);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  for (final width in [390.0, 1280.0]) {
    testWidgets('native publishing loads shared drafts and fits at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final document = {
        'id': 'qa-game',
        'kind': 'game',
        'title': 'QA draft',
        'label': 'Ryhze Games',
        'description': 'Unpublished description',
        'status': 'In development',
        'categories': ['Story'],
        'availability': 'coming-soon',
        'visibility': 'internal',
        'facts': [],
        'screenshots': [],
        'releases': [],
        'draftRevision': 2,
      };
      final client = MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        final p = r.url.path;
        if (p.endsWith('/games')) {
          return http.Response(
            jsonEncode({
              'games': [],
              'drafts': [document],
            }),
            200,
          );
        }
        if (p.endsWith('/games/qa-game')) {
          return http.Response(
            jsonEncode({'draft': document, 'published': null}),
            200,
          );
        }
        if (p.endsWith('/drafts')) {
          return http.Response(
            jsonEncode({
              'draft': {...jsonDecode(r.body)['document'], 'draftRevision': 3},
              'published': null,
            }),
            200,
          );
        }
        if (p.startsWith('/api/admin/publishing/')) {
          return http.Response('[]', 200);
        }
        return http.Response('{}', 200);
      });
      final state = await fixtureState(
        user: const Member('Leo', 'admin'),
        client: client,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: GamePublishingPage(state: state, gameId: 'qa-game'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('QA draft'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Media'));
      await tester.pumpAndSettle();
      expect(find.text('Upload cover'), findsOneWidget);
      expect(find.text('Add screenshot'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Save changes'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        calls.where((c) => c == 'POST /api/admin/publishing/drafts'),
        hasLength(1),
      );
      expect(
        calls.where(
          (c) => c.contains('/publish') && !c.contains('/publishing/'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      state.dispose();
    });
  }
}
