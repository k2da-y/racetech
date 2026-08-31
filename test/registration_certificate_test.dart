import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/registration_certificate.dart';

void main() {
  test('reads the new readiness certificate response', () {
    final certificate = readinessCertificate({
      'certificate': {
        'status': 'available',
        'download_url': 'https://example.com/certificate.pdf',
        'verification_url': 'https://example.com/verify/ABC',
      },
    });

    expect(certificateStatus(certificate!), 'available');
    expect(certificateStatusLabel(certificate), 'Available');
    expect(
      certificateDownloadUrl(certificate),
      'https://example.com/certificate.pdf',
    );
    expect(
      certificateVerificationUrl(certificate),
      'https://example.com/verify/ABC',
    );
  });

  test('normalizes waiting and revoked statuses', () {
    expect(
      certificateStatusLabel({'status': 'pending_result'}),
      'Waiting for result',
    );
    expect(
      certificateStatusLabel({'status': 'waiting_feedback'}),
      'Waiting for feedback',
    );
    expect(certificateStatusLabel({'status': 'invalidated'}), 'Revoked');
  });

  test('falls back to legacy E-Badge objects', () {
    final certificate = readinessCertificate({
      'e_badge': {
        'status': 'issued',
        'url': 'https://example.com/legacy-certificate.pdf',
      },
    });

    expect(certificate?['legacy_e_badge'], isTrue);
    expect(certificateStatus(certificate!), 'available');
    expect(
      certificateDownloadUrl(certificate),
      'https://example.com/legacy-certificate.pdf',
    );
  });

  test('rejects unsafe certificate URLs', () {
    expect(
      certificateDownloadUrl({'download_url': 'javascript:alert(1)'}),
      isEmpty,
    );
    expect(
      certificateVerificationUrl({'verification_url': '/verify/ABC'}),
      isEmpty,
    );
  });
}
