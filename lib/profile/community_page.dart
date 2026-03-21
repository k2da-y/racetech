import 'package:flutter/material.dart';

class CommunityPage extends StatelessWidget {
  const CommunityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            /// TOP BAR
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("Back"),
                  ),

                  const Text(
                    "Training Module",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 70)

                ],
              ),
            ),

            const SizedBox(height: 40),

            const Center(
              child: Text(
                "this is me training u :>",
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            )

          ],
        ),
      ),
    );
  }
}