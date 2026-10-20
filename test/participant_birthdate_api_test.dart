import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/services/offline_health_profile_store.dart';
import 'package:racetechph/utils/participant_birthdate.dart';

Future<ApiActionResult> signup(ApiService api, String birthdate) =>
    api.register(
      firstName: 'Juan',
      lastName: 'Cruz',
      gender: 'Male',
      birthday: birthdate,
      email: 'test@example.com',
      password: 'TrailRunner!2026',
      passwordConfirmation: 'TrailRunner!2026',
    );
Future<ApiActionResult> profile(ApiService api, String birthdate) =>
    api.updateProfile(
      name: 'Juan',
      phone: '09123456789',
      gender: 'Male',
      birthdate: birthdate,
      address: 'City',
      emergencyContactName: 'Contact',
      emergencyContactNumber: '09123456789',
      medicalConditions: '',
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'token': 'test-token'}));
  test(
    'signup and profile prioritize errors.birthdate over generic or unrelated errors',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        final body = request.method == 'POST'
            ? request.bodyFields
            : jsonDecode(request.body) as Map;
        expect(body['birthdate'], '2000-01-01');
        return http.Response(
          jsonEncode({
            'message': 'The given data was invalid.',
            'errors': {
              'name': ['Unrelated error'],
              'birthdate': [birthdateBeforeTodayMessage],
            },
          }),
          422,
        );
      });
      addTearDown(client.close);
      final api = ApiService(
        profileClient: client,
        healthStore: MemoryHealthProfileStore(),
      );
      expect(
        (await signup(api, '2000-01-01')).message,
        birthdateBeforeTodayMessage,
      );
      expect(
        (await profile(api, '2000-01-01')).message,
        birthdateBeforeTodayMessage,
      );
      expect(calls, 2);
    },
  );
  test(
    'invalid signup and profile birthdates never reach the network',
    () async {
      var calls = 0;
      final client = MockClient((_) async {
        calls++;
        return http.Response('{}', 500);
      });
      addTearDown(client.close);
      final api = ApiService(profileClient: client);
      final today = formatParticipantBirthdate(DateTime.now());
      expect((await signup(api, '')).message, birthdateRequiredMessage);
      expect((await signup(api, today)).message, birthdateBeforeTodayMessage);
      expect(
        (await profile(api, '1800-01-01')).message,
        birthdateTooOldMessage,
      );
      expect((await profile(api, 'invalid')).message, birthdateInvalidMessage);
      expect(calls, 0);
    },
  );
}
