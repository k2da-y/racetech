import 'package:flutter/material.dart';
import '../data/activity_data.dart';
import '../services/api_service.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController searchController = TextEditingController();

  List<String> activities = ActivityData.activities;
  List<Map<String, dynamic>> allEvents = [];
  List<Map<String, dynamic>> filteredEvents = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadEvents() async {
    final apiService = ApiService();
    final eventsFuture = apiService.getEvents();
    final interestsFuture = apiService.getInterestTypes();
    final events = await eventsFuture;
    final interests = await interestsFuture;

    if (!mounted) return;

    setState(() {
      activities = interests.isEmpty ? ActivityData.activities : interests;
      allEvents = events.map(normalizeEvent).toList();
      filteredEvents = allEvents;
      isLoading = false;
    });
  }

  Map<String, dynamic> normalizeEvent(Map<String, dynamic> event) {
    final categories = ((event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
    final interest = (event["interest_type"] ?? "").toString();

    return {
      "title": event["title"] ?? "Untitled Event",
      "event": interest.isEmpty ? "Race Event" : interest,
      "date": event["event_date"] ?? "TBA",
      "venue": event["venue"] ?? "",
      "banner_url": event["banner_url"],
      "tags": [
        if (interest.isNotEmpty) interest,
        ...categories.map((category) => (category["name"] ?? "").toString()),
      ],
    };
  }

  void searchEvent(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredEvents = allEvents;
      });
      return;
    }

    final search = query.toLowerCase();
    final results = allEvents.where((event) {
      final title = event["title"].toString().toLowerCase();
      final type = event["event"].toString().toLowerCase();
      final venue = event["venue"].toString().toLowerCase();
      final tags = ((event["tags"] as List?) ?? []).join(" ").toLowerCase();

      return title.contains(search) ||
          type.contains(search) ||
          venue.contains(search) ||
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
      appBar: AppBar(title: const Text("Find Events")),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
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
            Text(
              searchController.text.isEmpty
                  ? "Suggested Events"
                  : "Search Results",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredEvents.isEmpty
                  ? const Center(child: Text("No events found"))
                  : ListView.builder(
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];
                        final bannerUrl = (event["banner_url"] ?? "")
                            .toString();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 5,
                                color: Colors.black.withValues(alpha: 0.1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 50,
                                width: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  image: DecorationImage(
                                    image: bannerUrl.isEmpty
                                        ? const AssetImage("assets/map.jpg")
                                        : NetworkImage(bannerUrl),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      event["title"].toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      "${event["event"]} - ${event["date"]}",
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
