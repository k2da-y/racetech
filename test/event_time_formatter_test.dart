import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_time_formatter.dart';

void main() {
  group('formatEventStartTime', () {
    test('formats backend 24-hour time', () {
      expect(formatEventStartTime('06:30'), '6:30 AM');
      expect(formatEventStartTime('18:05:00'), '6:05 PM');
    });

    test('keeps a valid 12-hour time normalized', () {
      expect(formatEventStartTime('6:30 am'), '6:30 AM');
    });
  });

  group('categoryScheduledStartTime', () {
    test('prefers the category schedule', () {
      final category = <String, dynamic>{
        'scheduled_start_time': '06:30',
        'started_at': '2026-08-20T06:37:12+08:00',
      };

      expect(categoryScheduledStartTime(category, '05:00'), '6:30 AM');
    });

    test('falls back to the general event start time', () {
      final category = <String, dynamic>{
        'scheduled_start_time': null,
        'started_at': null,
      };

      expect(categoryScheduledStartTime(category, '07:15'), '7:15 AM');
    });
  });
}
