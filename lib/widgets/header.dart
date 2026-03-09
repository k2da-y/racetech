import 'package:flutter/material.dart';
import '../pages/home_page.dart';
import '../pages/follow_us_page.dart';

class Header extends StatelessWidget {
  const Header({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blue,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Row(
        children: [

          const Text(
            "RaceTech",
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),

          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HomePage(),
                ),
              );
            },
            child: const Text(
              "Home",
              style: TextStyle(color: Colors.white),
            ),
          ),

          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FollowUsPage(),
                ),
              );
            },
            child: const Text(
              "Follow Us",
              style: TextStyle(color: Colors.white),
            ),
          ),

          TextButton(
            onPressed: () {},
            child: const Text(
              "About",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}