import 'package:flutter/material.dart';
import '../widgets/header.dart';
import '../widgets/footer.dart';

class MerchPage extends StatelessWidget {
  const MerchPage({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: Column(
        children: [

          const Header(),

          const SizedBox(height: 40),

          Image.asset(
            "assets/merch.png",
            height: 250,
          ),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "RaceTech offers premium race merchandise including finisher shirts, medals, and race kits designed for runners and event organizers.",
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