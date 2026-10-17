import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/participant_birthdate.dart';
import 'package:racetechph/utils/event_normalizer.dart';
import 'package:racetechph/services/api_service.dart';

void main() {
  final now = DateTime(2026, 10, 17, 23, 59);
  test(
    'inclusive oldest date and yesterday are valid, today/future are rejected',
    () {
      expect(validateParticipantBirthdate('1906-10-17', now: now), isNull);
      expect(validateParticipantBirthdate('2026-10-16', now: now), isNull);
      expect(
        validateParticipantBirthdate('1906-10-16', now: now),
        birthdateTooOldMessage,
      );
      expect(
        validateParticipantBirthdate('2026-10-17', now: now),
        birthdateBeforeTodayMessage,
      );
      expect(
        validateParticipantBirthdate('2026-10-18', now: now),
        birthdateBeforeTodayMessage,
      );
    },
  );
  test(
    'missing, malformed and impossible dates use exact Laravel messages',
    () {
      expect(
        validateParticipantBirthdate(null, now: now),
        birthdateRequiredMessage,
      );
      expect(
        validateParticipantBirthdate(' ', now: now),
        birthdateRequiredMessage,
      );
      for (final invalid in [
        'not a date',
        '2026-02-30',
        '2025-02-29',
        '2000-1-01',
        '2000-01-01T00:00:00Z',
      ]) {
        expect(
          validateParticipantBirthdate(invalid, now: now),
          birthdateInvalidMessage,
        );
      }
      expect(validateParticipantBirthdate('2000-02-29', now: now), isNull);
      expect(formatParticipantBirthdate(DateTime(2000, 2, 9)), '2000-02-09');
    },
  );
  test(
    'calendar limits and picker initial date remain safe for invalid legacy data',
    () {
      final limits = birthdateLimits(now: DateTime(2024, 2, 29));
      expect(limits.first, DateTime(1904, 2, 29));
      expect(limits.last, DateTime(2024, 2, 28));
      expect(
        birthdateLimits(now: DateTime(2026, 1, 1)).last,
        DateTime(2025, 12, 31),
      );
      expect(
        initialParticipantBirthdate('1800-01-01', now: now),
        DateTime(1906, 10, 17),
      );
      expect(
        initialParticipantBirthdate('2030-01-01', now: now),
        DateTime(2026, 10, 16),
      );
    },
  );
  test(
    'block reason survives normalization and overrides complete-looking legacy profiles',
    () {
      final event = normalizeEventFromApi({
        'registration_block_reason': birthdateRegistrationBlockMessage,
        'categories': [
          {'id': 1, 'status': 'open'},
        ],
      });
      expect(registrationBlockReason(event), birthdateRegistrationBlockMessage);
      final user = <String, dynamic>{
        'name': 'Juan',
        'phone': '09123456789',
        'gender': 'Male',
        'birthdate': '2000-01-01',
        'address': 'City',
        'emergency_contact_name': 'Contact',
        'emergency_contact_number': '09123456789',
      };
      expect(ApiService().profileIsComplete(user), isTrue);
      expect(
        ApiService().profileIsComplete({...user, 'birthdate': '1800-01-01'}),
        isFalse,
      );
      expect(
        registrationBlockReason({}, user: {...user, 'birthdate': null}),
        birthdateRegistrationBlockMessage,
      );
      expect(registrationBlockReason({}, user: user), isEmpty);
    },
  );
}
