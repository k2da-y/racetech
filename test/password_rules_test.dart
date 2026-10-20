import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/password_rules.dart';

void main() {
  test('requires all five rules with the documented guidance', () {
    for (final weak in [
      '',
      'Short1!',
      'lowercase123!',
      'UPPERCASE123!',
      'NoNumbersHere!',
      'NoSymbols12345',
    ]) {
      expect(validateNewPassword(weak), passwordRequirementsMessage);
    }
    expect(validateNewPassword('TrailRunner!2026'), isNull);
  });
  test('matches Laravel Unicode categories and counts code points', () {
    expect(validateNewPassword('Áá١§abcdefgh'), isNull);
    expect(validateNewPassword('Aa1!aaaaaaa😀'), isNull);
    expect(validateNewPassword('Aa1!aaaaaa😀'), passwordRequirementsMessage);
    expect(validateNewPassword('Aa123456789 '), isNull);
    expect(passwordRequirements('Aa123456789\t').last.met, isFalse);
  });
  test('confirmation is exact and whitespace is preserved', () {
    expect(
      validatePasswordConfirmation(' TrailRunner!2026 ', ' TrailRunner!2026 '),
      isNull,
    );
    expect(
      validatePasswordConfirmation('TrailRunner!2026 ', 'TrailRunner!2026'),
      isNotNull,
    );
    expect(
      validatePasswordConfirmation('TrailRunner!2026', 'trailRunner!2026'),
      isNotNull,
    );
  });
}
