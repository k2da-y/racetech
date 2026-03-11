import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';
import 'home_page2.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              children: [

                Image.asset(
                  "assets/logo.cvsu.jpg",
                  height: 200,
                ),

                const SizedBox(height: 20),

                const Text(
                  "RaceTech offers comprehensive race timing solutions, including race result scoring, event promotion and registration, race clock sales and rentals, and production of finisher tshirts and medals.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NextHomePage(),
                ),
              );
            },
            child: const Text("Next"),
          ),

          const Spacer(),
          const Footer()
        ],
      ),
    );
  }
}