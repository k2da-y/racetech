import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racetechph/pages/profile_settings_page.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/services/offline_health_profile_store.dart';
import 'package:racetechph/utils/health_profile.dart';
import 'package:racetechph/widgets/health_profile_section.dart';

void main() {
  for (final state in [
    'adult',
    'age_specific_required',
    'age_unknown',
    'unavailable',
    'legacy',
  ]) {
    testWidgets('private section displays $state and clearing is optional', (
      tester,
    ) async {
      final h = TextEditingController(text: '170');
      final w = TextEditingController(text: '65');
      final d = TextEditingController(text: '2026-10-01');
      addTearDown(h.dispose);
      addTearDown(w.dispose);
      addTearDown(d.dispose);
      final profile = HealthProfile.fromUser(
        state == 'legacy'
            ? {}
            : {
                'bmi': state == 'unavailable' ? null : 23.1,
                'bmi_category': 'Healthy weight',
                'bmi_interpretation': state,
                'bmi_notice': 'Server disclaimer',
              },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HealthProfileSection(
                profile: profile,
                height: h,
                weight: w,
                date: d,
              ),
            ),
          ),
        ),
      );
      expect(find.text(profile.message), findsOneWidget);
      expect(find.text(profile.disclaimer), findsOneWidget);
      expect(
        find.textContaining('not used for registration eligibility'),
        findsOneWidget,
      );
      if (state != 'adult') expect(find.text('Healthy weight'), findsNothing);
      await tester.ensureVisible(find.text('Clear measurements'));
      await tester.tap(find.text('Clear measurements'));
      expect([h.text, w.text, d.text], ['', '', '']);
    });
  }
  testWidgets(
    'shows paired validation errors and keeps saved BMI during edits',
    (tester) async {
      final h = TextEditingController(text: '170'),
          w = TextEditingController(),
          d = TextEditingController();
      addTearDown(h.dispose);
      addTearDown(w.dispose);
      addTearDown(d.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: HealthProfileSection(
                profile: const HealthProfile(
                  bmi: 23.1,
                  interpretation: 'adult',
                ),
                height: h,
                weight: w,
                date: d,
                hasChanges: true,
                errors: const HealthMeasurements('170', '', '').validate(),
              ),
            ),
          ),
        ),
      );
      expect(
        find.textContaining('Enter height and weight together'),
        findsOneWidget,
      );
      expect(find.textContaining('private on-device preview'), findsOneWidget);
      expect(find.text('BMI: 23.1'), findsOneWidget);
    },
  );
  for (final completeProfile in [true, false]) {
    testWidgets(
      'health save refreshes BMI with complete profile: $completeProfile',
      (tester) async {
        SharedPreferences.setMockInitialValues({'token': 'test-token'});
        var saved = false;
        var gets = 0;
        final client = MockClient((request) async {
          if (request.method == 'PUT') {
            final body = jsonDecode(request.body) as Map;
            expect(body['height_cm'], 170);
            expect(body['weight_kg'], 65);
            expect(body.containsKey('bmi'), isFalse);
            expect(body['client_update_id'], isNotEmpty);
            saved = true;
            return http.Response(
              jsonEncode({
                'message': 'Saved',
                'user': {
                  'name': 'Participant',
                  if (completeProfile) 'birthdate': '2000-01-01',
                  'height_cm': 170,
                  'weight_kg': 65,
                  'bmi': 23.1,
                  'bmi_category': completeProfile ? 'Healthy weight' : null,
                  'bmi_interpretation': completeProfile
                      ? 'adult'
                      : 'age_unknown',
                  'bmi_measured_at': '2026-10-14',
                  'health_profile_updated_at': '2026-10-17T09:00:00Z',
                },
              }),
              200,
            );
          }
          gets++;
          return http.Response(
            jsonEncode({
              'user': {
                'name': 'Participant',
                if (completeProfile) ...{
                  'phone': '09123456789',
                  'gender': 'Other',
                  'birthdate': '2000-01-01',
                  'address': 'City',
                  'emergency_contact_name': 'Contact',
                  'emergency_contact_number': '09123456789',
                },
                if (saved) ...{
                  'height_cm': 170,
                  'weight_kg': 65,
                  'bmi': 23.1,
                  'bmi_category': completeProfile ? 'Healthy weight' : null,
                  'bmi_interpretation': completeProfile
                      ? 'adult'
                      : 'age_unknown',
                  'bmi_measured_at': '2026-10-14',
                },
              },
            }),
            200,
          );
        });
        addTearDown(client.close);
        await tester.pumpWidget(
          MaterialApp(
            home: ProfileSettingsPage(
              apiService: ApiService(
                profileClient: client,
                healthStore: MemoryHealthProfileStore(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final height = find.byKey(const Key('health-height'));
        await tester.ensureVisible(height);
        await tester.enterText(height, '170');
        final weight = find.byKey(const Key('health-weight'));
        await tester.ensureVisible(weight);
        await tester.enterText(weight, '65');
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(saved, isTrue);
        expect(gets, 2);
        await tester.ensureVisible(find.text('BMI: 23.1'));
        expect(
          find.text(
            completeProfile
                ? 'Healthy weight'
                : 'Add your birthdate to enable age-appropriate interpretation.',
          ),
          findsOneWidget,
        );
        expect(find.text('Measured on 2026-10-14'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
