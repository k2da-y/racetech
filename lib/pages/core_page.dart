import 'package:flutter/material.dart';

class CorePage extends StatelessWidget {
  const CorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [

          Container(
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
                  onPressed: () {},
                  child: const Text(
                    "Home",
                    style: TextStyle(color: Colors.white),
                  ),
                ),

                TextButton(
                  onPressed: () {},
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
          ),

          const Expanded(
            child: Center(
              child: Text(
                "Welcome to RaceTech",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}