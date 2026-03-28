import 'package:flutter/material.dart';

class TrainingModulePage extends StatelessWidget {
  const TrainingModulePage({super.key});

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

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Training Module"),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Daily Quests",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            questCard("Morning Ride", "Complete a 5km ride today", "Easy", 0.6),
            questCard("Hydration Check", "Drink 2L water", "Easy", 0.3),
            questCard("Stretch Routine", "10 mins stretching", "Easy", 1.0),

            const SizedBox(height: 20),

            const Text(
              "Weekly Quests",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            questCard("Weekend Ride", "20km ride", "Medium", 0.5),
            questCard("Consistency Rider", "Ride 3x", "Medium", 0.7),
            questCard("Climb Challenge", "Uphill ride", "Medium", 0.2),
            questCard("Night Ride", "Ride at night", "Medium", 0.4),
            questCard("Explore Route", "New route", "Medium", 0.6),
            questCard("Group Ride", "Join event", "Medium", 0.3),
            questCard("Speed Boost", "Maintain 20km/h", "Medium", 0.5),
            questCard("Recovery Day", "Light ride", "Medium", 1.0),
            questCard("Safety Check", "Bike inspection", "Medium", 0.8),
            questCard("Photo Post", "Post ride", "Medium", 0.2),

            const SizedBox(height: 20),

            const Text(
              "Monthly Challenges (Hard)",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            questCard("Century Ride", "100km ride", "Hard", 0.3),
            questCard("Elevation Master", "1000m gain", "Hard", 0.4),
            questCard("Consistency Pro", "15 ride days", "Hard", 0.6),
            questCard("Event Finisher", "Finish event", "Hard", 0.1),
            questCard("Endurance Test", "50km nonstop", "Hard", 0.5),
          ],
        ),
      ),
    );
  }
}