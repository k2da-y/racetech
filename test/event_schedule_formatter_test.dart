import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_schedule_formatter.dart';

void main() {
  test('formats one-day and multi-day event dates', () {
    expect(
      formatEventDateRange(
        eventStartDate: '2026-08-21',
        eventEndDate: '2026-08-21',
      ),
      'Aug 21, 2026',
    );
    expect(
      formatEventDateRange(
        eventStartDate: '2026-08-21',
        eventEndDate: '2026-08-23',
      ),
      'Aug 21, 2026 – Aug 23, 2026',
    );
  });

  test('continues accepting the legacy event date', () {
    expect(formatEventDateRange(legacyEventDate: '2026-08-21'), 'Aug 21, 2026');
  });

  test('prefers complete category timestamps', () {
    final category = <String, dynamic>{
      'scheduled_start_date': '2026-08-24',
      'scheduled_start_time': '07:00',
      'scheduled_start_at': '2026-08-21T06:30:00',
      'scheduled_end_at': '2026-08-21T10:30:00',
    };

    expect(
      categoryScheduleLabel(category),
      'Aug 21, 2026 • 6:30 AM – 10:30 AM',
    );
  });

  test('formats an overnight category with both dates', () {
    final category = <String, dynamic>{
      'scheduled_start_at': '2026-08-21T22:00:00',
      'scheduled_end_at': '2026-08-22T02:00:00',
    };

    expect(
      categoryScheduleLabel(category),
      'Aug 21, 2026 • 10:00 PM – Aug 22, 2026 • 2:00 AM',
    );
  });
}
