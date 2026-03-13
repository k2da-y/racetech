import 'package:flutter/material.dart';
import 'user_profile_page.dart';
import '../profile/training_module_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/help_support_page.dart';
import 'login_page.dart';
import 'user_home_page.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {

  int currentIndex = 0;

  final List<String> images = [
    "assets/map.jpg", //dito yung pic
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
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return const RegisterDialog();
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.blueAccent[400],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "JOIN HERE!!",
                        style: TextStyle(color:Colors.white ,fontSize: 16),

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

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({super.key});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();

  String size = "Small";
  String selectedGender = "Male";
  int step = 0;
  String paymentMethod = "GCash";
  bool acceptedWaiver = false;

  @override
  Widget build(BuildContext context) {

    return AlertDialog(
      title: const Text("Event Registration"),

      content: SingleChildScrollView(
        child: Column(
          children: [

            // step 1 - info ni runner
            if (step == 0) ...[

              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Full Name",
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                decoration: const InputDecoration(
                  labelText: "Age",
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: const InputDecoration(
                  labelText: "Gender",
                ),
                items: const [
                  DropdownMenuItem(value: "Male", child: Text("Male")),
                  DropdownMenuItem(value: "Female", child: Text("Female")),
                  DropdownMenuItem(value: "Other", child: Text("Other")),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedGender = value!;
                  });
                },
              ),

              const SizedBox(height: 10),

              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: "Email",
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: contactController,
                decoration: const InputDecoration(
                  labelText: "Contact Number",
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField(
                value: size,
                decoration: const InputDecoration(
                  labelText: "Shirt Sizes",
                ),
                items: const [
                  DropdownMenuItem(value: "Small", child: Text("Small")),
                  DropdownMenuItem(value: "Medium", child: Text("Medium")),
                  DropdownMenuItem(value: "Large", child: Text("Large")),
                ],
                onChanged: (value) {
                  setState(() {
                    size = value!;
                  });
                },
              ),

            ],

            // step 2 - payment method
            if (step == 1) ...[

              const Text(
                "Select Payment Method",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: const InputDecoration(
                  labelText: "Payment Method",
                ),
                items: const [
                  DropdownMenuItem(value: "GCash", child: Text("GCash")),
                  DropdownMenuItem(value: "PayMaya", child: Text("PayMaya")),
                  DropdownMenuItem(value: "Bank Transfer", child: Text("Bank Transfer")),
                ],
                onChanged: (value) {
                  setState(() {
                    paymentMethod = value!;
                  });
                },
              ),

            ],

            // step 3 - agreemnt
            if (step == 2) ...[

              const Text(
                "Waiver Agreement",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              const Text(
                "By joining this event, I confirm that I am physically fit and "
                    "understand the risks involved in participating in running events. "
                    "I release the event organizers from any liability.",
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              CheckboxListTile(
                value: acceptedWaiver,
                title: const Text("I agree to the waiver"),
                onChanged: (value) {
                  setState(() {
                    acceptedWaiver = value!;
                  });
                },
              ),

            ],

          ],
        ),
      ),

      actions: [

        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text("Cancel"),
        ),

        ElevatedButton(
          onPressed: () {

            if (step < 2) {
              setState(() {
                step++;
              });
            } else {

              if (!acceptedWaiver) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Please accept the waiver first."),
                  ),
                );
                return;
              }

              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Registration Complete!"),
                ),
              );
            }

          },
          child: Text(step < 2 ? "Next" : "Submit"),
        ),
      ],
    );
  }
}