import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/category_requirements.dart';

void main() {
  test('explicit true requires a medical certificate', () {
    expect(
      categoryRequiresMedicalCertificate({
        'requires_medical_certificate': true,
        'distance_km': 10,
      }),
      isTrue,
    );
  });

  test('explicit false overrides the legacy distance rule', () {
    expect(
      categoryRequiresMedicalCertificate({
        'requires_medical_certificate': false,
        'distance_km': 100,
      }),
      isFalse,
    );
  });

  test('uses distance only when the flag is absent', () {
    expect(categoryRequiresMedicalCertificate({'distance_km': 50}), isTrue);
    expect(categoryRequiresMedicalCertificate({'distance_km': 49.9}), isFalse);
  });
}
