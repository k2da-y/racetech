import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_category_registration.dart';

void main() {
  test('joined categories are identified and cannot register again', () {
    final category = <String, dynamic>{
      'registration_status': 'approved',
      'can_register': false,
    };

    expect(categoryIsJoined(category), isTrue);
    expect(categoryStatusLabel(category), 'Approved');
    expect(categoryCanRegister(category), isFalse);
  });

  test('compatible categories remain registerable', () {
    final category = <String, dynamic>{
      'can_register': true,
      'registration_status': null,
    };

    expect(categoryIsJoined(category), isFalse);
    expect(categoryCanRegister(category), isTrue);
  });

  test('conflicting categories expose the backend reason', () {
    final category = <String, dynamic>{
      'can_register': false,
      'conflict_reason': 'Schedule overlaps with 21K Open.',
    };

    expect(categoryCanRegister(category), isFalse);
    expect(
      categoryConflictReason(category),
      'Schedule overlaps with 21K Open.',
    );
  });

  test('category cutoff falls back to the event end time', () {
    expect(categoryCutoffTime(<String, dynamic>{}, '11:30'), '11:30');
    expect(
      categoryCutoffTime(<String, dynamic>{'cutoff_time': '10:00'}, '11:30'),
      '10:00',
    );
  });
}
