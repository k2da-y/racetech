import 'package:flutter/material.dart';


class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  Widget menuItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(fontSize: 16),
          ),
          const Divider()
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            /// TOP BAR
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [

                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.grey,
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("LOG OUT"),
                  )
                ],
              ),
            ),

            const Divider(),

            /// TITLE
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
              color: Colors.grey[300],
              child: const Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "My Profile",
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  Icon(Icons.arrow_forward)
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// USER INFO CARD
            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Row(
                children: [

                  const CircleAvatar(
                    radius: 30,
                    child: Icon(Icons.person, size: 35),
                  ),

                  const SizedBox(width: 20),

                  Column(
                    crossAxisAlignment:
                    CrossAxisAlignment.start,
                    children: const [
                      Text(
                        "Keith Garcia",
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "keithgarcia@gmail.com",
                        style: TextStyle(color: Colors.grey),
                      )
                    ],
                  )
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// SETTINGS CARD
            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [

                  menuItem("EDIT NAME"),
                  menuItem("CHANGE PASSWORD"),
                  menuItem("BADGES"),

                ],
              ),
            ),

            const SizedBox(height: 20),

            /// MORE SETTINGS
            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black26),
              ),
              child: Column(
                children: [

                  menuItem("TRAINING MODULE"),
                  menuItem("PRIVACY POLICY"),
                  menuItem("HELP AND SUPPORT"),

                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}