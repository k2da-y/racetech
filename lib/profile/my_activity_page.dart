import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MyActivityPage extends StatefulWidget {
  const MyActivityPage({super.key});

  @override
  State<MyActivityPage> createState() => _MyActivityPageState();
}

class _MyActivityPageState extends State<MyActivityPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> registrations = [];
  List<Map<String, dynamic>> results = [];

  @override
  void initState() {
    super.initState();
    loadActivity();
  }

  Future<void> loadActivity() async {
    final loadedRegistrations = await ApiService().getMyRegistrations();
    final loadedResults = await ApiService().getMyResults();

    if (!mounted) return;

    setState(() {
      registrations = loadedRegistrations;
      results = loadedResults;
      isLoading = false;
    });
  }

  Map<String, dynamic> nestedMap(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return {};
  }

  String formatDate(String value) {
    if (value.isEmpty) return "TBA";

    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;

    return "${parsed.month}/${parsed.day}/${parsed.year}";
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: const Text("My Activity"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Registrations"),
              Tab(text: "Results"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _RegistrationList(
                    registrations: registrations,
                    nestedMap: nestedMap,
                    formatDate: formatDate,
                  ),
                  _ResultList(results: results, nestedMap: nestedMap),
                ],
              ),
      ),
    );
  }
}

class _RegistrationList extends StatelessWidget {
  final List<Map<String, dynamic>> registrations;
  final Map<String, dynamic> Function(Map<String, dynamic>, String) nestedMap;
  final String Function(String) formatDate;

  const _RegistrationList({
    required this.registrations,
    required this.nestedMap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    if (registrations.isEmpty) {
      return const Center(child: Text("No registrations yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: registrations.length,
      itemBuilder: (context, index) {
        final registration = registrations[index];
        final event = nestedMap(registration, "event");
        final category = nestedMap(registration, "category");

        return _ActivityCard(
          title: (event["title"] ?? "Event").toString(),
          subtitle: [
            if ((category["name"] ?? "").toString().isNotEmpty)
              category["name"].toString(),
            if ((event["event_date"] ?? "").toString().isNotEmpty)
              formatDate(event["event_date"].toString()),
          ].join(" - "),
          chips: [
            "Status: ${(registration["status"] ?? "pending").toString()}",
            if ((registration["bib_number"] ?? "").toString().isNotEmpty)
              "BIB: ${registration["bib_number"]}",
          ],
        );
      },
    );
  }
}

class _ResultList extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final Map<String, dynamic> Function(Map<String, dynamic>, String) nestedMap;

  const _ResultList({required this.results, required this.nestedMap});

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text("No results yet"));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final result = results[index];
        final event = nestedMap(result, "event");
        final category = nestedMap(result, "category");

        return _ActivityCard(
          title: (event["title"] ?? "Event").toString(),
          subtitle: [
            if ((category["name"] ?? "").toString().isNotEmpty)
              category["name"].toString(),
            if ((result["finish_time"] ?? "").toString().isNotEmpty)
              "Finish: ${result["finish_time"]}",
          ].join(" - "),
          chips: [
            if ((result["rank_overall"] ?? "").toString().isNotEmpty)
              "Overall: ${result["rank_overall"]}",
            if ((result["rank_category"] ?? "").toString().isNotEmpty)
              "Category: ${result["rank_category"]}",
            if ((result["remarks"] ?? "").toString().isNotEmpty)
              result["remarks"].toString(),
          ],
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> chips;

  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.chips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: const TextStyle(color: Colors.grey)),
          ],
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips
                  .map(
                    (chip) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        chip,
                        style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
