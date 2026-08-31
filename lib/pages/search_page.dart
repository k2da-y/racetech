import 'package:flutter/material.dart';
import '../data/activity_data.dart';
import '../services/api_service.dart';
import '../widgets/event_details_sheet.dart';
import '../utils/event_category_registration.dart';
import '../utils/event_normalizer.dart';
import 'places_page.dart' show RegisterDialog;
import 'profile_settings_page.dart';

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
  String selectedActivity = "";
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
    final interestsFuture = apiService.getEventInterestTypes();
    final events = await eventsFuture;
    final interests = await interestsFuture;
    final normalizedEvents = events.map(normalizeEvent).toList();
    final eventActivities = activityFiltersFromEvents(normalizedEvents);

    if (!mounted) return;

    setState(() {
      activities = eventActivities.isNotEmpty
          ? eventActivities
          : interests.isEmpty
          ? ActivityData.activities
          : interests;
      allEvents = normalizedEvents;
      filteredEvents = allEvents;
      isLoading = false;
    });
  }

  Map<String, dynamic> normalizeEvent(Map<String, dynamic> event) {
    return normalizeEventFromApi(event);
  }

  List<String> activityFiltersFromEvents(List<Map<String, dynamic>> events) {
    final filters = <String>{};

    for (final event in events) {
      final eventType = (event["event"] ?? "").toString().trim();
      if (eventType.isNotEmpty && eventType != "Race Event") {
        filters.add(eventType);
      }

      for (final tag in ((event["tags"] as List?) ?? [])) {
        final label = tag.toString().trim();
        if (label.isNotEmpty) {
          filters.add(label);
        }
      }
    }

    return filters.toList()..sort();
  }

  String normalizedSearchText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), " ").trim();
  }

  void searchEvent(String query) {
    if (query.isEmpty) {
      setState(() {
        filteredEvents = allEvents;
      });
      return;
    }

    final search = normalizedSearchText(query);
    final results = allEvents.where((event) {
      final title = normalizedSearchText(event["title"].toString());
      final type = normalizedSearchText(event["event"].toString());
      final venue = normalizedSearchText(event["venue"].toString());
      final tags = normalizedSearchText(
        ((event["tags"] as List?) ?? []).join(" "),
      );

      return title.contains(search) ||
          type.contains(search) ||
          venue.contains(search) ||
          tags.contains(search) ||
          search.contains(type);
    }).toList();

    setState(() {
      filteredEvents = results;
    });
  }

  void handleSearchChanged(String query) {
    selectedActivity = "";
    searchEvent(query);
  }

  void clearFilters() {
    searchController.clear();
    setState(() {
      selectedActivity = "";
      filteredEvents = allEvents;
    });
  }

  void filterByActivity(String activity) {
    searchController.text = activity;
    selectedActivity = activity;
    searchEvent(activity);
  }

  String get sectionTitle {
    if (selectedActivity.isNotEmpty) {
      return "$selectedActivity Events";
    }

    return searchController.text.isEmpty
        ? "Suggested Events"
        : "Search Results";
  }

  bool eventHasOpenCategory(Map<String, dynamic> event) {
    return ((event["categories"] as List?) ?? []).whereType<Map>().any(
      (category) =>
          (category["status"] ?? "").toString().toLowerCase() == "open",
    );
  }

  bool eventHasRegisterableCategory(Map<String, dynamic> event) {
    final categories = ((event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
    final hasPerCategoryMetadata = categories.any(
      categoryHasRegistrationMetadata,
    );
    if (hasPerCategoryMetadata) return categories.any(categoryCanRegister);
    return !eventBlocksJoin(event) && eventHasOpenCategory(event);
  }

  bool eventHasJoinedCategory(Map<String, dynamic> event) {
    return ((event["categories"] as List?) ?? [])
            .whereType<Map>()
            .map((category) => Map<String, dynamic>.from(category))
            .any(categoryIsJoined) ||
        eventBlocksJoin(event);
  }

  String eventStatusLabel(Map<String, dynamic> event) {
    final status = (event["status"] ?? "").toString().trim().toLowerCase();

    return switch (status) {
      "ongoing" => "Ongoing",
      "completed" => "Completed",
      _ => "Upcoming",
    };
  }

  bool canJoinEvent(Map<String, dynamic> event) {
    return event["status"] == "upcoming" && eventHasRegisterableCategory(event);
  }

  bool eventBlocksJoin(Map<String, dynamic> event) {
    return event["is_registered"] == true &&
        !eventRegistrationAllowsJoin(event);
  }

  bool eventRegistrationAllowsJoin(Map<String, dynamic> event) {
    final status = (event["registration_status"] ?? "")
        .toString()
        .trim()
        .toLowerCase();

    return status.isEmpty || status == "rejected";
  }

  String eventActionLabel(Map<String, dynamic> event) {
    if (event["status"] != "upcoming") {
      return "Unavailable";
    }

    if (!eventHasRegisterableCategory(event)) {
      return eventHasJoinedCategory(event) ? "Registered" : "Unavailable";
    }
    return eventHasJoinedCategory(event)
        ? "Join Another Category"
        : "Join Event";
  }

  String eventActionMessage(Map<String, dynamic> event) {
    if (event["status"] != "upcoming") {
      return "Registration is only available for upcoming events.";
    }

    if (!eventHasRegisterableCategory(event)) {
      return eventHasJoinedCategory(event)
          ? "You are registered for all compatible categories."
          : "There are no compatible categories available for registration.";
    }
    return eventHasJoinedCategory(event)
        ? "You may register for another compatible category."
        : "Choose an available category to complete your registration.";
  }

  Future<void> handleJoinEvent(Map<String, dynamic> event) async {
    final apiService = ApiService();
    final user = await apiService.getUser();

    if (!mounted) return;

    if (!apiService.profileIsComplete(user)) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.account_circle_outlined),
          title: const Text("Complete Your Profile"),
          content: const Text(
            "Please add your phone, address, birthdate, and emergency contact before joining an event.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Later"),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Open Settings"),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (shouldOpenSettings == true) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSettingsPage()),
        );
      }

      return;
    }

    final registered = await showDialog<bool>(
      context: context,
      builder: (_) => RegisterDialog(
        event: event,
        initialMedicalConditions: (user?["medical_conditions"] ?? "")
            .toString(),
      ),
    );

    if (!mounted || registered != true) return;

    await refreshEventAfterRegistration(event);
  }

  Future<void> refreshEventAfterRegistration(
    Map<String, dynamic> registeredEvent,
  ) async {
    final eventId = (registeredEvent['id'] ?? '').toString().trim();
    if (eventId.isEmpty) {
      await loadEvents();
      return;
    }

    final refreshed = await ApiService().getEvent(eventId);
    if (!mounted) return;
    if (refreshed == null) {
      await loadEvents();
      return;
    }

    final normalized = normalizeEvent(refreshed);
    setState(() {
      allEvents = allEvents
          .map(
            (event) =>
                (event['id'] ?? '').toString() == eventId ? normalized : event,
          )
          .toList();
    });
    searchEvent(searchController.text);
  }

  void openEventDetails(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => EventDetailsSheet(
        event: event,
        canJoin: canJoinEvent(event),
        statusLabel: eventStatusLabel(event),
        actionLabel: eventActionLabel(event),
        availabilityMessage: eventActionMessage(event),
        onJoin: () async {
          Navigator.pop(context);
          await handleJoinEvent(event);
        },
      ),
    );
  }

  Future<void> refreshEvents() async {
    setState(() => isLoading = true);
    await loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: refreshEvents,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _HeaderSection(onRefresh: refreshEvents),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                SliverToBoxAdapter(
                  child: _SearchField(
                    controller: searchController,
                    onChanged: handleSearchChanged,
                    onClear: clearFilters,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                SliverToBoxAdapter(
                  child: _ActivityChips(
                    activities: activities,
                    selectedActivity: selectedActivity,
                    onSelected: filterByActivity,
                    onAllSelected: clearFilters,
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 26)),

                SliverToBoxAdapter(
                  child: _SectionTitle(
                    title: sectionTitle,
                    subtitle: isLoading
                        ? "Loading events..."
                        : "${filteredEvents.length} event${filteredEvents.length == 1 ? "" : "s"} found",
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                if (isLoading)
                  SliverList.builder(
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return const _LoadingEventCard();
                    },
                  )
                else if (filteredEvents.isEmpty)
                  const SliverToBoxAdapter(child: _EmptySearchState())
                else
                  SliverList.builder(
                    itemCount: filteredEvents.length,
                    itemBuilder: (context, index) {
                      final event = filteredEvents[index];

                      return _EventResultCard(
                        event: event,
                        onTap: () => openEventDetails(event),
                      );
                    },
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 24)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _HeaderSection({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              shadowColor: Colors.black.withValues(alpha: 0.08),
              elevation: 2,
            ),
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Find Events",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  "Search events by title, venue, or activity",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              shadowColor: Colors.black.withValues(alpha: 0.08),
              elevation: 2,
            ),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: "Search events...",
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: const Icon(
            Icons.search_outlined,
            color: Color(0xFF2563EB),
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: Color(0xFF64748B)),
              );
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(22),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _ActivityChips extends StatelessWidget {
  final List<String> activities;
  final String selectedActivity;
  final ValueChanged<String> onSelected;
  final VoidCallback onAllSelected;

  const _ActivityChips({
    required this.activities,
    required this.selectedActivity,
    required this.onSelected,
    required this.onAllSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: activities.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final activity = isAll ? "All" : activities[index - 1];
          final selected = isAll
              ? selectedActivity.isEmpty
              : selectedActivity == activity;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _ActivityChip(
              label: activity,
              icon: isAll
                  ? Icons.grid_view_rounded
                  : Icons.local_activity_outlined,
              selected: selected,
              onTap: isAll ? onAllSelected : () => onSelected(activity),
            ),
          );
        },
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ActivityChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final background = selected ? const Color(0xFF2563EB) : Colors.white;
    final foreground = selected ? Colors.white : const Color(0xFF2563EB);
    final borderColor = selected
        ? const Color(0xFF2563EB)
        : const Color(0xFFE2E8F0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: selected ? 0.08 : 0.04),
              blurRadius: 9,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventResultCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onTap;

  const _EventResultCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bannerUrl = (event["banner_url"] ?? "").toString();
    final venue = (event["venue"] ?? "").toString();

    final imageProvider = bannerUrl.isEmpty
        ? const AssetImage("assets/map.jpg")
        : NetworkImage(bannerUrl) as ImageProvider;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        elevation: 0,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 66,
                    width: 66,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3F9),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event["title"].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _SmallInfoPill(
                            icon: Icons.local_activity_outlined,
                            label: event["event"].toString(),
                          ),
                          _SmallInfoPill(
                            icon: Icons.calendar_month_outlined,
                            label: event["date"].toString(),
                          ),
                        ],
                      ),
                      if (venue.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_outlined,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallInfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SmallInfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF2563EB)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingEventCard extends StatelessWidget {
  const _LoadingEventCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_outlined, size: 54, color: Color(0xFF2563EB)),
          SizedBox(height: 16),
          Text(
            "No events found",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Try searching another event, venue, or activity.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
