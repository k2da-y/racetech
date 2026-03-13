import 'package:flutter/material.dart';
import 'package:racetechph/pages/login_page.dart';
import 'package:racetechph/profile/help_support_page.dart';
import 'package:racetechph/profile/privacy_policy_page.dart';
import 'package:racetechph/profile/training_module_page.dart';
import 'user_profile_page.dart';
import 'places_page.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {

  int currentIndex = 0;

  final List<String> images = [
    "assets/hiking.jpg",
    "assets/running.jpg",
    "assets/marathon.jpg",
  ];


  void nextImage() {
    setState(() {
      currentIndex = (currentIndex + 1) % images.length;
    });
  }

  void previousImage() {
    setState(() {
      currentIndex =
          (currentIndex - 1 + images.length) % images.length;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [

            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                "RaceTech Menu",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                ),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.fitness_center),
              title: const Text("Training Module"),
              onTap: () {
                Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const TrainingModulePage(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text("Privacy Policy"),
              onTap: () {
                Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyPage(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.support_agent),
              title: const Text("Help and Support"),
              onTap: () {
                Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const HelpSupportPage(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.event),
              title: const Text("Event"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PlacesPage(),
                  ),
                );
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Log Out"),
              onTap: () {
                Navigator.push(context,
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              },
            ),

          ],
        ),
      ),

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

                  Builder(
                    builder: (context) => IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white),
                      onPressed: () {
                        Scaffold.of(context).openDrawer();
                      },
                    ),
                  ),

                  Text(
                    "RaceTech",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  IconButton(
                    icon: const Icon(Icons.person_outline, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfilePage(),
                        ),
                      );
                    },
                  ),

                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "WELCOME,",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Every event you join is a chance to grow, meet people who inspire you, and discover something new about yourself. One step outside your comfort zone today can open doors you never expected tomorrow.",
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 25),

                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PlacesPage(),
                          ),
                        );
                      },
                      child: const Text("Book an Event"),
                    ),

                    SizedBox(height: 25),

                    Row(
                      children: [

                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: previousImage,
                        ),

                        //dito yung pic
                        Expanded(
                          child: Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(10),
                              image: DecorationImage(
                                image: AssetImage(
                                    images[currentIndex]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        IconButton(
                          icon:
                          const Icon(Icons.arrow_forward),
                          onPressed: nextImage,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Center(
                      child: Text(
                        "When you move for fun,\nyou heal without even noticing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                        ),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}