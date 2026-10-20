import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:racetechph/pages/forgot_password_page.dart';
import 'package:racetechph/pages/login_page.dart';
import 'package:racetechph/pages/signup_page2.dart';
import 'package:racetechph/profile/edit_password.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/utils/password_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _password = ' TrailRunner!2026 ';
const _serverErrors = [
  'The given password has appeared in a data leak. Please choose a different password.',
  'Please choose another password that meets the requirements.',
];

// Keep email/code delivery local; exercise the real reset API and parser.
class _ResetApi extends ApiService {
  _ResetApi(http.Client client) : super(profileClient: client);

  @override
  Future<ForgotPasswordResult> forgotPassword(String email) async =>
      ForgotPasswordResult.success;

  @override
  Future<VerifyResetCodeResult> verifyResetCode({
    required String email,
    required String code,
  }) async => VerifyResetCodeResult.success;
}

Future<void> _enter(WidgetTester tester, int index, String value) async {
  final field = find.byType(TextField).at(index);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text) async {
  final button = find.text(text);
  // The reset flow shows transient delivery/verification snackbars. Dismiss
  // those before tapping a button that can sit behind the floating message.
  ScaffoldMessenger.of(tester.element(button)).clearSnackBars();
  await tester.pumpAndSettle();
  await Scrollable.ensureVisible(tester.element(button), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'token': 'test-token'}));

  for (final flow in ['signup', 'change', 'reset']) {
    testWidgets(
      '$flow validates, preserves passwords, and shows all server errors',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final requests = <http.Request>[];
        final client = MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'message': 'The password is invalid. (and 1 more error)',
              'errors': {'password': _serverErrors},
            }),
            422,
          );
        });
        addTearDown(client.close);
        final api = ApiService(profileClient: client);
        final Widget page;
        if (flow == 'signup') {
          page = SignUpPage2(
            firstName: 'Juan',
            lastName: 'Cruz',
            gender: 'Male',
            birthday: '2000-01-01',
            apiService: api,
          );
        } else if (flow == 'change') {
          page = EditPasswordPage(apiService: api);
        } else {
          page = ForgotPasswordPage(apiService: _ResetApi(client));
        }
        await tester.pumpWidget(MaterialApp(home: page));
        await tester.pumpAndSettle();

        if (flow == 'reset') {
          await _enter(tester, 0, 'test@example.com');
          await _tap(tester, 'Send Reset Code');
          await _enter(tester, 0, '123456');
          expect(find.text('New password'), findsOneWidget);
        } else {
          await _enter(
            tester,
            0,
            flow == 'signup' ? 'test@example.com' : ' old ',
          );
        }
        final passwordIndex = flow == 'reset' ? 0 : 1;
        final confirmIndex = passwordIndex + 1;
        final submit = flow == 'signup' ? 'Create Account' : 'Update Password';

        await _enter(tester, passwordIndex, 'short');
        await _enter(tester, confirmIndex, 'short');
        await _tap(tester, submit);
        expect(requests, isEmpty);
        expect(find.text(passwordRequirementsMessage), findsWidgets);
        final passwordField = tester.widget<TextField>(
          find.byType(TextField).at(passwordIndex),
        );
        expect(
          (passwordField.decoration!.error as Text).data,
          passwordRequirementsMessage,
        );

        await _enter(tester, passwordIndex, _password);
        await _enter(tester, confirmIndex, _password.trim());
        await _tap(tester, submit);
        expect(
          requests,
          isEmpty,
          reason: 'Confirmation must match exactly, including spaces.',
        );
        await _enter(tester, confirmIndex, _password);

        final toggle = find
            .byTooltip('Show password')
            .at(flow == 'change' ? 1 : 0);
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(passwordIndex))
              .controller!
              .text,
          _password,
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(passwordIndex))
              .obscureText,
          isFalse,
        );

        await _tap(tester, submit);
        expect(requests, hasLength(1));
        expect(requests.single.bodyFields['password'], _password);
        expect(requests.single.bodyFields['password_confirmation'], _password);
        if (flow == 'change') {
          expect(requests.single.bodyFields['current_password'], ' old ');
        }
        if (flow == 'reset') {
          expect(requests.single.bodyFields['email'], 'test@example.com');
          expect(requests.single.bodyFields['code'], '123456');
          expect(find.text('New password'), findsOneWidget);
        }
        expect(find.text(_serverErrors.join('\n')), findsOneWidget);
        final hideToggle = find.byTooltip('Hide password').first;
        await tester.ensureVisible(hideToggle);
        await tester.tap(hideToggle);
        await tester.pumpAndSettle();
        expect(
          find.text(_serverErrors.join('\n')),
          findsOneWidget,
          reason:
              'Visibility changes must not discard authoritative server errors.',
        );
        expect(
          tester
              .widget<TextField>(find.byType(TextField).at(passwordIndex))
              .controller!
              .text,
          _password,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('login still submits an existing weak password unchanged', (
    tester,
  ) async {
    String? sentPassword;
    final client = MockClient((request) async {
      sentPassword = request.bodyFields['password'];
      return http.Response('{}', 401);
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: LoginPage(apiService: ApiService(profileClient: client)),
      ),
    );
    await _enter(tester, 0, 'test@example.com');
    await _enter(tester, 1, ' old ');
    await _tap(tester, 'Sign in');
    expect(sentPassword, ' old ');
    expect(find.text(passwordRequirementsMessage), findsNothing);
    expect(find.text('Invalid email or password'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
