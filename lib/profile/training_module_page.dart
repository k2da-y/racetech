import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/training_data.dart';

class TrainingModulePage extends StatefulWidget {
  const TrainingModulePage({super.key});

  @override
  State<TrainingModulePage> createState() => _TrainingModulePageState();
}

class _TrainingModulePageState extends State<TrainingModulePage> {

  String selectedActivity = "";

  // ✅ LOAD USER ACTIVITY (FIRST ONE LANG)
  void loadActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList("activities") ?? [];

    setState(() {
      selectedActivity = activities.isNotEmpty ? activities.first : "Running";
    });
  }

  @override
  void initState() {
    super.initState();
    loadActivity();
  }

  // ✅ QUEST CARD (UNCHANGED)
  Widget questCard(
      String title,
      String description,
      String difficulty,
      double progress,
      ) {
    Color color;

    switch (difficulty) {
      case "Easy":
        color = Colors.green;
        break;
      case "Medium":
        color = Colors.orange;
        break;
      case "Hard":
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black.withOpacity(0.1),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Container(
                width: 10,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(description),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),

          const SizedBox(height: 5),

          Text(
            "${(progress * 100).toInt()}% completed",
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final quests = TrainingData.getQuests(selectedActivity);

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: Text("Training: $selectedActivity"),
      ),

      body: ListView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: quests.length,
        itemBuilder: (context, index) {

          final q = quests[index];

          return questCard(
            q["title"],
            q["desc"],
            q["diff"],
            0.3, // dummy progress
          );
        },
      ),
    );
  }
}