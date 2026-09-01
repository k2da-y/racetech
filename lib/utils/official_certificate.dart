import 'registration_certificate.dart';

List<Map<String, dynamic>> certificateListFromResponse(dynamic response) {
  dynamic value = response;
  if (value is Map) {
    value = value['data'] ?? value['certificates'];
  }
  if (value is Map) {
    value = value['certificates'] ?? value['data'];
  }
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => normalizeOfficialCertificate(item))
      .toList();
}

Map<String, dynamic> normalizeOfficialCertificate(Map source) {
  final raw = Map<String, dynamic>.from(source);
  final nested = raw['certificate'];
  final certificate = nested is Map
      ? <String, dynamic>{...raw, ...Map<String, dynamic>.from(nested)}
      : raw;
  final registration = _map(certificate['registration']);
  final event = _map(certificate['event']).isNotEmpty
      ? _map(certificate['event'])
      : _map(registration['event']);
  final category = _map(certificate['category']).isNotEmpty
      ? _map(certificate['category'])
      : _map(registration['category']);

  return {
    ...certificate,
    'event': event,
    'category': category,
    'event_title': (certificate['event_title'] ?? event['title'] ?? 'Event')
        .toString()
        .trim(),
    'category_name':
        (certificate['category_name'] ?? category['name'] ?? 'Category')
            .toString()
            .trim(),
    'certificate_number':
        (certificate['certificate_number'] ??
                certificate['number'] ??
                certificate['code'] ??
                '')
            .toString()
            .trim(),
    'issued_at': (certificate['issued_at'] ?? certificate['created_at'] ?? '')
        .toString()
        .trim(),
    'status': certificateStatus(certificate),
    'download_url': certificateDownloadUrl(certificate),
    'verification_url': certificateVerificationUrl(certificate),
  };
}

String officialCertificateIssueDate(Map<String, dynamic> certificate) {
  final value = (certificate['issued_at'] ?? '').toString().trim();
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year}';
}

bool officialCertificateIsValid(Map<String, dynamic> certificate) {
  final status = certificateStatus(certificate);
  return status == 'available' || status == 'valid';
}

int validOfficialCertificateCount(Iterable<Map<String, dynamic>> values) {
  return values
      .map(normalizeOfficialCertificate)
      .where(officialCertificateIsValid)
      .length;
}

Map<String, dynamic> _map(dynamic value) {
  return value is Map ? Map<String, dynamic>.from(value) : {};
}
