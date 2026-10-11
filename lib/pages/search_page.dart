import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/activity_data.dart';
import '../services/api_service.dart';
import '../widgets/event_details_sheet.dart';
import '../utils/event_category_registration.dart';
import '../utils/event_normalizer.dart';
import 'places_page.dart' show RegisterDialog;
import 'profile_settings_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as the rest of the app)
// ─────────────────────────────────────────────────────────────────────────────

const Color _brandPrimary = Color(0xFF6366F1);
const Color _brandDeep = Color(0xFF4F46E5);
const Color _accent = Color(0xFF0EA5E9);
const Color _brandSoft = Color(0xFFEEF2FF);
const Color _ink = Color(0xFF1E293B);
const Color _body = Color(0xFF475569);
const Color _muted = Color(0xFF64748B);
const Color _faint = Color(0xFF94A3B8);
const Color _border = Color(0xFFE2E8F0);
const Color _background = Color(0xFFF5F7FB);
const Color _fieldFill = Color(0xFFF8FAFC);
const Color _success = Color(0xFF16A34A);
const Color _amber = Color(0xFFD97706);
const Color _danger = Color(0xFFEF4444);
const Color _dangerSoft = Color(0xFFFEF2F2);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_brandDeep, _brandPrimary, _accent],
);

ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _brandPrimary,
      onPrimary: Colors.white,
      secondaryContainer: _brandSoft,
      onSecondaryContainer: _brandDeep,
      surfaceTint: Colors.transparent,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _brandPrimary,
      selectionColor: Color(0x336366F1),
      selectionHandleColor: _brandPrimary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: _brandPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: _brandPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: _brandPrimary,
        side: const BorderSide(color: _border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: shape,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: _brandPrimary),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

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
  bool loadFailed = false;
  bool isFetching = false;
  final Set<String> joiningIds = {};

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
    if (isFetching) return;
    isFetching = true;

    try {
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
        // Drop a selected chip that no longer exists after a refresh.
        if (!activities.contains(selectedActivity)) selectedActivity = "";
        allEvents = normalizedEvents;
        isLoading = false;
        loadFailed = false;
      });
      applyFilters();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    } finally {
      isFetching = false;
    }
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

  String normalizedSearchText(dynamic value) {
    return (value ?? "")
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9]+"), " ")
        .trim();
  }

  bool eventMatchesQuery(Map<String, dynamic> event, String search) {
    if (search.isEmpty) return true;

    final title = normalizedSearchText(event["title"]);
    final type = normalizedSearchText(event["event"]);
    final venue = normalizedSearchText(event["venue"]);
    final tags = normalizedSearchText(
      ((event["tags"] as List?) ?? []).join(" "),
    );

    return title.contains(search) ||
        type.contains(search) ||
        venue.contains(search) ||
        tags.contains(search) ||
        // Lets "trail run 10k" still match an event of type "Trail Run".
        // The isNotEmpty guard matters: "".contains check made every event
        // without a type match every search.
        (type.isNotEmpty && search.contains(type));
  }

  bool eventMatchesActivity(Map<String, dynamic> event, String activity) {
    if (activity.isEmpty) return true;

    final wanted = normalizedSearchText(activity);
    final type = normalizedSearchText(event["event"]);
    final tags = ((event["tags"] as List?) ?? []).map(normalizedSearchText);

    return type == wanted || tags.contains(wanted);
  }

  /// Text search and activity chip work together (e.g. "Taguig" + "Trail Run").
  void applyFilters() {
    final search = normalizedSearchText(searchController.text);

    setState(() {
      filteredEvents = allEvents
          .where(
            (event) =>
                eventMatchesQuery(event, search) &&
                eventMatchesActivity(event, selectedActivity),
          )
          .toList();
    });
  }

  void handleSearchChanged(String _) => applyFilters();

  void clearSearch() {
    searchController.clear();
    applyFilters();
  }

  void clearFilters() {
    searchController.clear();
    FocusScope.of(context).unfocus();
    selectedActivity = "";
    applyFilters();
  }

  void filterByActivity(String activity) {
    HapticFeedback.selectionClick();
    // Tapping the active chip again turns it off.
    selectedActivity = selectedActivity == activity ? "" : activity;
    applyFilters();
  }

  bool get hasActiveFilters =>
      selectedActivity.isNotEmpty || searchController.text.trim().isNotEmpty;

  String get sectionTitle {
    if (selectedActivity.isNotEmpty) {
      return "$selectedActivity Events";
    }

    return searchController.text.trim().isEmpty
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
    final eventKey = (event['id'] ?? '').toString();
    if (joiningIds.contains(eventKey)) return;
    joiningIds.add(eventKey);

    try {
      final apiService = ApiService();
      final user = await apiService.getUser();

      if (!mounted) return;

      if (!apiService.profileIsComplete(user)) {
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierColor: const Color(0x8C0F172A),
          builder: (dialogContext) => Theme(
            data: _brandTheme(dialogContext),
            child: const _CompleteProfileDialog(),
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
    } finally {
      joiningIds.remove(eventKey);
    }
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
    allEvents = allEvents
        .map(
          (event) =>
              (event['id'] ?? '').toString() == eventId ? normalized : event,
        )
        .toList();
    applyFilters();
  }

  void openEventDetails(Map<String, dynamic> event) {
    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: _brandTheme(sheetContext),
        child: EventDetailsSheet(
          event: event,
          canJoin: canJoinEvent(event),
          statusLabel: eventStatusLabel(event),
          actionLabel: eventActionLabel(event),
          availabilityMessage: eventActionMessage(event),
          onJoin: () async {
            Navigator.pop(sheetContext);
            await handleJoinEvent(event);
          },
        ),
      ),
    );
  }

  /// Header refresh button: full reload with skeletons.
  Future<void> refreshEvents() async {
    setState(() => isLoading = true);
    await loadEvents();
  }

  /// Pull-to-refresh keeps current results visible while reloading.
  Future<void> pullToRefresh() async {
    if (allEvents.isEmpty) {
      setState(() => isLoading = true);
    }
    await loadEvents();
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.canPop(context);
    final openCount = allEvents.where(canJoinEvent).length;

    return Theme(
      data: _brandTheme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          body: RefreshIndicator(
            color: _brandPrimary,
            backgroundColor: Colors.white,
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: pullToRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // Hero + floating search field
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 30),
                        child: _SearchHero(
                          onBack: canGoBack
                              ? () => Navigator.pop(context)
                              : null,
                          onRefresh: refreshEvents,
                          isLoading: isLoading,
                          totalEvents: allEvents.length,
                          openEvents: openCount,
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 0,
                        child: _SearchField(
                          controller: searchController,
                          onChanged: handleSearchChanged,
                          onClear: clearSearch,
                        ),
                      ),
                    ],
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                // Chips scroll edge-to-edge, so no horizontal padding here.
                SliverToBoxAdapter(
                  child: _ActivityChips(
                    activities: activities,
                    selectedActivity: selectedActivity,
                    onSelected: filterByActivity,
                    onAllSelected: () {
                      HapticFeedback.selectionClick();
                      selectedActivity = "";
                      applyFilters();
                    },
                  ),
                ),

                if (loadFailed && allEvents.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: _RefreshErrorBanner(onRetry: pullToRefresh),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 18)),

                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _SectionTitle(
                      title: sectionTitle,
                      count: isLoading ? null : filteredEvents.length,
                      subtitle: isLoading
                          ? "Loading events..."
                          : "${filteredEvents.length} event${filteredEvents.length == 1 ? "" : "s"} found",
                      trailing: hasActiveFilters
                          ? TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: _brandPrimary,
                                visualDensity: VisualDensity.compact,
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: clearFilters,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text("Clear"),
                            )
                          : null,
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 14)),

                if (isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: 4,
                      itemBuilder: (context, index) =>
                          const _LoadingEventCard(),
                    ),
                  )
                else if (filteredEvents.isEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: loadFailed && allEvents.isEmpty
                          ? _ErrorState(onRetry: refreshEvents)
                          : _EmptySearchState(
                              hasFilters: hasActiveFilters,
                              onClear: clearFilters,
                              onRefresh: refreshEvents,
                            ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: filteredEvents.length,
                      itemBuilder: (context, index) {
                        final event = filteredEvents[index];

                        return _EventResultCard(
                          event: event,
                          statusLabel: eventStatusLabel(event),
                          canJoin: canJoinEvent(event),
                          actionLabel: eventActionLabel(event),
                          onTap: () => openEventDetails(event),
                        );
                      },
                    ),
                  ),

                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 24 + MediaQuery.paddingOf(context).bottom,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────────────────────

