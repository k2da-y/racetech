bool categoryRequiresMedicalCertificate(Map<String, dynamic> category) {
  final explicit = category['requires_medical_certificate'];
  if (explicit is bool) return explicit;

  // Legacy categories did not include the flag and used distance instead.
  final distance = double.tryParse((category['distance_km'] ?? '').toString());
  return distance != null && distance >= 50;
}
