import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class FAQPage extends StatelessWidget {
  const FAQPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const SizedBox(height: 40),

          const Text(
            "Frequently Asked Questions",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  "Q: What services does RaceTech provide?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    "A: RaceTech provides race timing, event registration, race promotion, and merchandise production."),

                SizedBox(height: 20),

                Text(
                  "Q: How can I register for an event?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    "A: You can register through our event registration system available in the RaceTech platform."),

                SizedBox(height: 20),

                Text(
                  "Q: Do you offer race equipment?",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                    "A: Yes, we offer race clock sales, rentals, and timing equipment."),
              ],
            ),
          ),

          const Spacer(),
          const Footer()
        ],
      ),
    );
  }
}