import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class FollowUsPage extends StatelessWidget {
  const FollowUsPage({super.key});

  Widget socialCard(
      IconData icon,
      String title,
      String subtitle,
      ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 50),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(subtitle),
        ],
      ),
    );
  }

  Widget cardContainer(Widget left, Widget right) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          left,
          Container(
            height: 70,
            width: 1,
            color: Colors.black26,
          ),
          right,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const SizedBox(height: 40),

          cardContainer(
            socialCard(Icons.facebook, "Facebook", "RaceTech Ph"),
            socialCard(Icons.camera_alt, "Instagram", "racetech.ph"),
          ),

          cardContainer(
            socialCard(Icons.music_note, "TikTok", "race.tech.ph"),
            socialCard(Icons.mail, "Gmail", "racetechph@gmail.com"),
          ),

          const Spacer(),

          const Footer()
        ],
      ),
    );
  }
}