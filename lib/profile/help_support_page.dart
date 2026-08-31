import 'package:flutter/material.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key});

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

                    _SupportSection(
                      title: "Getting Started",
                      icon: Icons.flag_outlined,
                      children: [
                        _FaqItem(
                          question: "What is Racetech?",
                          answer:
                              "Racetech is a mobile-based platform for running and recreational event management. It helps users discover events, register for activities, view training modules, track badges, check leaderboards, and interact with the community.",
                        ),
                        _FaqItem(
                          question: "Who can use the app?",
                          answer:
                              "The app is designed for users who want to join running or recreational events. Some events may require complete profile details, emergency contact information, or organizer approval before participation.",
                        ),
                        _FaqItem(
                          question: "Why do I need to complete my profile?",
                          answer:
                              "Your profile details help organizers verify your registration and support participant safety. Important details may include your phone number, address, birthdate, emergency contact, and medical conditions if applicable.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Events and Registration",
                      icon: Icons.event_outlined,
                      children: [
                        _FaqItem(
                          question: "How do I join an event?",
                          answer:
                              "Go to the Events section, choose an available event, select an open category, provide the required registration details, accept the waiver, and submit your registration.",
                        ),
                        _FaqItem(
                          question: "Why is the Join Event button unavailable?",
                          answer:
                              "The button may be unavailable if the event is not upcoming, if registration is already closed, or if you are already registered for that event.",
                        ),
                        _FaqItem(
                          question:
                              "What does Pending, Approved, Checked In, or Completed mean?",
                          answer:
                              "Pending means your registration is waiting for review. Approved means you are accepted for the event. Checked In means you have been recorded at the event. Completed means your event participation has been finished.",
                        ),
                        _FaqItem(
                          question: "Where can I see my registrations?",
                          answer:
                              "You can view your event registrations in My Profile > My Activity > Registrations.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Training, Badges, and Leaderboard",
                      icon: Icons.emoji_events_outlined,
                      children: [
                        _FaqItem(
                          question: "What are training modules?",
                          answer:
                              "Training modules are guides, programs, warmups, safety reminders, or activity-based content that can help you prepare for your selected recreational activity.",
                        ),
                        _FaqItem(
                          question: "How do I unlock badges?",
                          answer:
                              "Badges are unlocked based on your app activity, such as joining events, participating consistently, engaging with the community, or achieving event-related milestones.",
                        ),
                        _FaqItem(
                          question: "How is the leaderboard ranked?",
                          answer:
                              "The leaderboard is based on the number of badges unlocked by users. Users with more unlocked badges may appear higher in the ranking.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Community and Posting",
                      icon: Icons.groups_outlined,
                      children: [
                        _FaqItem(
                          question: "What can I post in the community?",
                          answer:
                              "You can share event experiences, recreational activity updates, photos, questions, and positive community content related to the app and events.",
                        ),
                        _FaqItem(
                          question: "Why was my post not accepted?",
                          answer:
                              "Your post may not be accepted if it contains restricted, unsafe, inappropriate, or offensive words. Community content should remain respectful and event-related.",
                        ),
                        _FaqItem(
                          question: "Can other users see my posts?",
                          answer:
                              "Yes. Community posts may show your name, post content, image, likes, and comments depending on the app feature.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Notifications",
                      icon: Icons.notifications_none,
                      children: [
                        _FaqItem(
                          question: "What notifications will I receive?",
                          answer:
                              "You may receive notifications about event reminders, registration updates, announcements, comments, community activity, and other important app updates.",
                        ),
                        _FaqItem(
                          question: "Why am I not receiving notifications?",
                          answer:
                              "Check if notifications are enabled on your device, if your internet connection is active, and if the app has permission to send notifications. Push notifications are commonly used by apps to send real-time reminders and updates.",
                        ),
                        _FaqItem(
                          question: "How do I mark notifications as read?",
                          answer:
                              "Open the notification dialog and tap a notification to mark it as read. You may also use the Read All option if there are unread notifications.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Account and Security",
                      icon: Icons.security_outlined,
                      children: [
                        _FaqItem(
                          question: "How do I update my profile?",
                          answer:
                              "Go to My Profile > Profile Settings. From there, you can update your personal details, emergency contact, and medical information.",
                        ),
                        _FaqItem(
                          question: "How do I change my password?",
                          answer:
                              "Go to My Profile > Edit Password. Enter your current password, your new password, and confirm the new password before saving.",
                        ),
                        _FaqItem(
                          question: "What should I do if I cannot log in?",
                          answer:
                              "Check your email and password first. If the issue continues, contact the app administrator or support team for account assistance.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _SupportSection(
                      title: "Privacy and Data",
                      icon: Icons.privacy_tip_outlined,
                      children: [
                        _FaqItem(
                          question:
                              "Why does the app collect personal information?",
                          answer:
                              "The app collects personal information to manage your account, support event registration, verify participant details, send notifications, process community features, and improve event safety.",
                        ),
                        _FaqItem(
                          question: "Is my information shared with others?",
                          answer:
                              "Your information is not sold. However, necessary information may be shared with authorized organizers, administrators, technical providers, or emergency responders when needed for event operations and safety.",
                        ),
                        _FaqItem(
                          question: "Where can I read the full Privacy Policy?",
                          answer:
                              "You can read the full policy by going to My Profile > Privacy Policy.",
                        ),
                      ],
                    ),

                    SizedBox(height: 15),

                    _ContactSupportCard(),

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
                    "Help and Support",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Frequently asked questions",
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
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              child: const Icon(
                Icons.support_agent_outlined,
                color: Color(0xFF2563EB),
              ),
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
          Icon(Icons.help_outline, color: Color(0xFF2563EB), size: 26),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Need help using Racetech? Browse the FAQs below for quick answers about events, registration, training modules, badges, notifications, account settings, and privacy.",
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

class _SupportSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SupportSection({
    required this.title,
    required this.icon,
    required this.children,
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

          const SizedBox(height: 12),

          ...children,
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: const Color(0xFFEAF2FF),
        highlightColor: const Color(0xFFEAF2FF),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
        iconColor: const Color(0xFF2563EB),
        collapsedIconColor: const Color(0xFF64748B),
        title: Text(
          question,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              answer,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD8E7FF)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.contact_support_outlined,
            color: Color(0xFF2563EB),
            size: 38,
          ),
          SizedBox(height: 12),
          Text(
            "Still need help?",
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Please contact the app administrator, event organizer, or support team assigned to your event. Include your name, event title, concern, and screenshot if available.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              height: 1.4,
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
            "Racetech Support",
            style: TextStyle(
              color: Color(0xFF111827),
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            "Mobile-Based Platform for Running and Recreational Event Management",
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
