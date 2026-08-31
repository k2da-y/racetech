import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_category_registration.dart';
import 'package:racetechph/utils/event_normalizer.dart';

void main() {
  group('normalizeEventFromApi category registration states', () {
    test('allows a 7-9 AM category followed by an 11 AM-1 PM category', () {
      final event = normalizeEventFromApi(
        _event(
          categories: [
            _category(1, 'Morning 10K', '07:00', '09:00'),
            _category(2, 'Midday 10K', '11:00', '13:00'),
          ],
          states: [
            _state(1, canRegister: false, status: 'approved', joined: true),
            _state(2, canRegister: true),
          ],
        ),
      );

      final categories = _categories(event);
      expect(categoryIsJoined(categories[0]), isTrue);
      expect(categoryCanRegister(categories[1]), isTrue);
    });

    test('disables a category when the backend reports an overlap', () {
      final event = normalizeEventFromApi(
        _event(
          categories: [
            _category(1, 'Morning 10K', '07:00', '09:00'),
            _category(2, 'Overlapping 5K', '08:30', '10:00'),
          ],
          states: [
            _state(1, canRegister: false, status: 'approved', joined: true),
            _state(
              2,
              canRegister: false,
              conflictReason: 'Schedule overlaps with Morning 10K.',
            ),
          ],
        ),
      );

      final overlapping = _categories(event)[1];
      expect(categoryCanRegister(overlapping), isFalse);
      expect(
        categoryConflictReason(overlapping),
        'Schedule overlaps with Morning 10K.',
      );
    });

    test('disables an already joined category', () {
      final event = normalizeEventFromApi(
        _event(
          categories: [_category(7, '21K Open', '06:30', '10:30')],
          states: [
            _state(7, canRegister: false, status: 'pending', joined: true),
          ],
        ),
      );

      final category = _categories(event).single;
      expect(category['registration_status'], 'pending');
      expect(categoryIsJoined(category), isTrue);
      expect(categoryCanRegister(category), isFalse);
    });

    test('enables a compatible unjoined category and matches string ids', () {
      final event = normalizeEventFromApi(
        _event(
          categories: [_category(12, '5K Fun Run', '14:00', '15:30')],
          states: [_state('12', canRegister: true)],
        ),
      );

      final category = _categories(event).single;
      expect(category['is_registered'], isFalse);
      expect(categoryCanRegister(category), isTrue);
    });

    test('makes a rejected registration available again', () {
      final event = normalizeEventFromApi(
        _event(
          categories: [_category(3, 'Open Category', '07:00', '09:00')],
          states: [
            _state(3, canRegister: true, status: 'rejected', joined: false),
          ],
        ),
      );

      final category = _categories(event).single;
      expect(category['registration_status'], 'rejected');
      expect(categoryIsJoined(category), isFalse);
      expect(categoryCanRegister(category), isTrue);
    });

    test('safely preserves legacy event-level registration fallback', () {
      final source = _event(
        categories: [_category(4, 'Legacy Open', '07:00', '09:00')],
        registeredCategoryIds: [4],
        activeRegisteredCategoryIds: [4],
      )..remove('category_registration_states');

      final event = normalizeEventFromApi(source);
      final category = _categories(event).single;

      expect(event['registered_category_ids'], [4]);
      expect(event['active_registered_category_ids'], [4]);
      expect(event['category_registration_states'], isNull);
      expect(categoryHasRegistrationMetadata(category), isFalse);
      expect(categoryCanRegister(category), isTrue);
    });

    test('preserves the original state collection on the event', () {
      final states = [_state(1, canRegister: true)];
      final event = normalizeEventFromApi(
        _event(
          categories: [_category(1, '5K', '07:00', '08:00')],
          states: states,
        ),
      );

      expect(event['category_registration_states'], same(states));
    });
  });
}

Map<String, dynamic> _event({
  required List<Map<String, dynamic>> categories,
  List<Map<String, dynamic>>? states,
  List<int> registeredCategoryIds = const [],
  List<int> activeRegisteredCategoryIds = const [],
}) {
  return {
    'id': 99,
    'title': 'Schedule Test Event',
    'interest_type': 'Running',
    'status': 'upcoming',
    'event_start_date': '2026-09-12',
    'event_end_date': '2026-09-12',
    'categories': categories,
    'category_registration_states': states ?? <Map<String, dynamic>>[],
    'registered_category_ids': registeredCategoryIds,
    'active_registered_category_ids': activeRegisteredCategoryIds,
  };
}

Map<String, dynamic> _category(
  int id,
  String name,
  String startTime,
  String endTime,
) {
  return {
    'id': id,
    'name': name,
    'status': 'open',
    'scheduled_start_at': '2026-09-12T$startTime:00+08:00',
    'scheduled_end_at': '2026-09-12T$endTime:00+08:00',
  };
}

Map<String, dynamic> _state(
  Object categoryId, {
  required bool canRegister,
  String status = '',
  bool joined = false,
  String conflictReason = '',
}) {
  return {
    'category_id': categoryId,
    'can_register': canRegister,
    'is_registered': joined,
    'registration_status': status,
    'conflict_reason': conflictReason,
  };
}

List<Map<String, dynamic>> _categories(Map<String, dynamic> event) {
  return (event['categories'] as List)
      .map((category) => Map<String, dynamic>.from(category as Map))
      .toList();
}
