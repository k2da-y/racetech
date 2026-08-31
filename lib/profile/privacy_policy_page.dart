import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: Column(
          children: [
            _HeaderSection(onBack: () => Navigator.pop(context)),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  children: const [
                    _IntroCard(),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.info_outline,
                      title: "1. Introduction",
                      content:
                          "Racetech respects your privacy and is committed to protecting your personal information. This Privacy Policy explains how we collect, use, store, and protect your data when you use the app for recreational events, training modules, community posts, event registration, notifications, and user profile management.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.person_outline,
                      title: "2. Information We Collect",
                      content:
                          "We may collect personal information such as your name, email address, phone number, gender, birthdate, address, emergency contact name, emergency contact number, and account login details. We may also collect event-related information such as your selected recreational activities, event registrations, category, shirt size, BIB number, race results, rankings, community posts, comments, likes, and notification activity.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.health_and_safety_outlined,
                      title: "3. Sensitive Personal Information",
                      content:
                          "For event safety purposes, we may collect sensitive personal information such as medical conditions and emergency contact details. This information is collected only when necessary for participant safety, emergency response, event coordination, and compliance with organizer requirements.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.task_alt_outlined,
                      title: "4. How We Use Your Information",
                      content:
                          "Your information may be used to create and manage your account, verify your identity, complete event registration, recommend activities and training modules, manage event participation, display your badges and leaderboard ranking, process community features, send event reminders and notifications, provide support, improve app performance, and maintain event safety.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.verified_user_outlined,
                      title: "5. Legal Basis for Processing",
                      content:
                          "We process your personal data based on your consent, the need to provide app and event services, legitimate event management purposes, safety requirements, and compliance with applicable laws and regulations in the Philippines, including the Data Privacy Act of 2012.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.share_outlined,
                      title: "6. Data Sharing",
                      content:
                          "We do not sell your personal information. However, your data may be shared with authorized event organizers, administrators, technical service providers, emergency responders, or government authorities when necessary for event operations, safety, legal compliance, or support services. Only necessary information will be shared.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.lock_outline,
                      title: "7. Data Protection and Security",
                      content:
                          "We apply reasonable security measures to help protect your personal data against unauthorized access, loss, misuse, alteration, or disclosure. Access to your information is limited to authorized personnel or service providers who need it for legitimate app or event-related purposes.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.schedule_outlined,
                      title: "8. Data Retention",
                      content:
                          "We retain your personal information only for as long as necessary to fulfill the purposes stated in this Privacy Policy, support event records, comply with legal obligations, resolve disputes, maintain account history, and improve app services. When data is no longer needed, it may be securely deleted, anonymized, or archived according to applicable policies.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.account_circle_outlined,
                      title: "9. Your Privacy Rights",
                      content:
                          "Under Philippine data privacy rules, you may have the right to be informed, access your personal data, request correction of inaccurate data, object to processing, request deletion or blocking, withdraw consent when applicable, request data portability, file a complaint, and claim damages when allowed by law.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.notifications_none,
                      title: "10. Notifications and Communications",
                      content:
                          "The app may send you notifications about event reminders, registration updates, announcements, comments, community activity, and other app-related updates. These notifications are intended to support your participation and improve your experience in the app.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.groups_outlined,
                      title: "11. Community Posts",
                      content:
                          "When you create posts or interact with community content, your name, post content, images, likes, comments, and related activity may be visible to other users depending on the app feature. You are responsible for the information you choose to share publicly within the community space.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.child_care_outlined,
                      title: "12. Minors",
                      content:
                          "If the app is used by minors, registration or participation in events should be done with the guidance and consent of a parent, guardian, school, or authorized representative, depending on the event requirement.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.edit_note_outlined,
                      title: "13. Updates to this Policy",
                      content:
                          "We may update this Privacy Policy from time to time to reflect changes in app features, event operations, legal requirements, or data protection practices. Any significant changes may be communicated through the app or other appropriate channels.",
                    ),

                    SizedBox(height: 15),

                    _PolicySection(
                      icon: Icons.support_agent_outlined,
                      title: "14. Contact Us",
                      content:
                          "For privacy-related questions, requests, corrections, or concerns, you may contact the app administrator or event organizer through the official support channels provided in the app.",
                    ),

                    SizedBox(height: 20),

                    _FooterNote(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final VoidCallback onBack;

  const _HeaderSection({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEAF2FF),
                foregroundColor: const Color(0xFF2563EB),
              ),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Privacy Policy",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "How Racetech handles your data",
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Color(0xFFEAF2FF),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: Icon(Icons.privacy_tip_outlined, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF2563EB), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "This policy is written for a recreational event management app in the Philippines. It is a practical app policy draft and should be reviewed by your adviser, organization, or legal/privacy officer before official use.",
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;

  const _PolicySection({
    required this.icon,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
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
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            content,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Column(
        children: [
          Text(
            "Last updated: 2026",
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Racetech: Mobile-Based Platform for Running and Recreational Event Management",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
