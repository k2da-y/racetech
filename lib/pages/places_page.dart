import 'package:flutter/material.dart';
import 'user_profile_page.dart';
import '../profile/training_module_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/help_support_page.dart';
import 'login_page.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {

  int currentIndex = 0;

  final List<String> images = [
    "assets/place1.jpg",
    "assets/place2.jpg",
    "assets/place3.jpg"
  ];

  void nextImage() {
    setState(() {
      currentIndex = (currentIndex + 1) % images.length;
    });
  }

  void previousImage() {
    setState(() {
      currentIndex = (currentIndex - 1 + images.length) % images.length;
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

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                alignment: Alignment.center,
                children: [

                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Back"),
                    ),
                  ),

                  const Text(
                    "Places",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "CAVITE LOOP",
              style: TextStyle(fontSize: 18),
            ),

            const SizedBox(height: 20),

            Row(
              children: [

                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: previousImage,
                ),

                Expanded(
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: AssetImage(images[currentIndex]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),

                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: previousImage,
                ),

              ],
            ),

            const SizedBox(height: 25),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 25),
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [

                  const Text(
                    "EVENT START\nMARCH 29, 2026\n6:00 AM PHT",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "add details here.",
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.grey[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "JOIN HERE!!",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}