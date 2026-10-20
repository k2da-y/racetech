import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:racetechph/pages/signup_page.dart';
import 'package:racetechph/pages/signup_page2.dart';
import 'package:racetechph/pages/profile_settings_page.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/services/offline_health_profile_store.dart';
import 'package:racetechph/utils/participant_birthdate.dart';
import 'package:racetechph/widgets/event_details_sheet.dart';
import 'package:racetechph/widgets/registration_profile_action.dart';

void main() {
  testWidgets(
    'signup requires birthdate and picker excludes today with inclusive oldest date',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
      final next = find.text('Continue');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(find.text(birthdateRequiredMessage), findsOneWidget);
      final birthday = find.text('Select your birthday');
      await tester.ensureVisible(birthday);
      await tester.tap(birthday);
      await tester.pumpAndSettle();
      final picker = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      expect(picker.firstDate, birthdateLimits().first);
      expect(picker.lastDate, birthdateLimits().last);
      expect(picker.lastDate.isBefore(birthdateLimits().today), isTrue);
    },
  );
  testWidgets('signup second step displays the exact server birthdate error', (
    tester,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'message': 'Validation failed.',
          'errors': {
            'birthdate': [birthdateBeforeTodayMessage],
          },
        }),
        422,
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: SignUpPage2(
          firstName: 'Juan',
          lastName: 'Cruz',
          gender: 'Male',
          birthday: '2000-01-01',
          apiService: ApiService(profileClient: client),
        ),
      ),
    );
    for (final (index, value) in [
      (0, 'test@example.com'),
      (1, 'TrailRunner!2026'),
      (2, 'TrailRunner!2026'),
    ]) {
      final field = find.byType(TextField).at(index);
      await tester.ensureVisible(field);
      await tester.enterText(field, value);
    }
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final create = find.text('Create Account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect(find.text(birthdateBeforeTodayMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final birthdate in [
    '1800-01-01',
    formatParticipantBirthdate(DateTime.now()),
  ]) {
    testWidgets(
      'profile picker safely clamps legacy birthdate $birthdate and save rejects it',
      (tester) async {
        SharedPreferences.setMockInitialValues({'token': 'test-token'});
        var patches = 0;
        final client = MockClient((request) async {
          if (request.method == 'PATCH') patches++;
          return http.Response(
            jsonEncode({
              'user': {'id': 1, 'name': 'Juan', 'birthdate': birthdate},
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
        final field = find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Birthdate *',
        );
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.tap(field);
        await tester.pumpAndSettle();
        final picker = tester.widget<DatePickerDialog>(
          find.byType(DatePickerDialog),
        );
        expect(picker.firstDate, birthdateLimits().first);
        expect(picker.lastDate, birthdateLimits().last);
        expect(picker.initialDate, initialParticipantBirthdate(birthdate));
        Navigator.of(tester.element(find.byType(DatePickerDialog))).pop();
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(
          find.text(validateParticipantBirthdate(birthdate)!),
          findsWidgets,
        );
        expect(patches, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'blocked event offers Update Profile and refreshes eligibility on return',
    (tester) async {
      var blocked = true;
      var refreshed = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => EventDetailsSheet(
                event: {
                  'title': 'Legacy Event',
                  'event': 'Marathon',
                  'registration_block_reason': blocked
                      ? birthdateRegistrationBlockMessage
                      : null,
                  'categories': [
                    {
                      'name': 'Open Category',
                      'status': 'open',
                      'can_register': !blocked,
                    },
                  ],
                },
                canJoin: !blocked,
                statusLabel: 'Upcoming',
                actionLabel: blocked ? 'Unavailable' : 'Join Event',
                availabilityMessage: '',
                onJoin: () => openRegistrationProfileSettings(
                  context,
                  profileBuilder: (settingsContext) => Scaffold(
                    appBar: AppBar(title: const Text('Profile Settings')),
                    body: FilledButton(
                      onPressed: () => Navigator.pop(settingsContext, true),
                      child: const Text('Save corrected birthdate'),
                    ),
                  ),
                  onRefresh: () async {
                    refreshed++;
                    setState(() => blocked = false);
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(birthdateRegistrationBlockMessage), findsOneWidget);
      await tester.tap(find.text('Update Profile'));
      await tester.pumpAndSettle();
      expect(find.text('Profile Settings'), findsOneWidget);
      await tester.tap(find.text('Save corrected birthdate'));
      await tester.pumpAndSettle();
      expect(refreshed, 1);
      expect(find.text('Update Profile'), findsNothing);
      expect(find.text('Join Event'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
