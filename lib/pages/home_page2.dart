import 'package:flutter/material.dart';
import 'package:racetechph/pages/home_page.dart';
import 'package:racetechph/pages/login_page.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class NextHomePage extends StatelessWidget {
  const NextHomePage({super.key});

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
                  "Jesus is King",
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
                  builder: (context) => HomePage(),
                ),
              );
            },
            child: const Text("Back"),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LoginPage(),
                ),
              );
            },
            child: const Text("Login"),
          ),

          const Spacer(),
          const Footer()
        ],
      ),
    );
  }
}