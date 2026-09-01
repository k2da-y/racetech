import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/official_certificate.dart';
import '../utils/registration_certificate.dart';

typedef CertificatesLoader =
    Future<ApiDataResult<List<Map<String, dynamic>>>> Function();

class CertificatesPage extends StatefulWidget {
  final CertificatesLoader? loader;
  final ValueChanged<String>? onOpenUrl;

  const CertificatesPage({super.key, this.loader, this.onOpenUrl});

  @override
  State<CertificatesPage> createState() => _CertificatesPageState();
}

class _CertificatesPageState extends State<CertificatesPage>
    with WidgetsBindingObserver {
  bool isLoading = true;
  String errorMessage = '';
  List<Map<String, dynamic>> certificates = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadCertificates();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !isLoading) {
      loadCertificates(showLoading: false);
    }
  }

  Future<void> loadCertificates({bool showLoading = true}) async {
    if (showLoading && mounted) {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });
    }

    final result =
        await (widget.loader?.call() ?? ApiService().getCertificates());
    if (!mounted) return;
    setState(() {
      if (result.success) {
        certificates = (result.data ?? const [])
            .map(normalizeOfficialCertificate)
            .toList();
        errorMessage = '';
      } else {
        errorMessage = result.message;
      }
      isLoading = false;
    });
  }

  Future<void> openUrl(String value) async {
    if (widget.onOpenUrl != null) {
      widget.onOpenUrl!(value);
      return;
    }
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      showMessage('Certificate link is unavailable.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted || opened) return;
    showMessage('Unable to open the certificate link.');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEFF3F9),
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'E-Certificates',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh certificates',
            onPressed: isLoading ? null : loadCertificates,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage.isNotEmpty && certificates.isEmpty
          ? _CertificateError(message: errorMessage, onRetry: loadCertificates)
          : RefreshIndicator(
              onRefresh: () => loadCertificates(showLoading: false),
              child: certificates.isEmpty
                  ? const _EmptyCertificates()
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                      itemCount: certificates.length,
                      itemBuilder: (context, index) => _CertificateCard(
                        certificate: certificates[index],
                        onOpenUrl: openUrl,
                      ),
                    ),
            ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Map<String, dynamic> certificate;
  final ValueChanged<String> onOpenUrl;

  const _CertificateCard({required this.certificate, required this.onOpenUrl});

  @override
  Widget build(BuildContext context) {
    final status = certificateStatus(certificate);
    final isRevoked = status == 'revoked';
    final isValid = status == 'available';
    final color = isRevoked ? const Color(0xFFDC2626) : const Color(0xFF16A34A);
    final downloadUrl = certificateDownloadUrl(certificate);
    final verificationUrl = certificateVerificationUrl(certificate);
    final number = (certificate['certificate_number'] ?? '').toString();
    final issuedAt = officialCertificateIssueDate(certificate);

    return Container(
      key: const Key('official-certificate-card'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.workspace_premium_outlined, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (certificate['event_title'] ?? 'Event').toString(),
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (certificate['category_name'] ?? 'Category').toString(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  isRevoked ? 'Revoked' : 'Available',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CertificateDetail(label: 'Certificate Number', value: number),
          _CertificateDetail(label: 'Issue Date', value: issuedAt),
          if ((isValid && downloadUrl.isNotEmpty) ||
              verificationUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isValid && downloadUrl.isNotEmpty)
                  FilledButton.icon(
                    key: const Key('official-certificate-download'),
                    onPressed: () => onOpenUrl(downloadUrl),
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Download'),
                  ),
                if (verificationUrl.isNotEmpty)
                  OutlinedButton.icon(
                    key: const Key('official-certificate-verify'),
                    onPressed: () => onOpenUrl(verificationUrl),
                    icon: const Icon(Icons.verified_outlined, size: 18),
                    label: const Text('Verify'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CertificateDetail extends StatelessWidget {
  final String label;
  final String value;

  const _CertificateDetail({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 126,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCertificates extends StatelessWidget {
  const _EmptyCertificates();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(28),
      children: const [
        SizedBox(height: 100),
        Icon(
          Icons.workspace_premium_outlined,
          size: 64,
          color: Color(0xFF2563EB),
        ),
        SizedBox(height: 16),
        Text(
          'No official E-Certificates yet',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Your E-Certificate will appear after an eligible official result is published.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _CertificateError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CertificateError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 52,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
