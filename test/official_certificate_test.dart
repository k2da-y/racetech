import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/official_certificate.dart';

void main() {
  test(
    'normalizes official certificate fields and nested registration data',
    () {
      final certificate = normalizeOfficialCertificate({
        'number': 'CERT-2026-001',
        'status': 'issued',
        'issued_at': '2026-09-01T10:00:00+08:00',
        'download_url': 'https://example.com/certificate.pdf',
        'verify_url': 'https://example.com/verify/CERT-2026-001',
        'registration': {
          'event': {'title': 'Manila Marathon'},
          'category': {'name': '21K Open'},
        },
      });

      expect(certificate['event_title'], 'Manila Marathon');
      expect(certificate['category_name'], '21K Open');
      expect(certificate['certificate_number'], 'CERT-2026-001');
      expect(certificate['status'], 'available');
      expect(
        certificate['download_url'],
        'https://example.com/certificate.pdf',
      );
      expect(
        certificate['verification_url'],
        'https://example.com/verify/CERT-2026-001',
      );
      expect(officialCertificateIssueDate(certificate), 'Sep 1, 2026');
    },
  );

  test('extracts list, nested list, and safe empty response shapes', () {
    final item = {'certificate_number': 'CERT-1', 'status': 'valid'};
    expect(certificateListFromResponse([item]), hasLength(1));
    expect(
      certificateListFromResponse({
        'data': {
          'certificates': [item],
        },
      }),
      hasLength(1),
    );
    expect(certificateListFromResponse({'data': null}), isEmpty);
  });

  test('preserves revoked status and strips unsafe action URLs', () {
    final certificate = normalizeOfficialCertificate({
      'status': 'revoked',
      'download_url': 'javascript:alert(1)',
      'verification_url': '/verify/CERT-1',
    });

    expect(certificate['status'], 'revoked');
    expect(certificate['download_url'], isEmpty);
    expect(certificate['verification_url'], isEmpty);
  });

  test('counts only valid or available official certificates', () {
    expect(
      validOfficialCertificateCount([
        {'status': 'valid'},
        {'status': 'issued'},
        {'status': 'revoked'},
        {'status': 'waiting_for_result'},
      ]),
      2,
    );
  });
}
