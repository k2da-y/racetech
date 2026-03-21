import 'package:flutter/material.dart';
import 'package:racetechph/pages/places_page.dart';
import 'package:racetechph/profile/badges_page.dart';
import 'login_page.dart';
import '../profile/help_support_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/training_module_page.dart';
import '../profile/community_page.dart';
import '../profile/edit_password.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  Widget menuItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15),
        child: Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16)
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              // 🔥 MODERN HEADER
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F2027), Color(0xFF2C5364)],
                  ),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [

                    // TOP BAR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PlacesPage(),
                              ),
                            );
                          },
                          child: const Icon(Icons.arrow_back, color: Colors.white),
                        ),

                        const Text(
                          "My Profile",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => LoginPage(),
                              ),
                            );
                          },
                          child: const Icon(Icons.logout, color: Colors.white),
                        ),

                      ],
                    ),

                    const SizedBox(height: 25),

                    // PROFILE INFO
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, size: 40, color: Colors.black),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Keith Garcia",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    const Text(
                      "keithgarcia@gmail.com",
                      style: TextStyle(color: Colors.white70),
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔥 ACCOUNT SECTION
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [

                    menuItem(
                      title: "Badges",
                      icon: Icons.emoji_events_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BadgesPage(),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    menuItem(
                      title: "Edit Password",
                      icon: Icons.lock_outline,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditPasswordPage(),
                          ),
                        );
                      },
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 15),

              // 🔥 MORE SECTION
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [

                    menuItem(
                      title: "Training Module",
                      icon: Icons.menu_book_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TrainingModulePage(),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    menuItem(
                      title: "Privacy Policy",
                      icon: Icons.privacy_tip_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PrivacyPolicyPage(),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    menuItem(
                      title: "Help & Support",
                      icon: Icons.support_agent_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HelpSupportPage(),
                          ),
                        );
                      },
                    ),

                    const Divider(),

                    menuItem(
                      title: "Community",
                      icon: Icons.groups_outlined,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CommunityPage(),
                          ),
                        );
                      },
                    ),

                  ],
                ),
              ),

              const SizedBox(height: 20),

            ],
          ),
        ),
      ),
    );
  }
}