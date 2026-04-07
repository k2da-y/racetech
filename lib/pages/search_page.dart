import 'package:flutter/material.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {

  final TextEditingController searchController = TextEditingController();

  //SAMPLE EVENTS
  final List<Map<String, String>> events = [
    {"title": "Cavite Loop", "date": "March 29"},
    {"title": "Tagaytay Ride", "date": "April 5"},
    {"title": "Manila Marathon", "date": "May 10"},
    {"title": "Trail Run Baguio", "date": "June 2"},
    {"title": "Duathlon Challenge", "date": "July 18"},
  ];

  List<Map<String, String>> filteredEvents = [];

  @override
  void initState() {
    super.initState();
    filteredEvents = events;
  }

  //SEARCH FUNCTION
  void searchEvent(String query) {
    final results = events.where((event) {
      return event["title"]!
          .toLowerCase()
          .contains(query.toLowerCase());
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

                        //IMAGE PLACEHOLDER
                        Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.image),
                        ),

                        const SizedBox(width: 10),

                        //INFO
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event["title"]!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(event["date"]!),
                          ],
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