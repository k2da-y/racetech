import 'package:flutter/material.dart';
import '../profile/community_page.dart';
import '../profile/badges_page.dart';
import 'user_profile_page.dart';
import '../profile/training_module_page.dart';
import '../profile/create_post.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {

  //COMMUNITY POSTS DATA
  List<Map<String, String>> posts = [
    {"name": "Jan Jowell Diestro", "content": "Dubai chewy cookie? ano tara?"},
    {"name": "Trixie Ann Apan", "content": "Tara tambay sa pula"},
    {"name": "Keith Garcia", "content": "Ilocos Empanada? ano tara?"},
  ];

  //TRACK CURRENT CAROUSEL INDEX
  int currentIndex = 0;

  //EVENTS DATA (USED IN CAROUSEL)
  final List<Map<String, dynamic>> events = [
    {
      "event": "Marathon",
      "title": "Cavite Loop",
      "image": "assets/map.jpg",
      "participants": "10/100",
      "date": "March 29, 2026",
      "time": "6:00 AM",
    },
    {
      "event": "Bike Race",
      "title": "Tagaytay Ride",
      "image": "assets/map.jpg",
      "participants": "25/100",
      "date": "April 5, 2026",
      "time": "5:30 AM",
    },
    {
      "event": "Duathlon",
      "title": "Bako Loop",
      "image": "assets/map.jpg",
      "participants": "67/100",
      "date": "April 27, 2026",
      "time": "3:00 AM",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [

              //HEADER (APP TITLE + PROFILE)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [

                    const Text(
                      "RaceTech",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),

                    //PROFILE BUTTON
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

              //EVENTS TITLE
              const Text(
                "Events",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 20),

              //EVENT CAROUSEL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [

                    SizedBox(
                      height: 250,
                      child: PageView.builder(
                        itemCount: events.length,
                        controller: PageController(viewportFraction: 0.9),

                        //UPDATE CURRENT INDEX (for dots)
                        onPageChanged: (index) {
                          setState(() {
                            currentIndex = index;
                          });
                        },

                        itemBuilder: (context, index) {
                          final event = events[index];

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 8),

                            //CARD DESIGN
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              image: DecorationImage(
                                image: AssetImage(event["image"]),
                                fit: BoxFit.cover,
                              ),
                            ),

                            //DARK OVERLAY
                            child: Container(
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black.withOpacity(0.4),
                              ),

                              //EVENT DETAILS INSIDE CARD
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [

                                  //EVENT TYPE
                                  Text(
                                    event["event"],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  //TITLE
                                  Text(
                                    event["title"],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 8),

                                  //PARTICIPANTS
                                  Text(
                                    "Participants: ${event["participants"]}",
                                    style: const TextStyle(color: Colors.white),
                                  ),

                                  //DATE + TIME
                                  Text(
                                    "${event["date"]} • ${event["time"]}",
                                    style: const TextStyle(color: Colors.white),
                                  ),

                                  const SizedBox(height: 10),

                                  //JOIN BUTTON
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (_) => const RegisterDialog(),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade300,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                      child: const Text("Join Event",
                                          style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    //CAROUSEL DOT INDICATOR
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(events.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentIndex == index ? 12 : 8,
                          height: currentIndex == index ? 12 : 8,
                          decoration: BoxDecoration(
                            color: currentIndex == index ? Colors.redAccent : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 25),

              //COMMUNITY
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Community Posts",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              //POSTS LIST
              SizedBox(
                height: 250,
                child: ListView.builder(
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

                            //USER INFO SA NAVIGATION
                            Row(
                              children: [
                                const CircleAvatar(
                                  child: Icon(Icons.person),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  post["name"]!,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),

                            const SizedBox(height: 10),

                            //POST CONTENT SA NAVIGATION
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
        ),
      ),
      //CUSTOM BOTTOM NAVIGATION
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(15),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
              )
            ],
          ),

          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [

              //TRAINING SA NAVIGATION
              IconButton(
                icon: const Icon(Icons.menu_book_outlined, color: Colors.grey),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TrainingModulePage()),
                  );
                },
              ),

              //COMMUNITY SA NAVIGATION
              IconButton(
                icon: const Icon(Icons.groups_outlined, color: Colors.grey),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CommunityPage()),
                  );
                },
              ),

              //CREATE POST SA NAVIGATION
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CreatePostSheet(),
                  );
                },
                child: Container(
                  height: 55,
                  width: 55,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),

              //NOTIFICATIONS SA NAVIGATION
              IconButton(
                icon: const Icon(Icons.notifications_none, color: Colors.grey),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const AlertDialog(
                      title: Text("Notifications"),
                      content: Text("No notifications yet 🔔"),
                    ),
                  );
                },
              ),

              //BADGES SA NAVIGATION
              IconButton(
                icon: const Icon(Icons.emoji_events_outlined, color: Colors.grey),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BadgesPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
//REGISTRATION DIALOG SA JOIN EVENT BOTTON
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

            Text(
              "Register (${step + 1}/2)",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            if (step == 0) ...[

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "First Name:",
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

              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: "Last Name:",
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
                "This shirt sizes are for FREE!",
                textAlign: TextAlign.left,
              ),

            ],

            if (step == 1) ...[
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

                      if (step < 1) {
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
                    child: Text(step < 1 ? "Next" : "Submit"),
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