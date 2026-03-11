import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class EventsPage extends StatelessWidget {
  const EventsPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const SizedBox(height: 40),

          const Text(
            "RaceTech Events",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "RaceTech organizes and supports various running events including 5K fun runs, 10K marathons, and competitive racing events across different locations.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
          ),

          const Spacer(),
          const Footer()
        ],
      ),
    );
  }
}