import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'places_page.dart';
import '../data/activity_data.dart';
import '../services/api_service.dart';

class ProfilingPage extends StatefulWidget {
  const ProfilingPage({super.key});

  @override
  State<ProfilingPage> createState() => _ProfilingPageState();
}

class _ProfilingPageState extends State<ProfilingPage> {
  List<String> activitiesList = ActivityData.activities;
  List<String> selectedActivities = [];
  bool isSaving = false;
  bool isLoadingActivities = true;

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  Future<void> loadActivities() async {
    final interests = await ApiService().getInterestTypes();

    if (!mounted) return;

    setState(() {
      activitiesList = interests.isEmpty ? ActivityData.activities : interests;
      selectedActivities = selectedActivities
          .where((activity) => activitiesList.contains(activity))
          .toList();
      isLoadingActivities = false;
    });
  }

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

    setState(() => isSaving = true);

    final result = await ApiService().updateInterests(selectedActivities);

    if (!mounted) return;

    if (!result.success) {
      setState(() => isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // SAVE DATA
    await prefs.setBool("isProfiled", true);
    await prefs.setStringList("activities", selectedActivities);

    if (!mounted) return;

    // GO TO PLACES PAGE
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const PlacesPage()),
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
          border: Border.all(color: isSelected ? Colors.red : Colors.grey),
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                  if (isLoadingActivities)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: CircularProgressIndicator(),
                    )
                  else
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
                      onPressed: isSaving || isLoadingActivities
                          ? null
                          : finishProfiling,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isSaving ? "Saving..." : "Get Started",
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
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
