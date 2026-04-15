import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'places_page.dart';

class ProfilingPage extends StatefulWidget {
  const ProfilingPage({super.key});

  @override
  State<ProfilingPage> createState() => _ProfilingPageState();
}

class _ProfilingPageState extends State<ProfilingPage> {

  //LIST OF AVAILABLE ACTIVITIES (MATCH THIS WITH EVENT TAGS)
  final List<String> activitiesList = [
    "Running",
    "Cycling",
    "Duathlon",
    "Marathon",
    "Trail Run",
  ];

  //SELECTED ACTIVITIES
  List<String> selectedActivities = [];

  //SUBMIT PROFILE
  void finishProfiling() async {

    if (selectedActivities.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Incomplete"),
          content: Text("Please select at least one activity."),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // SAVE DATA
    await prefs.setBool("isProfiled", true);
    await prefs.setStringList("activities", selectedActivities);

    // GO TO PLACES PAGE
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacesPage(),
      ),
    );
  }

  //CHIP UI
  Widget buildChoice(String activity) {
    final isSelected = selectedActivities.contains(activity);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedActivities.remove(activity);
          } else {
            selectedActivities.add(activity);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            if (isSelected)
              const Icon(Icons.check, color: Colors.white, size: 16),

            if (isSelected) const SizedBox(width: 5),

            Text(
              activity,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
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
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const Text(
                    "Welcome to RaceTech",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Choose your interests to personalize events",
                    style: TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 30),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Your Interests",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  //DYNAMIC LIST (EASIER TO SCALE)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: activitiesList
                        .map((activity) => buildChoice(activity))
                        .toList(),
                  ),

                  const SizedBox(height: 40),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: finishProfiling,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Get Started",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),

                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}