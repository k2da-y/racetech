import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racetechph/services/api_service.dart';

Future<ApiActionResult> signup(
  ApiService api,
  String password,
  String confirmation,
) => api.register(
  firstName: 'Juan',
  lastName: 'Cruz',
  gender: 'Male',
  birthday: '2000-01-01',
  email: 'test@example.com',
  password: password,
  passwordConfirmation: confirmation,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'token': 'test-token'}));
  test('valid new passwords still complete all three API operations', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({'message': 'Saved successfully.'}),
        request.url.path.endsWith('/register') ? 201 : 200,
      ),
    );
    addTearDown(client.close);
    final api = ApiService(profileClient: client);
    const password = 'TrailRunner!2026';
    final results = [
      await signup(api, password, password),
      await api.changePassword(
        currentPassword: 'old',
        newPassword: password,
        passwordConfirmation: password,
      ),
      await api.resetPassword(
        email: 'test@example.com',
        code: '123456',
        password: password,
        passwordConfirmation: password,
      ),
    ];
    for (final result in results) {
      expect(result.success, isTrue);
      expect(result.message, 'Saved successfully.');
      expect(result.fieldErrors, isEmpty);
    }
  });
  test(
    'all new-password APIs preserve values and retain the complete errors.password list',
    () async {
      const password = ' TrailRunner!2026 ';
      const errors = [
        'First password rule failed.',
        'The password appeared in a data leak.',
      ];
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.bodyFields['password'], password);
        expect(request.bodyFields['password_confirmation'], password);
        if (request.method == 'PATCH') {
          expect(request.bodyFields['current_password'], ' old ');
        }
        if (request.url.path.endsWith('reset-password')) {
          expect(request.bodyFields['code'], '123456');
          expect(request.bodyFields['email'], 'test@example.com');
        }
        return http.Response(
          jsonEncode({
            'message': 'Generic summary',
            'errors': {'password': errors},
          }),
          422,
        );
      });
      addTearDown(client.close);
      final api = ApiService(profileClient: client);
      final responses = [
        await signup(api, password, password),
        await api.changePassword(
          currentPassword: ' old ',
          newPassword: password,
          passwordConfirmation: password,
        ),
        await api.resetPassword(
          email: 'test@example.com',
          code: '123456',
          password: password,
          passwordConfirmation: password,
        ),
      ];
      for (final result in responses) {
        expect(result.success, isFalse);
        expect(result.fieldErrors['password'], errors);
        expect(result.message, errors.join('\n'));
      }
      expect(paths, [
        '/api/register',
        '/api/me/password',
        '/api/reset-password',
      ]);
    },
  );
  test(
    'weak and mismatched passwords never submit or consume a reset code',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      });
      addTearDown(client.close);
      final api = ApiService(profileClient: client);
      expect((await signup(api, 'weak', 'weak')).success, isFalse);
      expect(
        (await api.changePassword(
          currentPassword: 'old',
          newPassword: 'weak',
          passwordConfirmation: 'weak',
        )).success,
        isFalse,
      );
      expect(
        (await api.resetPassword(
          email: 'test@example.com',
          code: '123456',
          password: 'weak',
          passwordConfirmation: 'weak',
        )).success,
        isFalse,
      );
      expect(
        (await signup(api, 'TrailRunner!2026', 'TrailRunner!2026 ')).success,
        isFalse,
      );
      expect(calls, 0);
    },
  );
  test(
    'login still sends an existing short password without strength validation or trimming',
    () async {
      var called = false;
      final client = MockClient((request) async {
        called = true;
        expect(request.url.path, '/api/login');
        expect(request.bodyFields['password'], ' old ');
        return http.Response('{}', 401);
      });
      addTearDown(client.close);
      expect(
        await ApiService(
          profileClient: client,
        ).login('test@example.com', ' old '),
        LoginResult.invalidCredentials,
      );
      expect(called, isTrue);
    },
  );
}
