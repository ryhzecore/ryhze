import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/state.dart';
import 'package:ryhze/main.dart';
import 'package:ryhze/ui/design.dart';
import 'package:ryhze/ui/shell.dart';
import 'support.dart';

class PendingWebsiteAuthenticator implements WebsiteAuthenticator {
  final callback = Completer<Uri>();
  bool started = false;
  @override
  bool get supported => true;
  @override
  Future<Uri> authenticate(Uri url) {
    started = true;
    return callback.future;
  }
}

void main() {
  testWidgets('first iOS launch opens website recognition and shows sign-in', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authenticator = PendingWebsiteAuthenticator();
    final api = RyhzeApi(
      store: MemorySession(),
      websiteAuthenticator: authenticator,
      client: MockClient((_) async => http.Response('{}', 500)),
    );
    final state = RyhzeState(
      api,
      await SharedPreferences.getInstance(),
      libraryAutoSync: false,
      featuredMotion: false,
    )
      ..loading = false
      ..titles = [sample];
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: RyhzeShell(state: state, initialSignIn: true),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Pill && widget.label.contains('Ryhze.com'),
      ),
      findsOneWidget,
    );
    expect(find.text('User ID'), findsOneWidget);
    expect(authenticator.started, isTrue);
    expect(state.prefs.getBool('website-sign-in-shown'), isTrue);
    authenticator.callback.complete(Uri.parse('ryhze://auth/callback?code=bad&state=bad'));
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    api.close();
  });
  testWidgets(
    'successful sign-in survives catalogue refresh and leaves the form',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final token = 'c' * 64;
      final sessionResponse = Completer<void>();
      final api = RyhzeApi(
        store: MemorySession(),
        client: MockClient((request) async {
          if (request.url.path == '/api/login') {
            final body = jsonDecode(request.body);
            expect(body['username'], 'fixture');
            expect(body['password'], 'fixture password');
            expect(body['remember'], true);
            return http.Response(
              '{"user":{"username":"fixture","role":"viewer"}}',
              200,
              headers: {
                'set-cookie':
                    '__Host-ryhze_session=$token; Path=/; Secure; HttpOnly',
              },
            );
          }
          expect(request.headers['Cookie'], '__Host-ryhze_session=$token');
          if (request.url.path == '/api/session') {
            await sessionResponse.future;
            return http.Response(
              '{"user":{"username":"fixture","role":"viewer"}}',
              200,
            );
          }
          if (request.url.path == '/api/catalog') {
            return http.Response('[]', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      final state = RyhzeState(api, await SharedPreferences.getInstance(), featuredMotion: false)
        ..loading = false
        ..titles = [sample];
      await tester.pumpWidget(RyhzeApp(state: state));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate(
          (widget) => widget is Pill && widget.label == 'Account and settings',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('expanding-surface')),
          matching: find.text('Sign in'),
        ),
      );
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'fixture');
      await tester.enterText(fields.at(1), 'fixture password');
      await tester.ensureVisible(find.text('Sign in').last);
      await tester.tap(find.text('Sign in').last);
      await tester.pump(const Duration(milliseconds: 100));
      sessionResponse.complete();
      await tester.pumpAndSettle();
      expect(state.user?.username, 'fixture');
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      api.close();
      state.dispose();
    },
  );
}
