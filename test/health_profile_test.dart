import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/health_profile.dart';

void main() {
  test('reads numeric strings and trusts the supplied result', () {
    final profile = HealthProfile.fromUser({
      'height_cm': '170.00',
      'weight_kg': 65,
      'bmi': '23.1',
      'bmi_category': 'Healthy weight',
      'bmi_interpretation': 'adult',
      'bmi_measured_at': '2026-10-01',
      'bmi_notice': 'Server disclaimer',
    });
    expect(profile.height, 170);
    expect(profile.weight, 65);
    expect(profile.bmi, 23.1);
    expect(profile.message, 'Healthy weight');
    expect(profile.measuredAt, '2026-10-01');
    expect(profile.disclaimer, 'Server disclaimer');
  });
  test('handles unavailable, unknown age and younger participant states', () {
    expect(HealthProfile.fromUser({}).bmi, isNull);
    expect(
      HealthProfile.fromUser({}).message,
      contains('Add height and weight'),
    );
    expect(
      HealthProfile.fromUser({'bmi_interpretation': 'age_unknown'}).message,
      contains('birthdate'),
    );
    expect(
      HealthProfile.fromUser({
        'bmi_interpretation': 'age_specific_required',
        'bmi_category': 'Ignore',
      }).message,
      contains('age-specific'),
    );
    expect(
      HealthProfile.fromUser({'bmi': 'NaN', 'weight_kg': double.infinity}).bmi,
      isNull,
    );
  });
  test('requires a pair and accepts the backend limits', () {
    expect(
      const HealthMeasurements('', '65', '').validate(),
      contains('height'),
    );
    expect(
      const HealthMeasurements('170', '', '').validate(),
      contains('weight'),
    );
    for (final values in [
      const HealthMeasurements('50', '10', ''),
      const HealthMeasurements('250', '500', ''),
    ]) {
      expect(values.validate(), isEmpty);
    }
    for (final bad in ['49', '251', 'NaN', 'Infinity', 'abc']) {
      expect(HealthMeasurements(bad, '65', '').validate(), contains('height'));
    }
    for (final bad in ['9', '501', 'NaN', '-2']) {
      expect(HealthMeasurements('170', bad, '').validate(), contains('weight'));
    }
  });
  test(
    'validates dates and supports explicit clearing without submitting BMI',
    () {
      final today = DateTime(2026, 10, 14);
      for (final bad in ['2026-10-15', '2026-02-30', 'bad']) {
        expect(
          HealthMeasurements('170', '65', bad).validate(today: today),
          contains('date'),
        );
      }
      expect(
        const HealthMeasurements(
          '170',
          '65',
          '2026-10-14',
        ).validate(today: today),
        isEmpty,
      );
      expect(const HealthMeasurements('', '', '').toJson(), {
        'height_cm': null,
        'weight_kg': null,
      });
      expect(const HealthMeasurements('170', '65', '').toJson(), {
        'height_cm': 170.0,
        'weight_kg': 65.0,
      });
      expect(const HealthMeasurements('170', '65', '2026-10-01').toJson(), {
        'height_cm': 170.0,
        'weight_kg': 65.0,
        'bmi_measured_at': '2026-10-01',
      });
      expect(
        const HealthMeasurements('', '', '2026-10-01').validate(),
        contains('date'),
      );
    },
  );
}
