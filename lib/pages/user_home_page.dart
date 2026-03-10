import 'package:flutter/material.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {

  int currentIndex = 0;

  final List<String> images = [
    "assets/run1.jpg",
    "assets/run2.jpg",
    "assets/run3.jpg",
  ];

  void nextImage() {
    setState(() {
      currentIndex = (currentIndex + 1) % images.length;
    });
  }

  void previousImage() {
    setState(() {
      currentIndex =
          (currentIndex - 1 + images.length) % images.length;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [

            /// BLUE TOP BAR
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
                children: const [

                  Icon(Icons.menu, color: Colors.white),

                  Text(
                    "RaceTech",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Icon(Icons.person_outline,
                      color: Colors.white),
                ],
              ),
            ),

            /// CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [

                    const Text(
                      "WELCOME,",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Every event you join is a chance to grow, meet people who inspire you, and discover something new about yourself. One step outside your comfort zone today can open doors you never expected tomorrow.",
                      style: TextStyle(fontSize: 16),
                    ),

                    const SizedBox(height: 25),

                    /// BOOK EVENT BUTTON
                    Center(
                      child: ElevatedButton(
                        onPressed: () {},
                        child: const Text("Book an Event"),
                      ),
                    ),

                    const SizedBox(height: 25),

                    /// IMAGE SLIDER
                    Row(
                      children: [

                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: previousImage,
                        ),

                        Expanded(
                          child: Container(
                            height: 220,
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(10),
                              image: DecorationImage(
                                image: AssetImage(
                                    images[currentIndex]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),

                        IconButton(
                          icon:
                          const Icon(Icons.arrow_forward),
                          onPressed: nextImage,
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    const Center(
                      child: Text(
                        "When you move for fun,\nyou heal without even noticing.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontSize: 16,
                        ),
                      ),
                    )

                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}