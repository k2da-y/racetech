import 'package:flutter/material.dart';

class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  //SAMPLE BADGES DATA
  final List<Map<String, dynamic>> badges = const [
    {
      "title": "First Event",
      "desc": "Join your first event",
      "icon": Icons.directions_bike,
      "unlocked": true,
    },
    {
      "title": "Explorer",
      "desc": "Join 3 different events",
      "icon": Icons.explore,
      "unlocked": false,
    },
    {
      "title": "Consistent Athlete",
      "desc": "Join events 5 times",
      "icon": Icons.repeat,
      "unlocked": false,
    },
    {
      "title": "Early Bird",
      "desc": "Join a 5AM event",
      "icon": Icons.wb_sunny,
      "unlocked": true,
    },
    {
      "title": "Social Athlete",
      "desc": "Post 5 times in community",
      "icon": Icons.people,
      "unlocked": false,
    },
    {
      "title": "Champion",
      "desc": "Complete a major event",
      "icon": Icons.emoji_events,
      "unlocked": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Achievements"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(15),

        //GRID OF BADGES
        child: GridView.builder(
          itemCount: badges.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 per row
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 0.9,
          ),

          itemBuilder: (context, index) {
            final badge = badges[index];

            return Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: badge["unlocked"]
                    ? Colors.white
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 8,
                    color: Colors.black.withOpacity(0.1),
                  )
                ],
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  //ICON
                  Icon(
                    badge["icon"],
                    size: 50,
                    color: badge["unlocked"]
                        ? Colors.orange
                        : Colors.grey,
                  ),

                  const SizedBox(height: 10),

                  //TITLE
                  Text(
                    badge["title"],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: badge["unlocked"]
                          ? Colors.black
                          : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 5),

                  //DESCRIPTION
                  Text(
                    badge["desc"],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: badge["unlocked"]
                          ? Colors.black54
                          : Colors.grey,
                    ),
                  ),

                  const SizedBox(height: 10),

                  //STATUS
                  Text(
                    badge["unlocked"] ? "Unlocked" : "Locked",
                    style: TextStyle(
                      fontSize: 12,
                      color: badge["unlocked"]
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}