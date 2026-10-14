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
  final String height, weight, date;
  const HealthMeasurements(this.height, this.weight, this.date);
  Map<String, String> validate({DateTime? today}) {
    final errors = <String, String>{};
    final h = height.trim(), w = weight.trim(), d = date.trim();
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
    if (d.isNotEmpty) {
      final parsed = DateTime.tryParse(d);
      final now = today ?? DateTime.now();
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d) ||
          parsed == null ||
          parsed.toIso8601String().split('T').first != d ||
          parsed.isAfter(DateTime(now.year, now.month, now.day))) {
        errors['date'] =
            'Choose a valid measurement date that is not in the future.';
      }
      if (h.isEmpty && w.isEmpty) {
        errors['date'] = 'Add measurements or clear the measurement date.';
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'height_cm': height.trim().isEmpty ? null : double.parse(height.trim()),
    'weight_kg': weight.trim().isEmpty ? null : double.parse(weight.trim()),
    if (date.trim().isNotEmpty && height.trim().isNotEmpty)
      'bmi_measured_at': date.trim(),
  };
}