class _SearchHero extends StatelessWidget {
  final VoidCallback? onBack;
  final Future<void> Function() onRefresh;
  final bool isLoading;
  final int totalEvents;
  final int openEvents;

  const _SearchHero({
    required this.onBack,
    required this.onRefresh,
    required this.isLoading,
    required this.totalEvents,
    required this.openEvents,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 58),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: "Back",
                  onTap: onBack!,
                ),
              const Spacer(),
              _GlassButton(
                icon: Icons.refresh_rounded,
                tooltip: "Refresh",
                onTap: isLoading ? null : onRefresh,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.travel_explore_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Find Events",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Search events by title, venue, or activity",
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(
                icon: Icons.event_rounded,
                label: isLoading
                    ? "Loading events…"
                    : "$totalEvents ${totalEvents == 1 ? 'event' : 'events'}",
              ),
              if (!isLoading)
                _HeroPill(
                  icon: Icons.how_to_reg_rounded,
                  label: "$openEvents open for registration",
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: Colors.white.withValues(alpha: 0.16),
          shape: CircleBorder(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              height: 42,
              width: 42,
              child: Icon(icon, color: Colors.white, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH + CHIPS
// ─────────────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E6366F1),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        cursorColor: _brandPrimary,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _ink),
        decoration: InputDecoration(
          hintText: "Search events, venues, activities...",
          hintStyle: const TextStyle(
            color: _faint,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 8, right: 4),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: _brandPrimary,
                size: 20,
              ),
            ),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 56,
            minHeight: 56,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) {
              if (value.text.isEmpty) {
                return const SizedBox.shrink();
              }

              return IconButton(
                onPressed: onClear,
                tooltip: "Clear search",
                icon: const Icon(Icons.close_rounded, color: _faint),
              );
            },
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
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
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
        clipBehavior: Clip.none,
        itemCount: activities.length + 1,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final activity = isAll ? "All" : activities[index - 1];
          final selected = isAll
              ? selectedActivity.isEmpty
              : selectedActivity == activity;

          return _ActivityChip(
            label: activity,
            icon: isAll
                ? Icons.grid_view_rounded
                : Icons.local_activity_outlined,
            selected: selected,
            onTap: isAll ? onAllSelected : () => onSelected(activity),
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
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? _heroGradient : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: selected ? Colors.transparent : _border),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x406366F1),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected && label != "All" ? Icons.check_rounded : icon,
                    size: 16,
                    color: selected ? Colors.white : _brandPrimary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : _body,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final int? count;
  final Widget? trailing;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _brandSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        "$count",
                        style: const TextStyle(
                          color: _brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT CARD
// ─────────────────────────────────────────────────────────────────────────────

class _EventResultCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final String statusLabel;
  final bool canJoin;
  final String actionLabel;
  final VoidCallback onTap;

  const _EventResultCard({
    required this.event,
    required this.statusLabel,
    required this.canJoin,
    required this.actionLabel,
    required this.onTap,
  });

  Color get statusColor {
    switch (statusLabel) {
      case "Ongoing":
        return _amber;
      case "Completed":
        return _muted;
      default:
        return canJoin ? _success : _brandPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bannerUrl = (event["banner_url"] ?? "").toString().trim();
    final title = (event["title"] ?? "").toString();
    final type = (event["event"] ?? "").toString().trim();
    final date = (event["date"] ?? "").toString().trim();
    final venue = (event["venue"] ?? "").toString().trim();
    final isRegistered = actionLabel == "Registered";

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: _softShadow,
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      height: 92,
                      width: 88,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          bannerUrl.isEmpty
                              ? const _ThumbnailFallback()
                              : Image.network(
                                  bannerUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                      ? child
                                      : const ColoredBox(color: _brandSoft),
                                  errorBuilder: (context, error, stackTrace) =>
                                      const _ThumbnailFallback(),
                                ),
                          if (date.isNotEmpty)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Color(0x000F172A),
                                      Color(0xB30F172A),
                                    ],
                                  ),
                                ),
                                child: Text(
                                  date,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _StatusPill(label: statusLabel, color: statusColor),
                            if (isRegistered) ...[
                              const SizedBox(width: 6),
                              const _StatusPill(
                                label: "Registered",
                                color: _brandPrimary,
                                icon: Icons.check_circle_rounded,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _ink,
                            height: 1.25,
                          ),
                        ),
                        if (venue.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: _muted,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  venue,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (type.isNotEmpty)
                              Flexible(
                                child: _SmallInfoPill(
                                  icon: Icons.local_activity_outlined,
                                  label: type,
                                ),
                              ),
                            const Spacer(),
                            Text(
                              canJoin ? "View & join" : "View details",
                              style: TextStyle(
                                color: canJoin ? _brandPrimary : _faint,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: canJoin ? _brandPrimary : _faint,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _StatusPill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 11, color: color)
          else
            Container(
              height: 6,
              width: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThumbnailFallback extends StatelessWidget {
  const _ThumbnailFallback();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/map.jpg",
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: _brandSoft,
        child: Center(
          child: Icon(Icons.event_outlined, color: _brandPrimary, size: 30),
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
        color: _brandSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _brandPrimary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _brandDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _CompleteProfileDialog extends StatelessWidget {
  const _CompleteProfileDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  gradient: _heroGradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x406366F1),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Complete Your Profile",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: _ink,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Please add your phone, address, birthdate, and emergency contact before joining an event.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _body,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _border),
                ),
                child: const Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    _RequirementChip(
                      icon: Icons.phone_outlined,
                      label: "Phone",
                    ),
                    _RequirementChip(
                      icon: Icons.home_outlined,
                      label: "Address",
                    ),
                    _RequirementChip(
                      icon: Icons.cake_outlined,
                      label: "Birthdate",
                    ),
                    _RequirementChip(
                      icon: Icons.contact_emergency_outlined,
                      label: "Emergency contact",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _body,
                        minimumSize: const Size.fromHeight(48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text("Later"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text("Open Settings"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RequirementChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _brandPrimary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _body,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING / EMPTY / ERROR
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton row with a gentle pulse, shaped like a result card.
class _LoadingEventCard extends StatefulWidget {
  const _LoadingEventCard();

  @override
  State<_LoadingEventCard> createState() => _LoadingEventCardState();
}

class _LoadingEventCardState extends State<_LoadingEventCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget block(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          block(88, 92, radius: 18),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(70, 16, radius: 99),
                const SizedBox(height: 8),
                block(double.infinity, 14),
                const SizedBox(height: 6),
                block(140, 14),
                const SizedBox(height: 10),
                Row(
                  children: [
                    block(80, 20, radius: 99),
                    const Spacer(),
                    block(60, 12),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return card;

    return FadeTransition(opacity: opacity, child: card);
  }
}

class _EmptySearchState extends StatelessWidget {
  final bool hasFilters;
  final VoidCallback onClear;
  final Future<void> Function() onRefresh;

  const _EmptySearchState({
    required this.hasFilters,
    required this.onClear,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: const BoxDecoration(
              color: _brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters ? Icons.search_off_rounded : Icons.event_busy_outlined,
              size: 32,
              color: _brandPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? "No events found" : "No events available",
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? "Try searching another event, venue, or activity."
                : "Pull down to refresh, or check back later.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          if (hasFilters)
            FilledButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text("Clear filters"),
            )
          else
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("Refresh"),
            ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 68,
            width: 68,
            decoration: const BoxDecoration(
              color: _dangerSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded, size: 32, color: _danger),
          ),
          const SizedBox(height: 16),
          const Text(
            "Couldn't load events",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _ink,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            "Check your connection and try again.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Try again"),
          ),
        ],
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _RefreshErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _danger, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Couldn't refresh. Showing the last loaded events.",
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text(
              "Retry",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
