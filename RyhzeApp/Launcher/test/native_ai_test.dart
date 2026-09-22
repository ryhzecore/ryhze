import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/ai.dart';
import 'package:ryhze/core/models.dart';
import 'package:ryhze/ui/portal.dart';
import 'package:ryhze/ui/design.dart';
import 'support.dart';
import 'website_parity_test.dart' show capture;

final owner = Member.fromJson({
  'username': 'Leo',
  'role': 'admin',
  'portalAccess': true,
});

class AiServer {
  final paths = <String>[], submissions = <AiObject>[];
  bool failed = false, done = false, memoryConflict = false;
  int status = 200, polls = 0, creates = 0;
  Completer<void>? gate;
  AiObject chat = {
    'id': 'a1',
    'title': 'Release planning',
    'project': '',
    'archived': 0,
    'messages': [
      {
        'id': 'u1',
        'role': 'user',
        'content': 'What should we validate?',
        'status': 'done',
        'request_id': 'prior',
        'sources': [],
      },
      {
        'id': 'm1',
        'role': 'assistant',
        'content':
            'Check upgrades, account access and mobile layouts before publishing.',
        'status': 'done',
        'request_id': 'prior',
        'sources': [
          {
            'number': 1,
            'title': 'Release checklist',
            'source': 'Workspace notes',
            'excerpt': 'Preserve user data during upgrades.',
          },
        ],
      },
    ],
  };
  AiObject get run => {
    'id': 'r1',
    'status': done ? 'done' : 'running',
    'partial': 'Checking the release checklist…',
  };
  late final client = MockClient((r) async {
    paths.add(r.url.path);
    expectSync(r.url.path.startsWith('/portal/internal-api/'), isTrue);
    expectSync(r.headers['Origin'], 'https://ryhze.com');
    dynamic value;
    final p = r.url.path.replaceFirst('/portal/internal-api', '');
    if (status != 200) {
      return http.Response(jsonEncode({'error': 'Session ended'}), status);
    }
    switch (p) {
      case '/ai/chats':
        if (r.method == 'POST') {
          creates++;
          await gate?.future;
          value = chat;
        } else {
          value = [chat];
        }
      case '/records/project':
        value = [
          {'id': 'p1', 'title': 'Ryhze App'},
        ];
      case '/ai-status':
        value = {'online': true};
      case '/ai/gemini':
        value = {'configured': false, 'assisting': false};
      case '/ai/chats/a1':
        if (r.method == 'POST') {
          chat = {...chat, ...aiObject(jsonDecode(r.body))};
        }
        value = {...chat, if (submissions.isNotEmpty && !done) 'run': run};
      case '/ai/chats/a1/runs':
        submissions.add(aiObject(jsonDecode(r.body)));
        if (failed) throw http.ClientException('Connection lost');
        value = run;
      case '/ai/runs/r1':
        polls++;
        value = run;
      case '/ai/memories':
        if (r.method == 'POST' && memoryConflict) {
          return http.Response(
            jsonEncode({
              'error': 'This memory changed. Reopen it before saving.',
            }),
            409,
          );
        }
        value = r.method == 'GET'
            ? [
                {
                  'id': 'memory1',
                  'content': 'Preserve artwork ratios.',
                  'category': 'preference',
                  'project': '',
                  'revision': 1,
                  'archived': 0,
                },
              ]
            : {};
      case '/ai/learning':
        value = {
          'files': {
            'memory': {
              'content': 'Verify before release.',
              'revision': 'v1',
              'limit': 12000,
              'history': [],
            },
          },
          'skills': [],
        };
      case '/ai/sources':
        value = {'documents': [], 'localRoots': []};
      case '/ai/performance-reports':
        value = {'reports': [], 'nextCursor': null};
      case '/ai/graph':
        value = {
          'nodes': [
            {
              'id': 'memory1',
              'label': 'Preserve artwork ratios',
              'kind': 'memory',
            },
          ],
          'edges': [],
        };
      default:
        throw StateError('Unexpected native request $p');
    }
    return http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
    'lost submission reuses its ID; duplicate clicks and hidden polling are prevented',
    (tester) async {
      final server = AiServer()..failed = true;
      final state = await fixtureState(user: owner, client: server.client);
      final ai = RyhzeAi(state);
      await ai.refresh();
      expect(await ai.send('Plan the release'), isFalse);
      final id = server.submissions.single['requestId'];
      server.failed = false;
      final first = ai.send('Plan the release');
      expect(await ai.send('Plan the release'), isFalse);
      expect(await first, isTrue, reason: ai.error);
      expect(server.creates, 1);
      expect(server.submissions.length, 2);
      expect(server.submissions.last['requestId'], id);
      expect(ai.running, isTrue, reason: '${ai.run} ${ai.error}');
      ai.setVisible(false);
      await tester.pump(const Duration(seconds: 10));
      expect(server.polls, 0);
      ai.setVisible(true);
      await tester.pump(const Duration(milliseconds: 2));
      await tester.pump();
      expect(
        server.polls,
        1,
        reason: '${ai.run} ${ai.allowed} ${ai.error} ${server.paths}',
      );
      server.done = true;
      await tester.pump(const Duration(seconds: 1));
      expect(ai.running, isFalse);
      final count = server.polls;
      await tester.pump(const Duration(seconds: 10));
      expect(server.polls, count);
      ai.dispose();
      state.dispose();
    },
  );
  testWidgets(
    'account loss during chat creation discards the response and stops submission',
    (tester) async {
      final server = AiServer()..gate = Completer<void>();
      final state = await fixtureState(user: owner, client: server.client);
      final ai = RyhzeAi(state);
      await ai.refresh();
      final sending = ai.send('Private question');
      await tester.pump();
      await state.setAdminAccess(false);
      server.gate!.complete();
      expect(await sending, isFalse);
      expect(ai.allowed, isFalse);
      expect(ai.chat, isNull);
      expect(ai.chats, isEmpty);
      expect(server.submissions, isEmpty);
      ai.dispose();
      state.dispose();
    },
  );
  testWidgets('expired and forbidden sessions clear already loaded AI data', (
    tester,
  ) async {
    for (final status in [401, 403]) {
      final server = AiServer();
      final state = await fixtureState(user: owner, client: server.client);
      final ai = RyhzeAi(state);
      await ai.refresh();
      expect(ai.chats, isNotEmpty);
      server.status = status;
      await ai.refresh();
      expect(ai.allowed, isFalse);
      expect(ai.chats, isEmpty);
      ai.dispose();
      state.dispose();
    }
  });
  testWidgets(
    'rapid conversation changes ignore late responses and another approved account sees no prior data',
    (tester) async {
      final delayed = Completer<http.Response>();
      final client = MockClient(
        (r) async => r.url.path.endsWith('/first')
            ? delayed.future
            : http.Response(
                jsonEncode({
                  'id': 'second',
                  'title': 'Second conversation',
                  'messages': [],
                }),
                200,
              ),
      );
      final state = await fixtureState(user: owner, client: client);
      final ai = RyhzeAi(state);
      final first = ai.open('first');
      await ai.open('second');
      delayed.complete(
        http.Response(
          jsonEncode({
            'id': 'first',
            'title': 'Late conversation',
            'messages': [],
          }),
          200,
        ),
      );
      await first;
      expect(ai.chat?['id'], 'second');
      state.user = Member.fromJson({
        'username': 'Another',
        'role': 'admin',
        'portalAccess': true,
      });
      state.notifyListeners();
      expect(ai.allowed, isFalse);
      expect(ai.chat, isNull);
      ai.dispose();
      state.dispose();
    },
  );
  for (final size in [
    const Size(320, 740),
    const Size(390, 844),
    const Size(1280, 900),
  ]) {
    testWidgets('native AI screens, history and keyboard at ${size.width}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final server = AiServer(), boundary = GlobalKey();
      final state = await fixtureState(user: owner, client: server.client);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: RepaintBoundary(
            key: boundary,
            child: PortalPage(state: state),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('What are we working on?'), findsOneWidget);
      expect(
        server.paths.length,
        4,
      ); // No hidden tools, HTML, embed tickets or 3D graph.
      if (size.width < 800) {
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
      expect(tester.takeException(), isNull);
      await tester.runAsync(
        () => capture(boundary, 'native-ai-chat-${size.width.toInt()}'),
      );
      for (final tab in [
        'Memory',
        'Sources',
        'Models',
        'Reports',
        'Knowledge',
      ]) {
        final target = find.text(tab).first;
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (tab == 'Memory' || tab == 'Models') {
          await tester.runAsync(
            () => capture(
              boundary,
              'native-ai-${tab.toLowerCase()}-${size.width.toInt()}',
            ),
          );
        }
      }
      await tester.drag(find.byType(ListView).first, const Offset(1000, 0));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Chat').first);
      await tester.tap(find.text('Chat').first);
      await tester.pumpAndSettle();
      final field = find.widgetWithText(TextField, 'Message Gideon');
      await tester.enterText(field, 'A native message');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(server.submissions.length, 1);
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Sign in with your approved account'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Check upgrades, account access and mobile layouts before publishing.',
        ),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    });
  }
  testWidgets(
    'memory conflict preserves draft and account change hides an open editor',
    (tester) async {
      final server = AiServer()..memoryConflict = true;
      final state = await fixtureState(user: owner, client: server.client);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          home: PortalPage(state: state),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Memory').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Add memory'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Add memory'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Memory'),
        'Keep this unsaved draft',
      );
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(find.text('Keep this unsaved draft'), findsOneWidget);
      expect(
        find.text('This memory changed. Reopen it before saving.'),
        findsOneWidget,
      );
      await state.setAdminAccess(false);
      await tester.pumpAndSettle();
      expect(find.text('Keep this unsaved draft'), findsNothing);
      expect(find.text('AI access ended'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
  testWidgets(
    'small screen keeps a multiline composer usable with the keyboard and reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final server = AiServer();
      final state = await fixtureState(user: owner, client: server.client);
      await tester.pumpWidget(
        MaterialApp(
          theme: ryhzeTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: true,
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: PortalPage(state: state),
        ),
      );
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      await tester.pump();
      await tester.enterText(
        find.widgetWithText(TextField, 'Message Gideon'),
        'First line\nSecond line\nThird line\nFourth line',
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Send message'));
      await tester.pump();
      expect(server.submissions.length, 1);
      await tester.pumpWidget(const SizedBox());
      state.dispose();
    },
  );
}
