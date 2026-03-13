import 'package:flutter/material.dart';
import 'package:racetechph/pages/user_home_page.dart';
import 'login_page.dart';
import '../profile/help_support_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/training_module_page.dart';

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  Widget menuItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
          const Divider()
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            Container(
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserHomePage(),
                        ),
                      );
                    },
                    child: const Text(
                      "RaceTech",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LoginPage(),
                        ),
                      );
                    },
                    child: const Text(
                      "Logout",
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

                  Text(
                    "My Profile",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),

            const SizedBox(height: 20),

            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Row(
                children: [

                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 35),
                  ),

                  const SizedBox(width: 20),

                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Keith Garcia",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "keithgarcia@gmail.com",
                        style: TextStyle(color: Colors.grey),
                      )
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [

                  menuItem("EDIT NAME"),
                  menuItem("CHANGE PASSWORD"),
                  menuItem("BADGES"),

                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TrainingModulePage(),
                        ),
                      );
                    },
                    child: menuItem("TRAINING MODULE"),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PrivacyPolicyPage(),
                        ),
                      );
                    },
                    child: menuItem("PRIVACY POLICY"),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportPage(),
                        ),
                      );
                    },
                    child: menuItem("HELP AND SUPPORT"),
                  ),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}