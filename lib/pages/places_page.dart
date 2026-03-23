import 'package:flutter/material.dart';
import 'user_profile_page.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  List<Map<String, String>> posts = [
    {
      "name": "Juan Dela Cruz",
      "content": "Excited for this event! 🔥",
    },
    {
      "name": "Maria Santos",
      "content": "Sino sasama? Tara ride tayo 🚴",
    },
    {
      "name": "Alex Reyes",
      "content": "First time ko dito, let's go!",
    },
  ];

  int currentIndex = 0;

  final List<String> images = [
    "assets/map.jpg",
  ];

  void nextImage() {
    setState(() {
      currentIndex = (currentIndex + 1) % images.length;
    });
  }

  void previousImage() {
    setState(() {
      currentIndex = (currentIndex - 1 + images.length) % images.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
          children: [

            // 🔥 MODERN APP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  const Text(
                    "RaceTech",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UserProfilePage(),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      backgroundColor: Colors.black,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),

            // TITLE
            const Text(
              "Events",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 IMAGE CARD
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                children: [

                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: DecorationImage(
                        image: AssetImage(images[currentIndex]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  // arrows
                  Positioned(
                    left: 10,
                    top: 90,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: previousImage,
                      ),
                    ),
                  ),

                  Positioned(
                    right: 10,
                    top: 90,
                    child: CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_forward, color: Colors.white),
                        onPressed: nextImage,
                      ),
                    ),
                  ),

                ],
              ),
            ),

            const SizedBox(height: 20),

            // EVENT TITLE
            const Text(
              "CAVITE LOOP",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            // 🔥 EVENT CARD
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 10,
                    color: Colors.black.withOpacity(0.1),
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                children: [

                  const Text(
                    "📅 March 29, 2026\n⏰ 6:00 AM",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Join the Cavite Loop ride. Experience scenic routes and a fun community ride!",
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const RegisterDialog(),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "Join Event",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  )
                ],
              ),
            ),

            const SizedBox(height: 25),

            // 🔥 COMMUNITY POSTS TITLE
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Community Posts",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // 🔥 POSTS LIST
            SizedBox(
              height: 250, // scrollable height
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                itemCount: posts.length,
                itemBuilder: (context, index) {

                  final post = posts[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 8,
                            color: Colors.black.withOpacity(0.1),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            children: [
                              const CircleAvatar(
                                child: Icon(Icons.person),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                post["name"]!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Text(post["content"]!),

                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          ],
        ),
        )
      ),
    );
  }
}

class RegisterDialog extends StatefulWidget {
  const RegisterDialog({super.key});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {

  int step = 0;
  String size = "Small";
  String paymentMethod = "GCash";
  bool acceptedWaiver = false;

  final nameController = TextEditingController();

  @override
  Widget build(BuildContext context) {

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            // TITLE + STEP
            Text(
              "Register (${step + 1}/3)",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (step == 0) ...[

              // FULL NAME
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Full Name",
                  prefixIcon: const Icon(Icons.person),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 🔥 SHIRT SIZE DROPDOWN
              DropdownButtonFormField<String>(
                value: size,
                decoration: InputDecoration(
                  hintText: "Shirt Size",
                  prefixIcon: const Icon(Icons.checkroom),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "X-Small", child: Text("X-Small")),
                  DropdownMenuItem(value: "Small", child: Text("Small")),
                  DropdownMenuItem(value: "Medium", child: Text("Medium")),
                  DropdownMenuItem(value: "Large", child: Text("Large")),
                  DropdownMenuItem(value: "X-Large", child: Text("X-Large")),
                ],
                onChanged: (value) {
                  setState(() {
                    size = value!;
                  });
                },
              ),

              const Text(
                "pili ka ng size mo teh",
                textAlign: TextAlign.left,
              ),

            ],

            if (step == 1) ...[
              DropdownButtonFormField<String>(
                value: paymentMethod,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.payment),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: "GCash", child: Text("GCash")),
                  DropdownMenuItem(value: "PayMaya", child: Text("PayMaya")),
                  DropdownMenuItem(value: "Bank Transfer", child: Text("Bank Transfer")),
                ],
                onChanged: (value) {
                  setState(() {
                    paymentMethod = value!;
                  });
                },
              ),
            ],

            if (step == 2) ...[
              const Text(
                "I hereby declare that I am physically and medically fit to participate in this event. "
                    "I fully understand and acknowledge the risks involved, including possible injury or accident. "
                    "I voluntarily agree to assume all such risks and release the organizers, sponsors, and affiliated parties from any and all liability arising from my participation.",
                textAlign: TextAlign.center,
              ),
              CheckboxListTile(
                value: acceptedWaiver,
                title: const Text("I agree to the waiver"),
                onChanged: (value) {
                  setState(() {
                    acceptedWaiver = value!;
                  });
                },
              ),
            ],

            const SizedBox(height: 20),

            Row(
              children: [

                if (step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          step--;
                        });
                      },
                      child: const Text("Back"),
                    ),
                  ),

                if (step > 0) const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {

                      if (step < 2) {
                        setState(() {
                          step++;
                        });
                      } else {
                        if (!acceptedWaiver) return;

                        Navigator.pop(context);

                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            title: const Text("Success 🎉"),
                            content: const Text("You have successfully registered for the event!"),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // close dialog
                                },
                                child: const Text("OK"),
                              ),
                            ],
                          ),
                        );
                      }
                    },
                    child: Text(step < 2 ? "Next" : "Submit"),
                  ),
                ),

              ],
            )
          ],
        ),
      ),
    );
  }
}