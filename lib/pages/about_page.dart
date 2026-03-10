import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import 'merch_page.dart';
import 'faq_page.dart';
import 'event_page.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  Widget menuButton(BuildContext context, String title, Widget page) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(200, 50),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => page,
            ),
          );
        },
        child: Text(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const Spacer(),

          const Text(
            "Learn about RaceTech",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 30),

          menuButton(context, "Merch", const MerchPage()),
          menuButton(context, "FAQ", const FAQPage()),
          menuButton(context, "Events", const EventsPage()),

          const Spacer(),

          const Footer()

        ],
      ),
    );
  }
}