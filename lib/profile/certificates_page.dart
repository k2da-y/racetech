import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';
import '../utils/official_certificate.dart';
import '../utils/registration_certificate.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _success = Color(0xFF16A34A);
const _danger = Color(0xFFDC2626);
const _warning = Color(0xFFD97706);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

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

  // ============================================================
  // DATA — logic unchanged
  // ============================================================

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

  Future<void> copyNumber(String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!mounted) return;
    HapticFeedback.selectionClick();
    showMessage('Certificate number copied.');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final availableCount = certificates
        .where((item) => certificateStatus(item) == 'available')
        .length;
    final showFullError = errorMessage.isNotEmpty && certificates.isEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: RefreshIndicator(
          color: _primary,
          onRefresh: () => loadCertificates(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _CertificatesHero(
                  isLoading: isLoading,
                  totalCount: certificates.length,
                  availableCount: availableCount,
                  onBack: () => Navigator.maybePop(context),
                  onRefresh: isLoading ? null : () => loadCertificates(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: isLoading
                          ? const _LoadingList()
                          : showFullError
                          ? _CertificateError(
                              message: errorMessage,
                              onRetry: loadCertificates,
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // A refresh can fail while old certificates
                                // are still shown — tell the user instead of
                                // silently showing stale data.
                                if (errorMessage.isNotEmpty) ...[
                                  _RefreshErrorBanner(
                                    message: errorMessage,
                                    onRetry: () => loadCertificates(),
                                  ),
                                  const SizedBox(height: 14),
                                ],
                                if (certificates.isEmpty)
                                  const _EmptyCertificates()
                                else
                                  for (final certificate in certificates)
                                    _CertificateCard(
                                      certificate: certificate,
                                      onOpenUrl: openUrl,
                                      onCopyNumber: copyNumber,
                                    ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HERO HEADER
// ============================================================

class _CertificatesHero extends StatelessWidget {
  final bool isLoading;
  final int totalCount;
  final int availableCount;
  final VoidCallback onBack;
  final VoidCallback? onRefresh;

  const _CertificatesHero({
    required this.isLoading,
    required this.totalCount,
    required this.availableCount,
    required this.onBack,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDeep, _primary, _accent],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Back',
                    onTap: onBack,
                  ),
                  const Expanded(
                    child: Text(
                      'E-Certificates',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _GlassButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh certificates',
                    onTap: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isLoading ? '–' : '$totalCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                totalCount == 1
                    ? 'Official E-Certificate'
                    : 'Official E-Certificates',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isLoading && totalCount > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.download_done_rounded,
                        color: _primary,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$availableCount ready to download',
                        style: const TextStyle(
                          color: _primaryDeep,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CERTIFICATE CARD
// ============================================================

class _CertificateCard extends StatelessWidget {
  final Map<String, dynamic> certificate;
  final ValueChanged<String> onOpenUrl;
  final ValueChanged<String> onCopyNumber;

  const _CertificateCard({
    required this.certificate,
    required this.onOpenUrl,
    required this.onCopyNumber,
  });

  @override
  Widget build(BuildContext context) {
    final status = certificateStatus(certificate);
    final isRevoked = status == 'revoked';
    final isValid = status == 'available';
    // Anything other than available/revoked (e.g. pending) gets its own
    // neutral label instead of being shown as "Available".
    final (statusLabel, color, statusIcon) = isRevoked
        ? ('Revoked', _danger, Icons.block_rounded)
        : isValid
        ? ('Available', _success, Icons.check_circle_rounded)
        : (_prettyStatus(status), _warning, Icons.schedule_rounded);
    final downloadUrl = certificateDownloadUrl(certificate);
    final verificationUrl = certificateVerificationUrl(certificate);
    final number = (certificate['certificate_number'] ?? '').toString();
    final issuedAt = officialCertificateIssueDate(certificate);
    final hasActions =
        (isValid && downloadUrl.isNotEmpty) || verificationUrl.isNotEmpty;

    return Container(
      key: const Key('official-certificate-card'),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Thin colored strip shows the status at a glance.
          Container(height: 4, color: color),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 50,
                      width: 50,
                      decoration: BoxDecoration(
                        color: isRevoked
                            ? _danger.withValues(alpha: 0.08)
                            : const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRevoked
                              ? _danger.withValues(alpha: 0.2)
                              : const Color(0xFFFED7AA),
                        ),
                      ),
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: isRevoked ? _danger : const Color(0xFFF59E0B),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (certificate['event_title'] ?? 'Event').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            (certificate['category_name'] ?? 'Category')
                                .toString(),
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: color),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (number.trim().isNotEmpty || issuedAt.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      children: [
                        _CertificateDetail(
                          icon: Icons.tag_rounded,
                          label: 'Certificate Number',
                          value: number,
                          onCopy: number.trim().isEmpty
                              ? null
                              : () => onCopyNumber(number),
                        ),
                        if (number.trim().isNotEmpty &&
                            issuedAt.trim().isNotEmpty)
                          const Divider(height: 1, color: _border),
                        _CertificateDetail(
                          icon: Icons.event_available_outlined,
                          label: 'Issue Date',
                          value: issuedAt,
                        ),
                      ],
                    ),
                  ),
                ],

                if (isRevoked) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _danger.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: _danger,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This certificate was revoked by the organizer and can no longer be downloaded.',
                            style: TextStyle(
                              color: _danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (hasActions) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      if (isValid && downloadUrl.isNotEmpty)
                        Expanded(
                          child: FilledButton.icon(
                            key: const Key('official-certificate-download'),
                            onPressed: () => onOpenUrl(downloadUrl),
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text(
                              'Download',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      if (isValid &&
                          downloadUrl.isNotEmpty &&
                          verificationUrl.isNotEmpty)
                        const SizedBox(width: 10),
                      if (verificationUrl.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            key: const Key('official-certificate-verify'),
                            onPressed: () => onOpenUrl(verificationUrl),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.verified_outlined, size: 18),
                            label: const Text(
                              'Verify',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _prettyStatus(String value) {
  final cleaned = value.trim().replaceAll(RegExp(r'[_\-]+'), ' ');
  if (cleaned.isEmpty) return 'Pending';
  return cleaned
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

class _CertificateDetail extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _CertificateDetail({
    required this.icon,
    required this.label,
    required this.value,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                SelectableText(
                  value,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              onPressed: onCopy,
              tooltip: 'Copy',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 17, color: _faint),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY / ERROR / LOADING
// ============================================================

class _EmptyCertificates extends StatelessWidget {
  const _EmptyCertificates();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.workspace_premium_outlined,
              size: 30,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No official E-Certificates yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your E-Certificate will appear after an eligible official result is published.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificateError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CertificateError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _fieldFill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: const Icon(
              Icons.cloud_off_outlined,
              size: 30,
              color: _muted,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Couldn't load your certificates",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _RefreshErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18, color: _warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: _primaryDeep,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatefulWidget {
  const _LoadingList();

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget block({double? width, required double height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _softShadow,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    block(width: 50, height: 50, radius: 16),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          block(width: double.infinity, height: 16),
                          const SizedBox(height: 8),
                          block(width: 120, height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                block(width: double.infinity, height: 88, radius: 16),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: block(height: 46, radius: 14)),
                    const SizedBox(width: 10),
                    Expanded(child: block(height: 46, radius: 14)),
                  ],
                ),
              ],
            ),
          ),
      ],
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}
