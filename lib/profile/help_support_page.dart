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
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

// ============================================================
// FAQ CONTENT — wording unchanged from the original page
// ============================================================

class _Faq {
  final String question;
  final String answer;

  const _Faq(this.question, this.answer);
}

class _FaqGroup {
  final String title;
  final IconData icon;
  final List<_Faq> items;

  const _FaqGroup(this.title, this.icon, this.items);
}

const List<_FaqGroup> _groups = [
  _FaqGroup("Getting Started", Icons.flag_outlined, [
    _Faq(
      "What is Racetech?",
      "Racetech is a mobile-based platform for running and recreational event management. It helps users discover events, register for activities, view training modules, track E-Certificates, check leaderboards, and interact with the community.",
    ),
    _Faq(
      "Who can use the app?",
      "The app is designed for users who want to join running or recreational events. Some events may require complete profile details, emergency contact information, or organizer approval before participation.",
    ),
    _Faq(
      "Why do I need to complete my profile?",
      "Your profile details help organizers verify your registration and support participant safety. Important details may include your phone number, address, birthdate, emergency contact, and medical conditions if applicable.",
    ),
  ]),
  _FaqGroup("Events and Registration", Icons.event_outlined, [
    _Faq(
      "How do I join an event?",
      "Go to the Events section, choose an available event, select an open category, provide the required registration details, accept the waiver, and submit your registration.",
    ),
    _Faq(
      "Why is the Join Event button unavailable?",
      "The button may be unavailable if the event is not upcoming, if registration is already closed, or if you are already registered for that event.",
    ),
    _Faq(
      "What does Pending, Approved, Checked In, or Completed mean?",
      "Pending means your registration is waiting for review. Approved means you are accepted for the event. Checked In means you have been recorded at the event. Completed means your event participation has been finished.",
    ),
    _Faq(
      "Where can I see my registrations?",
      "You can view your event registrations in My Profile > My Activity > Registrations.",
    ),
  ]),
  _FaqGroup(
    "Training, E-Certificates, and Leaderboard",
    Icons.emoji_events_outlined,
    [
      _Faq(
        "What are training modules?",
        "Training modules are guides, programs, warmups, safety reminders, or activity-based content that can help you prepare for your selected recreational activity.",
      ),
      _Faq(
        "How do I unlock E-Certificates?",
        "E-Certificates are issued after you complete an eligible event and your official result is published.",
      ),
      _Faq(
        "How is the leaderboard ranked?",
        "The leaderboard is based on the number of E-Certificates earned by users. Users with more E-Certificates may appear higher in the ranking.",
      ),
    ],
  ),
  _FaqGroup("Community and Posting", Icons.groups_outlined, [
    _Faq(
      "What can I post in the community?",
      "You can share event experiences, recreational activity updates, photos, questions, and positive community content related to the app and events.",
    ),
    _Faq(
      "Why was my post not accepted?",
      "Your post may not be accepted if it contains restricted, unsafe, inappropriate, or offensive words. Community content should remain respectful and event-related.",
    ),
    _Faq(
      "Can other users see my posts?",
      "Yes. Community posts may show your name, post content, image, likes, and comments depending on the app feature.",
    ),
  ]),
  _FaqGroup("Notifications", Icons.notifications_none_rounded, [
    _Faq(
      "What notifications will I receive?",
      "You may receive notifications about event reminders, registration updates, announcements, comments, community activity, and other important app updates.",
    ),
    _Faq(
      "Why am I not receiving notifications?",
      "Check if notifications are enabled on your device, if your internet connection is active, and if the app has permission to send notifications. Push notifications are commonly used by apps to send real-time reminders and updates.",
    ),
    _Faq(
      "How do I mark notifications as read?",
      "Open the notification dialog and tap a notification to mark it as read. You may also use the Read All option if there are unread notifications.",
    ),
  ]),
  _FaqGroup("Account and Security", Icons.security_outlined, [
    _Faq(
      "How do I update my profile?",
      "Go to My Profile > Profile Settings. From there, you can update your personal details, emergency contact, and medical information.",
    ),
    _Faq(
      "How do I change my password?",
      "Go to My Profile > Edit Password. Enter your current password, your new password, and confirm the new password before saving.",
    ),
    _Faq(
      "What should I do if I cannot log in?",
      "Check your email and password first. If the issue continues, contact the app administrator or support team for account assistance.",
    ),
  ]),
  _FaqGroup("Privacy and Data", Icons.privacy_tip_outlined, [
    _Faq(
      "Why does the app collect personal information?",
      "The app collects personal information to manage your account, support event registration, verify participant details, send notifications, process community features, and improve event safety.",
    ),
    _Faq(
      "Is my information shared with others?",
      "Your information is not sold. However, necessary information may be shared with authorized organizers, administrators, technical providers, or emergency responders when needed for event operations and safety.",
    ),
    _Faq(
      "Where can I read the full Privacy Policy?",
      "You can read the full policy by going to My Profile > Privacy Policy.",
    ),
  ]),
];

// ============================================================
// PAGE
// ============================================================

class HelpSupportPage extends StatefulWidget {
  const HelpSupportPage({super.key});

  @override
  State<HelpSupportPage> createState() => _HelpSupportPageState();
}

class _HelpSupportPageState extends State<HelpSupportPage> {
  final _searchController = TextEditingController();
  String _query = "";

  /// "groupIndex:faqIndex" of questions that are open.
  final Set<String> _open = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  int get _totalQuestions =>
      _groups.fold(0, (sum, group) => sum + group.items.length);

