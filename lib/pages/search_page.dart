import 'package:flutter/material.dart';
import '../data/event_data.dart';
import '../data/activity_data.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {

  final TextEditingController searchController = TextEditingController();

  List<String> activities = ActivityData.activities;

  //GET EVENTS FROM event_data.dart
  final List<Map<String, dynamic>> allEvents = EventData.events;

  List<Map<String, dynamic>> filteredEvents = [];

  @override
  void initState() {
    super.initState();
    filteredEvents = allEvents;
  }

  //IMPROVED SEARCH FUNCTION (TITLE + TYPE + TAGS)
  void searchEvent(String query) {

    if (query.isEmpty) {
      setState(() {
        filteredEvents = allEvents;
      });
      return;
    }

    final search = query.toLowerCase();

    final results = allEvents.where((event) {

      final title = event["title"].toLowerCase();
      final type = event["event"].toLowerCase();
      final tags = (event["tags"] as List).join(" ").toLowerCase();

      return title.contains(search) ||
          type.contains(search) ||
          tags.contains(search);

    }).toList();

    setState(() {
      filteredEvents = results;
    });
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Find Events"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(15),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            //SEARCH BAR
            TextField(
              controller: searchController,
              onChanged: searchEvent,
              decoration: InputDecoration(
                hintText: "Search events...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 15),

            //ACTIVITY CHIPS
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: activities.map((activity) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        searchController.text = activity;
                        searchEvent(activity);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          activity,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            //TITLE
            Text(
              searchController.text.isEmpty
                  ? "Suggested Events"
                  : "Search Results",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            //LIST
            Expanded(
              child: filteredEvents.isEmpty
                  ? const Center(child: Text("No events found"))
                  : ListView.builder(
                itemCount: filteredEvents.length,
                itemBuilder: (context, index) {

                  final event = filteredEvents[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 5,
                          color: Colors.black.withOpacity(0.1),
                        )
                      ],
                    ),

                    child: Row(
                      children: [

                        //IMAGE
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: AssetImage(event["image"]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        //INFO
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                                event["title"],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                "${event["event"]} • ${event["date"]}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                ),
                              ),

                            ],
                          ),
                        ),

                      ],
                    ),
                  );
                },
              ),
            ),

          ],
        ),
      ),
    );
  }
}