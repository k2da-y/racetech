import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

// ============================================================
// POLICY CONTENT — wording unchanged from the original page
// ============================================================

class _PolicyItem {
  final IconData icon;
  final String title;
  final String content;

  const _PolicyItem(this.icon, this.title, this.content);
}

const List<_PolicyItem> _sections = [
  _PolicyItem(
    Icons.info_outline_rounded,
    "Introduction",
    "Racetech respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect your data when you use the app for recreational events, training modules, community posts, event registration, notifications, and user profile management.",
  ),
  _PolicyItem(
    Icons.person_outline_rounded,
    "Information We Collect",
    "We may collect personal information such as your name, email address, phone number, gender, birthdate, address, emergency contact name, emergency contact number, and account login details. We may also collect event-related information such as your selected recreational activities, event registrations, category, shirt size, BIB number, race results, rankings, community posts, comments, likes, and notification activity.",
  ),
  _PolicyItem(
    Icons.health_and_safety_outlined,
    "Sensitive Personal Information",
    "For event safety purposes, we may collect sensitive personal information such as medical conditions and emergency contact details. This information is collected only when necessary for participant safety, emergency response, event coordination, and compliance with organizer requirements.",
  ),
  _PolicyItem(
    Icons.task_alt_outlined,
    "How We Use Your Information",
    "Your information may be used to create and manage your account, verify your identity, complete event registration, recommend activities and training modules, manage event participation, display your E-Certificates and leaderboard ranking, process community features, send event reminders and notifications, provide support, improve app performance, and maintain event safety.",
  ),
  _PolicyItem(
    Icons.verified_user_outlined,
    "Legal Basis for Processing",
    "We process your personal data based on your consent, the need to provide app and event services, legitimate event management purposes, safety requirements, and compliance with applicable laws and regulations in the Philippines, including the Data Privacy Act of 2012.",
  ),
  _PolicyItem(
    Icons.share_outlined,
    "Data Sharing",
    "We do not sell your personal information. However, your data may be shared with authorized event organizers, administrators, technical service providers, emergency responders, or government authorities when necessary for event operations, safety, legal compliance, or support services. Only necessary information will be shared.",
  ),
  _PolicyItem(
    Icons.lock_outline_rounded,
    "Data Protection and Security",
    "We apply reasonable security measures to help protect your personal data against unauthorized access, loss, misuse, alteration, or disclosure. Access to your information is limited to authorized personnel or service providers who need it for legitimate app or event-related purposes.",
  ),
  _PolicyItem(
    Icons.schedule_outlined,
    "Data Retention",
    "We retain your personal information only for as long as necessary to fulfill the purposes stated in this Privacy Policy, support event records, comply with legal obligations, resolve disputes, maintain account history, and improve app services. When data is no longer needed, it may be securely deleted, anonymized, or archived according to applicable policies.",
  ),
  _PolicyItem(
    Icons.account_circle_outlined,
    "Your Privacy Rights",
    "Under Philippine data privacy rules, you may have the right to be informed, access your personal data, request correction of inaccurate data, object to processing, request deletion or blocking, withdraw consent when applicable, request data portability, file a complaint, and claim damages when allowed by law.",
  ),
  _PolicyItem(
    Icons.notifications_none_rounded,
    "Notifications and Communications",
    "The app may send you notifications about event reminders, registration updates, announcements, comments, community activity, and other app-related updates. These notifications are intended to support your participation and improve your experience in the app.",
  ),
  _PolicyItem(
    Icons.groups_outlined,
    "Community Posts",
    "When you create posts or interact with community content, your name, post content, images, likes, comments, and related activity may be visible to other users depending on the app feature. You are responsible for the information you choose to share publicly within the community space.",
  ),
  _PolicyItem(
    Icons.child_care_outlined,
    "Minors",
    "If the app is used by minors, registration or participation in events should be done with the guidance and consent of a parent, guardian, school, or authorized representative, depending on the event requirement.",
  ),
  _PolicyItem(
    Icons.edit_note_outlined,
    "Updates to this Policy",
    "We may update this Privacy Policy from time to time to reflect changes in app features, event operations, legal requirements, or data protection practices. Any significant changes may be communicated through the app or other appropriate channels.",
  ),
  _PolicyItem(
    Icons.support_agent_outlined,
    "Contact Us",
    "For privacy-related questions, requests, corrections, or concerns, you may contact the app administrator or event organizer through the official support channels provided in the app.",
  ),
];

