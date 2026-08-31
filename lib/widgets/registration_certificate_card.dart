import 'package:flutter/material.dart';

import '../utils/registration_certificate.dart';

class RegistrationCertificateCard extends StatelessWidget {
  final Map<String, dynamic> certificate;
  final ValueChanged<String> onOpenUrl;

  const RegistrationCertificateCard({
    super.key,
    required this.certificate,
    required this.onOpenUrl,
  });

  @override
  Widget build(BuildContext context) {
    final status = certificateStatus(certificate);
    final downloadUrl = certificateDownloadUrl(certificate);
    final verificationUrl = certificateVerificationUrl(certificate);
    final isRevoked = status == 'revoked';
    final isAvailable = status == 'available';
    final color = isRevoked
        ? const Color(0xFFDC2626)
        : isAvailable
        ? const Color(0xFF16A34A)
        : const Color(0xFFF59E0B);

    return Container(
      key: const Key('registration-certificate-card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium_outlined, color: color),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'E-Certificate',
                  style: TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                key: const Key('certificate-status'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  certificateStatusLabel(certificate),
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            certificateMessage(certificate),
            style: const TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          if ((isAvailable && downloadUrl.isNotEmpty) ||
              verificationUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isAvailable && downloadUrl.isNotEmpty)
                  FilledButton.icon(
                    key: const Key('download-certificate'),
                    onPressed: () => onOpenUrl(downloadUrl),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download E-Certificate'),
                  ),
                if (verificationUrl.isNotEmpty)
                  OutlinedButton.icon(
                    key: const Key('verify-certificate'),
                    onPressed: () => onOpenUrl(verificationUrl),
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Verify Certificate'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
