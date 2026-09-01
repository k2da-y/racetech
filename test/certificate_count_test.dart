import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/certificate_count.dart';

void main() {
  test('prefers certificates_count over all legacy badge values', () {
    expect(
      certificateCountFromUser({
        'certificates_count': 3,
        'badges_count': 12,
        'badge_count': 11,
      }),
      3,
    );
  });

  test('treats a primary zero as authoritative', () {
    expect(
      certificateCountFromUser({'certificates_count': 0, 'badges_count': 8}),
      0,
    );
  });

  test('temporarily falls back through legacy count aliases', () {
    expect(certificateCountFromUser({'badges_count': '5'}), 5);
    expect(certificateCountFromUser({'badge_count': 4}), 4);
    expect(certificateCountFromUser({'unlocked_badges_count': 3}), 3);
    expect(certificateCountFromUser({'achievements_count': 2}), 2);
  });

  test('skips invalid values and uses the next compatible alias', () {
    expect(
      certificateCountFromUser({
        'certificates_count': 'not-a-number',
        'badges_count': 6,
      }),
      6,
    );
  });

  test('returns a safe zero when no count exists', () {
    expect(certificateCountFromUser(null), isNull);
    expect(certificateCountFromUser({}), isNull);
    expect(certificateCountOrZero({}), 0);
  });
}
