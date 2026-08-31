import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/widgets/registration_certificate_card.dart';

void main() {
  testWidgets('shows available certificate actions', (tester) async {
    final openedUrls = <String>[];
    await tester.pumpWidget(
      _app(
        RegistrationCertificateCard(
          certificate: const {
            'status': 'available',
            'download_url': 'https://example.com/certificate.pdf',
            'verification_url': 'https://example.com/verify/ABC',
          },
          onOpenUrl: openedUrls.add,
        ),
      ),
    );

    expect(find.text('E-Certificate'), findsOneWidget);
    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Download E-Certificate'), findsOneWidget);
    expect(find.text('Verify Certificate'), findsOneWidget);

    await tester.tap(find.byKey(const Key('download-certificate')));
    await tester.tap(find.byKey(const Key('verify-certificate')));
    expect(openedUrls, [
      'https://example.com/certificate.pdf',
      'https://example.com/verify/ABC',
    ]);
  });

  testWidgets('shows waiting for result without actions', (tester) async {
    await tester.pumpWidget(
      _app(
        RegistrationCertificateCard(
          certificate: const {'status': 'waiting_for_result'},
          onOpenUrl: (_) {},
        ),
      ),
    );

    expect(find.text('Waiting for result'), findsOneWidget);
    expect(find.byKey(const Key('download-certificate')), findsNothing);
    expect(find.byKey(const Key('verify-certificate')), findsNothing);
  });

  testWidgets('shows waiting for feedback status', (tester) async {
    await tester.pumpWidget(
      _app(
        RegistrationCertificateCard(
          certificate: const {'status': 'waiting_for_feedback'},
          onOpenUrl: (_) {},
        ),
      ),
    );

    expect(find.text('Waiting for feedback'), findsOneWidget);
    expect(find.textContaining('feedback to unlock'), findsOneWidget);
  });

  testWidgets('keeps verification available for a revoked certificate', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        RegistrationCertificateCard(
          certificate: const {
            'status': 'revoked',
            'download_url': 'https://example.com/revoked.pdf',
            'verification_url': 'https://example.com/verify/REVOKED',
          },
          onOpenUrl: (_) {},
        ),
      ),
    );

    expect(find.text('Revoked'), findsOneWidget);
    expect(find.byKey(const Key('download-certificate')), findsNothing);
    expect(find.byKey(const Key('verify-certificate')), findsOneWidget);
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}