// ============================================================
// PAGE
// ============================================================

class PrivacyPolicyPage extends StatefulWidget {
  const PrivacyPolicyPage({super.key});

  @override
  State<PrivacyPolicyPage> createState() => _PrivacyPolicyPageState();
}

class _PrivacyPolicyPageState extends State<PrivacyPolicyPage> {
  /// Sections start open so nothing is hidden; users can collapse what
  /// they've read, or collapse everything to scan the headings.
  final Set<int> _expanded = {
    for (var i = 0; i < _sections.length; i++) i,
  };

  final _scrollController = ScrollController();
  bool _showBackToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 600;
      if (show != _showBackToTop) setState(() => _showBackToTop = show);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _allExpanded => _expanded.length == _sections.length;

  void _toggleAll() {
    setState(() {
      if (_allExpanded) {
        _expanded.clear();
      } else {
        _expanded.addAll(List.generate(_sections.length, (i) => i));
      }
    });
  }

  void _toggle(int index) {
    setState(() {
      if (!_expanded.remove(index)) _expanded.add(index);
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        floatingActionButton: AnimatedScale(
          scale: _showBackToTop ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          child: FloatingActionButton.small(
            onPressed: _scrollToTop,
            tooltip: "Back to top",
            backgroundColor: Colors.white,
            foregroundColor: _primary,
            elevation: 3,
            child: const Icon(Icons.keyboard_arrow_up_rounded),
          ),
        ),
        body: CustomScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(onBack: () => Navigator.pop(context)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _IntroCard(),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Text(
                              "${_sections.length} sections",
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: _toggleAll,
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              icon: Icon(
                                _allExpanded
                                    ? Icons.unfold_less_rounded
                                    : Icons.unfold_more_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _allExpanded ? "Collapse all" : "Expand all",
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        for (var i = 0; i < _sections.length; i++) ...[
                          _PolicySection(
                            number: i + 1,
                            item: _sections[i],
                            expanded: _expanded.contains(i),
                            onTap: () => _toggle(i),
                          ),
                          const SizedBox(height: 12),
                        ],
                        const SizedBox(height: 8),
                        const _FooterNote(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _Hero extends StatelessWidget {
  final VoidCallback onBack;

  const _Hero({required this.onBack});

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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(14),
                      child: const Tooltip(
                        message: "Back",
                        child: SizedBox(
                          height: 44,
                          width: 44,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Privacy Policy",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "How Racetech handles your data",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.gavel_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      "Data Privacy Act of 2012 (RA 10173)",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
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
// CARDS
// ============================================================

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: _primaryDeep, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "This policy is written for a recreational event management app in the Philippines. It is a practical app policy draft and should be reviewed by your adviser, organization, or legal/privacy officer before official use.",
              style: TextStyle(
                color: _primaryDeep,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final int number;
  final _PolicyItem item;
  final bool expanded;
  final VoidCallback onTap;

  const _PolicySection({
    required this.number,
    required this.item,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      height: 40,
                      width: 40,
                      decoration: BoxDecoration(
                        color: _primarySoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(item.icon, color: _primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "SECTION $number",
                            style: const TextStyle(
                              color: _faint,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        height: 32,
                        width: 32,
                        decoration: BoxDecoration(
                          color: _fieldFill,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _muted,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Padding(
                    padding: const EdgeInsets.only(top: 12, right: 4),
                    child: SelectableText(
                      item.content,
                      style: const TextStyle(
                        color: _body,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.6,
                      ),
                    ),
                  )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_rounded, color: _primary, size: 16),
              SizedBox(width: 6),
              Text(
                "Last updated: 2026",
                style: TextStyle(
                  color: _ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Text(
            "Racetech: Mobile-Based Platform for Running and Recreational Event Management",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}