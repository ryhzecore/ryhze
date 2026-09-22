import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ryhze/core/agreement.dart';
import 'package:ryhze/core/api.dart';
import 'package:ryhze/core/state.dart';
import 'package:ryhze/ui/agreement_dialog.dart';
import 'package:ryhze/ui/design.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support.dart';

final longText = List.generate(
  60,
  (i) => 'Clause ${i + 1}. Pre-release software has bugs and this line is long enough to wrap.',
).join('\n');
Map<String, dynamic> served(String text) => {
  'key': 'app-tester',
  'id': 'RYHZE-TESTER-1.0',
  'title': 'Ryhze Pre-Release Tester Agreement',
  'revision': '2026-10-01-final',
  'effectiveDate': '2026-10-01',
  'sha256': sha256.convert(utf8.encode(text)).toString(),
  'text': text,
  'url': 'https://ryhze.com/licence/app',
};

Future<RyhzeState> stateWith({int agreementStatus = 200, String? text}) async {
  SharedPreferences.setMockInitialValues({});
  final body = served(text ?? longText);
  final state = RyhzeState(
    RyhzeApi(
      client: MockClient((r) async {
        if (r.url.path == '/api/session') {
          // Like the real server: no session cookie after sign-out, no user.
          return r.headers.containsKey('cookie')
              ? http.Response(jsonEncode({'user': {'username': 'Tess', 'role': 'viewer', 'appTesterAccess': true}}), 200)
              : http.Response(jsonEncode({'error': 'Sign in required.'}), 401);
        }
        if (r.url.path == '/api/legal/agreement') {
          return agreementStatus == 200
              ? http.Response(jsonEncode(body), 200)
              : http.Response(jsonEncode({'error': 'Legal documents are being finalised.'}), agreementStatus);
        }
        if (r.url.path == '/api/legal/accept') return http.Response('{"ok":true}', 200);
        if (r.url.path == '/api/logout') return http.Response('{"ok":true}', 200);
        if (r.url.path == '/api/catalog') return http.Response('[]', 200);
        if (r.url.path == '/api/library') return http.Response(jsonEncode({'schema': 1, 'revision': 0, 'entries': {}}), 200);
        return http.Response(jsonEncode({'error': 'Sign in required.'}), 401);
      }),
      store: MemorySession()
        ..value = jsonEncode({
          'origin': 'https://ryhze.com',
          'expires': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
          'token': 'a' * 64,
        }),
    ),
    await SharedPreferences.getInstance(),
    libraryAutoSync: false,
    featuredMotion: false,
  );
  // What initialize() does on a real launch: pick up the stored session.
  await state.api.restore();
  return state;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an agreement is only accepted from the website when its hash matches its text', () {
    expect(Agreement.parse(served('Some agreement text.'))?.id, 'RYHZE-TESTER-1.0');
    expect(Agreement.parse({...served('Some agreement text.'), 'sha256': 'f' * 64}), isNull);
    expect(Agreement.parse({...served('Some agreement text.'), 'text': ''}), isNull);
    expect(Agreement.parse({...served('x'), 'url': 'http://example.com'}), isNull);
    expect(Agreement.parse({...served('x'), 'id': 'lowercase'}), isNull);
    expect(Agreement.parse('nonsense'), isNull);
  });

  test('acceptance is remembered per account and per exact text', () async {
    SharedPreferences.setMockInitialValues({});
    final records = AgreementRecords(await SharedPreferences.getInstance());
    final first = Agreement.parse(served('Version one.'))!;
    final second = Agreement.parse(served('Version two.'))!;
    expect(records.accepted('tess', first), isFalse);
    await records.record('tess', first);
    expect(records.accepted('tess', first), isTrue);
    expect(records.accepted('tess', second), isFalse, reason: 'a changed text is a new agreement');
    expect(records.accepted('someone-else', first), isFalse, reason: 'another account on the same device is asked in their own right');
    await records.record('tess', second);
    expect(records.accepted('tess', second), isTrue);
    expect(records.accepted('tess', first), isFalse, reason: 'only the current text counts');
  });

  test('signing in surfaces the agreement in force; accepting stores it and clears the gate', () async {
    final state = await stateWith();
    await state.refresh();
    expect(state.user?.username, 'Tess');
    expect(state.pendingAgreement?.id, 'RYHZE-TESTER-1.0');
    await state.acceptAgreement();
    expect(state.pendingAgreement, isNull);
    expect(state.agreements.accepted('Tess', Agreement.parse(served(longText))!), isTrue);
    await state.refresh();
    expect(state.pendingAgreement, isNull, reason: 'accepted once on this device');
    state.dispose();
  });

  test('while the website still serves drafts (503) nobody is asked to accept anything', () async {
    final state = await stateWith(agreementStatus: 503);
    await state.refresh();
    expect(state.user, isNotNull);
    expect(state.pendingAgreement, isNull);
    state.dispose();
  });

  test('declining signs the person out', () async {
    final state = await stateWith();
    await state.refresh();
    expect(state.pendingAgreement, isNotNull);
    await state.declineAgreement();
    expect(state.pendingAgreement, isNull);
    expect(state.user, isNull);
    state.dispose();
  });

  testWidgets('the dialog enables agreement only after reading to the end and ticking the box', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Builder(
          builder: (context) => Center(
            child: Pill(
              'Open',
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => AgreementDialog(
                    title: 'Ryhze Pre-Release Tester Agreement',
                    text: List.filled(400, 'line').join('\n'),
                    confirmLabel: 'Agree and continue',
                    cancelLabel: 'Sign out',
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('agreement-confirm'));
    expect(tester.widget<Pill>(confirm).onPressed, isNull, reason: 'nothing read yet');
    expect(tester.widget<CheckboxListTile>(find.byKey(const ValueKey('agreement-checkbox'))).onChanged, isNull);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    scroll.position.jumpTo(scroll.position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(tester.widget<Pill>(confirm).onPressed, isNull, reason: 'reaching the end never ticks the box');
    await tester.tap(find.byKey(const ValueKey('agreement-checkbox')));
    await tester.pumpAndSettle();
    expect(tester.widget<Pill>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('cancelling returns false and never counts as acceptance', (tester) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ryhzeTheme(),
        home: Builder(
          builder: (context) => Center(
            child: Pill(
              'Open',
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const AgreementDialog(title: 'T', text: 'short text'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('agreement-cancel')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
