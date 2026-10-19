class HealthProfile {
  final double? height, weight, bmi;
  final String category, interpretation, measuredAt, notice;
  const HealthProfile({
    this.height,
    this.weight,
    this.bmi,
    this.category = '',
    this.interpretation = '',
    this.measuredAt = '',
    this.notice = '',
  });

  factory HealthProfile.fromUser(Map<String, dynamic> user) {
    double? number(dynamic value) {
      final parsed = double.tryParse('$value');
      return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
    }

    String text(String key) => user[key]?.toString().trim() ?? '';
    return HealthProfile(
      height: number(user['height_cm']),
      weight: number(user['weight_kg']),
      bmi: number(user['bmi']),
      category: text('bmi_category'),
      interpretation: text('bmi_interpretation'),
      measuredAt: text('bmi_measured_at'),
      notice: text('bmi_notice'),
    );
  }

  factory HealthProfile.offlinePreview(
    Map<String, dynamic> user,
    HealthMeasurements measurements, {
    DateTime? now,
    String? measuredAt,
  }) {
    final values = measurements.toJson();
    final height = values['height_cm'] as double?;
    final weight = values['weight_kg'] as double?;
    final today = now ?? DateTime.now();
    final effectiveMeasuredAt = height == null
        ? ''
        : (measuredAt?.trim().isNotEmpty == true
              ? measuredAt!.trim()
              : _date(today));
    final bmi = height == null || weight == null
        ? null
        : double.parse(
            (weight / ((height / 100) * (height / 100))).toStringAsFixed(1),
          );
    final birthdate = DateTime.tryParse('${user['birthdate'] ?? ''}');
    final reference = DateTime.tryParse(effectiveMeasuredAt) ?? today;
    final interpretation = bmi == null
        ? 'unavailable'
        : birthdate == null
        ? 'age_unknown'
        : _ageOn(birthdate, reference) >= 20
        ? 'adult'
        : 'age_specific_required';

    return HealthProfile(
      height: height,
      weight: weight,
      bmi: bmi,
      category: interpretation == 'adult' ? _adultCategory(bmi) : '',
      interpretation: interpretation,
      measuredAt: effectiveMeasuredAt,
      notice: user['bmi_notice']?.toString().trim() ?? '',
    );
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static int _ageOn(DateTime birthdate, DateTime date) {
    var age = date.year - birthdate.year;
    if (date.month < birthdate.month ||
        (date.month == birthdate.month && date.day < birthdate.day)) {
      age--;
    }
    return age;
  }

  static String _adultCategory(double? bmi) => switch (bmi) {
    null => '',
    < 18.5 => 'Underweight',
    < 25 => 'Healthy weight',
    < 30 => 'Overweight',
    _ => 'Obesity',
  };

  String get message => switch (interpretation) {
    'age_specific_required' =>
      'Under 20: age-specific interpretation is required. Adult BMI categories do not apply.',
    'age_unknown' =>
      'Add your birthdate to enable age-appropriate interpretation.',
    'adult' when bmi != null =>
      category.isEmpty ? 'Category unavailable.' : category,
    _ => 'Add height and weight to view your BMI.',
  };
  String get disclaimer => notice.isNotEmpty
      ? notice
      : 'BMI is a screening indicator, not a medical diagnosis or a measure of fitness to participate.';
}

class HealthMeasurements {
  final String height, weight;
  const HealthMeasurements(this.height, this.weight);
  Map<String, String> validate() {
    final errors = <String, String>{};
    final h = height.trim(), w = weight.trim();
    if (h.isEmpty != w.isEmpty) {
      errors[h.isEmpty ? 'height' : 'weight'] =
          'Enter height and weight together, or clear both.';
    }
    void range(String value, String key, double min, double max, String unit) {
      if (value.isEmpty) return;
      final number = double.tryParse(value);
      if (number == null || !number.isFinite || number < min || number > max) {
        errors[key] = 'Enter a value from $min to $max $unit.';
      }
    }

    range(h, 'height', 50, 250, 'cm');
    range(w, 'weight', 10, 500, 'kg');
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'height_cm': height.trim().isEmpty ? null : double.parse(height.trim()),
    'weight_kg': weight.trim().isEmpty ? null : double.parse(weight.trim()),
  };
}
