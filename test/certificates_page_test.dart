import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/profile/certificates_page.dart';
import 'package:racetechph/services/api_service.dart';

void main() {
  testWidgets('shows official certificate information and actions', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: CertificatesPage(
          loader: () async => const ApiDataResult.success([
            {
              'certificate_number': 'CERT-2026-001',
              'status': 'valid',
              'issued_at': '2026-09-01T10:00:00+08:00',
              'download_url': 'https://example.com/certificate.pdf',
              'verification_url': 'https://example.com/verify/CERT-2026-001',
              'event': {'title': 'Manila Marathon'},
              'category': {'name': '21K Open'},
            },
          ]),
          onOpenUrl: opened.add,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Manila Marathon'), findsOneWidget);
    expect(find.text('21K Open'), findsOneWidget);
    expect(find.text('CERT-2026-001'), findsOneWidget);
    expect(find.text('Sep 1, 2026'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);

    await tester.tap(find.byKey(const Key('official-certificate-download')));
    await tester.tap(find.byKey(const Key('official-certificate-verify')));
    expect(opened, [
      'https://example.com/certificate.pdf',
      'https://example.com/verify/CERT-2026-001',
    ]);
  });

  testWidgets('shows revoked certificate without a download action', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CertificatesPage(
          loader: () async => const ApiDataResult.success([
            {
              'certificate_number': 'REVOKED-1',
              'status': 'revoked',
              'download_url': 'https://example.com/revoked.pdf',
              'verification_url': 'https://example.com/verify/REVOKED-1',
              'event_title': 'Trail Run',
              'category_name': '25K',
            },
          ]),
          onOpenUrl: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Revoked'), findsOneWidget);
    expect(
      find.byKey(const Key('official-certificate-download')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('official-certificate-verify')),
      findsOneWidget,
    );
  });

  testWidgets('shows official-result empty wording without feedback language', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CertificatesPage(
          loader: () async => const ApiDataResult.success([]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No official E-Certificates yet'), findsOneWidget);
    expect(find.textContaining('official result'), findsOneWidget);
    expect(find.textContaining('feedback'), findsNothing);
  });

  testWidgets('shows an API error and retry action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CertificatesPage(
          loader: () async => const ApiDataResult.failure('Server unavailable'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Server unavailable'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
  });
}
