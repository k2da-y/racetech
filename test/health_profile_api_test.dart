import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/utils/health_profile.dart';

Future<ApiActionResult> save(
  ApiService api,
  HealthMeasurements? measurements,
) => api.updateProfile(
  name: 'Participant',
  phone: '09123456789',
  gender: 'Other',
  birthdate: '2000-01-01',
  address: 'City',
  emergencyContactName: 'Contact',
  emergencyContactNumber: '09123456789',
  medicalConditions: '',
  measurements: measurements,
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({'token': 'test-token'}));
  test('GET me preserves private health fields', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/me');
      return http.Response(
        jsonEncode({
          'user': {
            'height_cm': 170,
            'bmi': 23.1,
            'bmi_interpretation': 'adult',
            'bmi_notice': 'Notice',
          },
        }),
        200,
      );
    });
    addTearDown(client.close);
    final profile = HealthProfile.fromUser(
      (await ApiService(profileClient: client).getUser())!,
    );
    expect(profile.bmi, 23.1);
    expect(profile.notice, 'Notice');
  });
  test(
    'PATCH sends the pair and date as JSON, and clearing sends real nulls',
    () async {
      final bodies = <Map>[];
      final client = MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '/api/me');
        expect(request.headers['authorization'], 'Bearer test-token');
        expect(request.headers['content-type'], contains('application/json'));
        bodies.add(jsonDecode(request.body) as Map);
        return http.Response('{"message":"Saved"}', 200);
      });
      addTearDown(client.close);
      final api = ApiService(profileClient: client);
      expect(
        (await save(
          api,
          const HealthMeasurements('170', '65', '2026-10-01'),
        )).success,
        isTrue,
      );
      expect(bodies.first['height_cm'], 170);
      expect(bodies.first['weight_kg'], 65);
      expect(bodies.first['bmi_measured_at'], '2026-10-01');
      expect(bodies.first.containsKey('bmi'), isFalse);
      await save(api, const HealthMeasurements('', '', ''));
      expect(bodies.last.containsKey('height_cm'), isTrue);
      expect(bodies.last['height_cm'], isNull);
      expect(bodies.last['weight_kg'], isNull);
      await save(api, null);
      expect(bodies.last.containsKey('height_cm'), isFalse);
    },
  );
  test(
    'invalid pairs do not send requests; Laravel validation errors are surfaced',
    () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        return http.Response(
          jsonEncode({
            'message': 'Date rejected',
            'errors': {
              'bmi_measured_at': ['Date rejected'],
            },
          }),
          422,
        );
      });
      addTearDown(client.close);
      final api = ApiService(profileClient: client);
      expect(
        (await save(api, const HealthMeasurements('170', '', ''))).success,
        isFalse,
      );
      expect(calls, 0);
      expect(
        (await save(api, const HealthMeasurements('170', '65', ''))).message,
        contains('Date rejected'),
      );
    },
  );
}