  bool _matches(_Faq faq) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return faq.question.toLowerCase().contains(q) ||
        faq.answer.toLowerCase().contains(q);
  }

  void _toggle(String key) {
    setState(() {
      if (!_open.remove(key)) _open.add(key);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() => _query = "");
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;

    // Groups with only the matching questions (all of them when not searching).
    final visibleGroups = <(int, _FaqGroup, List<(int, _Faq)>)>[];
    for (var g = 0; g < _groups.length; g++) {
      final matches = <(int, _Faq)>[
        for (var f = 0; f < _groups[g].items.length; f++)
          if (_matches(_groups[g].items[f])) (f, _groups[g].items[f]),
      ];
      if (matches.isNotEmpty) visibleGroups.add((g, _groups[g], matches));
    }
    final matchCount = visibleGroups.fold<int>(
      0,
          (sum, entry) => sum + entry.$3.length,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _Hero(
                controller: _searchController,
                totalQuestions: _totalQuestions,
                onBack: () => Navigator.pop(context),
                onChanged: (value) => setState(() => _query = value),
                onClear: _clearSearch,
              ),
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
                        if (searching)
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              matchCount == 0
                                  ? "No results for “${_query.trim()}”"
                                  : "$matchCount ${matchCount == 1 ? "result" : "results"} for “${_query.trim()}”",
                              style: const TextStyle(
                                color: _muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        else ...[
                          const _IntroCard(),
                          const SizedBox(height: 16),
                        ],

                        if (searching && visibleGroups.isEmpty)
                          _NoResults(onClear: _clearSearch)
                        else
                          for (final (groupIndex, group, faqs)
                          in visibleGroups) ...[
                            _SupportSection(
                              title: group.title,
                              icon: group.icon,
                              count: faqs.length,
                              children: [
                                for (final (index, (faqIndex, faq))
                                in faqs.indexed) ...[
                                  if (index > 0)
                                    const Divider(height: 1, color: _border),
                                  _FaqItem(
                                    faq: faq,
                                    query: _query.trim(),
                                    // Matching answers open automatically
                                    // while searching.
                                    expanded:
                                    searching ||
                                        _open.contains("$groupIndex:$faqIndex"),
                                    onTap: () =>
                                        _toggle("$groupIndex:$faqIndex"),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

                        const SizedBox(height: 4),
                        const _ContactSupportCard(),
                        const SizedBox(height: 14),
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
// HERO (with FAQ search)
// ============================================================

class _Hero extends StatelessWidget {
  final TextEditingController controller;
  final int totalQuestions;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _Hero({
    required this.controller,
    required this.totalQuestions,
    required this.onBack,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 24),
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
                      "Help and Support",
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
              const SizedBox(height: 18),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "How can we help?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryDeep.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) => TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    cursorColor: _primary,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: "Search $totalQuestions questions...",
                      hintStyle: const TextStyle(
                        color: _faint,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _primary,
                      ),
                      suffixIcon: value.text.isEmpty
                          ? null
                          : IconButton(
                        onPressed: onClear,
                        tooltip: "Clear search",
                        icon: const Icon(
                          Icons.close_rounded,
                          color: _faint,
                        ),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
          Icon(Icons.help_outline_rounded, color: _primaryDeep, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Need help using Racetech? Browse the FAQs below for quick answers about events, registration, training modules, E-Certificates, notifications, account settings, and privacy.",
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

class _SupportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final List<Widget> children;

  const _SupportSection({
    required this.title,
    required this.icon,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
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
                child: Icon(icon, color: _primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: _border),
                ),
                child: Text(
                  "$count",
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final _Faq faq;
  final String query;
  final bool expanded;
  final VoidCallback onTap;

  const _FaqItem({
    required this.faq,
    required this.query,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Highlighted(
                    text: faq.question,
                    query: query,
                    style: TextStyle(
                      color: expanded ? _primaryDeep : _ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: expanded ? _primary : _faint,
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
                padding: const EdgeInsets.only(top: 8, right: 28),
                child: _Highlighted(
                  text: faq.answer,
                  query: query,
                  style: const TextStyle(
                    color: _body,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.55,
                  ),
                ),
              )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// Text with every occurrence of [query] highlighted.
class _Highlighted extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle style;

  const _Highlighted({
    required this.text,
    required this.query,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: style);

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final spans = <TextSpan>[];
    var start = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) break;
      if (index > start) spans.add(TextSpan(text: text.substring(start, index)));
      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFEF08A),
            color: _ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = index + query.length;
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));

    return Text.rich(TextSpan(style: style, children: spans));
  }
}

class _NoResults extends StatelessWidget {
  final VoidCallback onClear;

  const _NoResults({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.search_off_rounded, color: _primary, size: 28),
          ),
          const SizedBox(height: 14),
          const Text(
            "No matching questions",
            style: TextStyle(
              color: _ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Try a different word, or contact support below.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: _primary,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text("Clear search"),
          ),
        ],
      ),
    );
  }
}

class _ContactSupportCard extends StatelessWidget {
  const _ContactSupportCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primarySoft, Color(0xFFE0F2FE)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.contact_support_outlined,
              color: _primary,
              size: 28,
            ),
          ),
          SizedBox(height: 12),
          Text(
            "Still need help?",
            style: TextStyle(
              color: _ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Please contact the app administrator, event organizer, or support team assigned to your event. Include your name, event title, concern, and screenshot if available.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _body,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flag_rounded, color: _primary, size: 15),
              SizedBox(width: 6),
              Text(
                "Racetech Support",
                style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            "Mobile-Based Platform for Running and Recreational Event Management",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}