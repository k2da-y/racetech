import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../profile/create_post.dart';
import '../profile/community_page.dart';
import 'profile_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/app_notification_service.dart';
import '../widgets/event_details_sheet.dart';
import '../utils/event_category_registration.dart';
import '../utils/event_schedule_formatter.dart';
import '../utils/event_normalizer.dart';
import '../utils/event_distance_formatter.dart';
import '../utils/payment_options.dart';
import '../utils/event_gear_formatter.dart';
import '../utils/event_trail_difficulty_formatter.dart';
import '../utils/qualification_notes.dart';
import '../utils/category_requirements.dart';
import '../widgets/health_conditions_selector.dart';
import '../widgets/notification_dialog.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/category_checkpoint_map.dart';
import '../widgets/announcement_image.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  List<String> userActivities = [];
  List<Map<String, dynamic>> filteredEvents = [];
  List<Map<String, dynamic>> apiEvents = [];
  List<Map<String, dynamic>> announcements = [];
  List<Map<String, dynamic>> posts = [];
  bool isLoadingEvents = true;
  bool isLoadingAnnouncements = true;
  bool isLoadingPosts = true;
  int unreadNotificationCount = 0;
  String? createPostError;
  late final VoidCallback notificationRefreshListener;

  int currentIndex = 0;

  Future<void> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList("activities") ?? [];
    final eventsFromApi = await ApiService().getEvents();
    final normalizedEvents = eventsFromApi.map(normalizeApiEvent).toList();
    final sortedEvents = sortEvents(normalizedEvents);
    final recommendedEvents = sortEventsByProfileInterests(
      normalizedEvents,
      activities,
    );

    if (!mounted) return;

    setState(() {
      userActivities = activities;
      apiEvents = sortedEvents;
      filteredEvents = recommendedEvents;
      currentIndex = 0;
      isLoadingEvents = false;
    });
  }

  List<Map<String, dynamic>> sortEventsByProfileInterests(
    List<Map<String, dynamic>> events,
    List<String> activities,
  ) {
    final sorted = List<Map<String, dynamic>>.from(events);

    sorted.sort((a, b) {
      final activityCompare = eventPreferenceRank(
        a,
        activities,
      ).compareTo(eventPreferenceRank(b, activities));
      if (activityCompare != 0) return activityCompare;

      final statusCompare = eventStatusRank(a).compareTo(eventStatusRank(b));
      if (statusCompare != 0) return statusCompare;

      return eventDateRank(a).compareTo(eventDateRank(b));
    });

    return sorted;
  }

  List<Map<String, dynamic>> sortEvents(List<Map<String, dynamic>> events) {
    final sorted = List<Map<String, dynamic>>.from(events);

    sorted.sort((a, b) {
      final statusCompare = eventStatusRank(a).compareTo(eventStatusRank(b));
      if (statusCompare != 0) return statusCompare;

      return eventDateRank(a).compareTo(eventDateRank(b));
    });

    return sorted;
  }

  int eventPreferenceRank(Map<String, dynamic> event, List<String> activities) {
    if (activities.isEmpty) {
      return 0;
    }

    return eventMatchesActivities(event, activities) ? 0 : 1;
  }

  bool eventMatchesActivities(
    Map<String, dynamic> event,
    List<String> activities,
  ) {
    final selectedActivities = activities
        .map(normalizeInterestLabel)
        .where((activity) => activity.isNotEmpty)
        .toSet();

    if (selectedActivities.isEmpty) {
      return false;
    }

    final tags = (event["tags"] as List?) ?? [];

    return tags
        .map(normalizeInterestLabel)
        .any((tag) => selectedActivities.contains(tag));
  }

  String normalizeInterestLabel(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? "";
  }

  int eventStatusRank(Map<String, dynamic> event) {
    final status = (event["status"] ?? "").toString().trim().toLowerCase();

    return switch (status) {
      "upcoming" => 0,
      "ongoing" => 1,
      "completed" => 2,
      _ => 3,
    };
  }

  int eventDateRank(Map<String, dynamic> event) {
    final parsed = DateTime.tryParse(
      (event["event_start_date"] ?? event["date"] ?? "").toString(),
    );

    return parsed?.millisecondsSinceEpoch ?? (1 << 62);
  }

  Map<String, dynamic> normalizeApiEvent(Map<String, dynamic> event) {
    return normalizeEventFromApi(event);
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

  String eventAvailabilityMessage(Map<String, dynamic> event) {
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

  String eventStatusLabel(Map<String, dynamic> event) {
    final status = (event["status"] ?? "").toString().trim().toLowerCase();

    return switch (status) {
      "ongoing" => "Ongoing",
      "completed" => "Completed",
      _ => "Upcoming",
    };
  }

  @override
  void initState() {
    super.initState();
    loadUserPreferences();
    loadAnnouncements();
    loadCommunityPosts();
    loadUnreadNotificationCount();
    notificationRefreshListener = loadUnreadNotificationCount;
    AppNotificationService.refreshListenable.addListener(
      notificationRefreshListener,
    );
  }

  @override
  void dispose() {
    AppNotificationService.refreshListenable.removeListener(
      notificationRefreshListener,
    );
    super.dispose();
  }

  Future<void> loadUnreadNotificationCount() async {
    final notifications = await ApiService().getNotifications();

    if (!mounted) return;

    setState(() {
      unreadNotificationCount = notifications
          .where((notification) => notification["is_read"] != true)
          .length;
    });
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
    await loadUnreadNotificationCount();
  }

  Future<void> refreshEventAfterRegistration(
    Map<String, dynamic> registeredEvent,
  ) async {
    final eventId = (registeredEvent['id'] ?? '').toString().trim();
    if (eventId.isEmpty) {
      await loadUserPreferences();
      return;
    }

    final refreshed = await ApiService().getEvent(eventId);
    if (!mounted) return;
    if (refreshed == null) {
      setState(() => isLoadingEvents = true);
      await loadUserPreferences();
      return;
    }

    final normalized = normalizeApiEvent(refreshed);
    final updatedEvents = apiEvents
        .map(
          (event) =>
              (event['id'] ?? '').toString() == eventId ? normalized : event,
        )
        .toList();

    setState(() {
      apiEvents = sortEvents(updatedEvents);
      filteredEvents = sortEventsByProfileInterests(
        updatedEvents,
        userActivities,
      );
      isLoadingEvents = false;
    });
  }

  void openEventDetails(Map<String, dynamic> event) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => EventDetailsSheet(
        event: event,
        canJoin: canJoinEvent(event),
        statusLabel: eventStatusLabel(event),
        actionLabel: eventActionLabel(event),
        availabilityMessage: eventAvailabilityMessage(event),
        onJoin: () async {
          Navigator.pop(sheetContext);
          await handleJoinEvent(event);
        },
      ),
    );
  }

  Future<void> openAnnouncementEvent(Map<String, dynamic> announcement) async {
    final eventId =
        (announcement["action_event_id"] ?? announcement["event_id"] ?? "")
            .toString()
            .trim();

    if (eventId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Event details are unavailable.")),
      );
      return;
    }

    final loadedEvents = [...apiEvents, ...filteredEvents];
    for (final event in loadedEvents) {
      if ((event["id"] ?? "").toString() == eventId) {
        openEventDetails(event);
        return;
      }
    }

    final event = await ApiService().getEvent(eventId);

    if (!mounted) return;

    if (event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to load event details.")),
      );
      return;
    }

    openEventDetails(normalizeApiEvent(event));
  }

  Map<String, dynamic> normalizeCommunityPost(Map<String, dynamic> post) {
    final user = Map<String, dynamic>.from(post["user"] ?? {});
    final title = (post["title"] ?? "").toString().trim();
    final content = (post["content"] ?? "").toString().trim();

    return {
      "id": post["id"],
      "name": (user["name"] ?? "Runner").toString(),
      "avatar_url": (user["avatar_url"] ?? "").toString(),
      "title": title,
      "content": content,
      "image_url": (post["image_url"] ?? "").toString(),
      "video_url": (post["video_url"] ?? "").toString(),
      "comments_count": ((post["comments"] as List?) ?? []).length,
      "likes_count": int.tryParse((post["likes_count"] ?? 0).toString()) ?? 0,
      "liked_by_me": post["liked_by_me"] == true,
    };
  }

  Future<void> loadCommunityPosts() async {
    final data = await ApiService().getCommunityPosts();

    if (!mounted) return;

    setState(() {
      posts = data.map(normalizeCommunityPost).take(5).toList();
      isLoadingPosts = false;
    });
  }

  Map<String, dynamic> normalizeAnnouncement(
    Map<String, dynamic> announcement,
  ) {
    final event = announcement["event"] is Map
        ? Map<String, dynamic>.from(announcement["event"])
        : null;
    final action = announcement["action"] is Map
        ? Map<String, dynamic>.from(announcement["action"])
        : null;

    return {
      "id": announcement["id"],
      "event_id": announcement["event_id"],
      "title": (announcement["title"] ?? "Announcement").toString(),
      "content": (announcement["content"] ?? "").toString(),
      "image_url": announcementImageUrl(announcement),
      "published_at": (announcement["published_at"] ?? "").toString(),
      "event_title": event?["title"]?.toString() ?? "",
      "action_label": (action?["label"] ?? "View Event").toString(),
      "action_event_id": (action?["event_id"] ?? announcement["event_id"] ?? "")
          .toString(),
    };
  }

  Future<void> loadAnnouncements() async {
    final data = await ApiService().getAnnouncements();

    if (!mounted) return;

    setState(() {
      announcements = data.map(normalizeAnnouncement).take(5).toList();
      isLoadingAnnouncements = false;
    });
  }

  Future<bool> addPost(
    String title,
    String content, {
    String? mediaPath,
  }) async {
    createPostError = null;

    final result = await ApiService().createCommunityPost(
      title: title,
      content: content,
      mediaPath: mediaPath,
    );

    if (!mounted) return false;

    if (!result.success || result.data == null) {
      createPostError = result.message;
      return false;
    }

    setState(() {
      posts.insert(0, normalizeCommunityPost(result.data!));
      posts = posts.take(5).toList();
    });

    return true;
  }

  Future<void> toggleCommunityLike(Map<String, dynamic> post) async {
    final postId = (post["id"] ?? "").toString();

    if (postId.isEmpty) {
      openCommunityPage();
      return;
    }

    final wasLiked = post["liked_by_me"] == true;
    final currentLikes =
        int.tryParse((post["likes_count"] ?? 0).toString()) ?? 0;

    setState(() {
      post["liked_by_me"] = !wasLiked;
      post["likes_count"] = wasLiked
          ? (currentLikes - 1).clamp(0, 1 << 31)
          : currentLikes + 1;
    });

    final result = await ApiService().toggleCommunityLike(postId);

    if (!mounted) return;

    if (result == null) {
      setState(() {
        post["liked_by_me"] = wasLiked;
        post["likes_count"] = currentLikes;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to update like.")));
      return;
    }

    setState(() {
      post["liked_by_me"] = result["liked"] == true;
      post["likes_count"] =
          int.tryParse((result["likes_count"] ?? 0).toString()) ?? currentLikes;
    });
  }

  void openCommunityPage() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CommunityPage()),
    ).then((_) {
      if (!mounted) return;

      setState(() => isLoadingPosts = true);
      loadCommunityPosts();
    });
  }

  void openCreatePostSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => CreatePostSheet(
        onPost: addPost,
        errorMessage: () => createPostError ?? "Unable to create post.",
      ),
    );
  }

  Future<void> openNotifications() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const NotificationDialog(),
    );

    await loadUnreadNotificationCount();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              isLoadingEvents = true;
              isLoadingAnnouncements = true;
              isLoadingPosts = true;
            });

            await loadUserPreferences();
            await loadAnnouncements();
            await loadCommunityPosts();
            await loadUnreadNotificationCount();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  child: _HeaderSection(
                    unreadNotificationCount: unreadNotificationCount,
                    onNotificationTap: openNotifications,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _SectionTitle(
                    title: "Events",
                    subtitle: userActivities.isEmpty
                        ? "Discover available events near you"
                        : "Recommended from your interests",
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              SliverToBoxAdapter(
                child: _EventCarousel(
                  isLoading: isLoadingEvents,
                  events: filteredEvents,
                  currentIndex: currentIndex,
                  onPageChanged: (index) {
                    setState(() => currentIndex = index);
                  },
                  canJoinEvent: canJoinEvent,
                  eventActionLabel: eventActionLabel,
                  eventStatusLabel: eventStatusLabel,
                  onOpenDetails: openEventDetails,
                  onJoin: handleJoinEvent,
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionTitle(
                    title: "Announcements",
                    subtitle: "Latest updates from organizers",
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (isLoadingAnnouncements)
                const SliverToBoxAdapter(child: _AnnouncementSkeletonList())
              else if (announcements.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: _EmptyCard(
                      icon: Icons.campaign_outlined,
                      title: "No announcements yet",
                      message: "Organizer updates will appear here.",
                    ),
                  ),
                )
              else
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: announcements.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _AnnouncementCard(
                          announcement: announcements[index],
                          onOpenEvent: openAnnouncementEvent,
                        );
                      },
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 28)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionTitle(
                    title: "Community",
                    subtitle: "Latest public posts",
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: openCommunityPage,
                          child: const Text("View all"),
                        ),
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: openCreatePostSheet,
                          icon: const Icon(Icons.add),
                          tooltip: "Create post",
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              if (isLoadingPosts)
                const SliverToBoxAdapter(child: _CommunitySkeletonList())
              else if (posts.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _EmptyCard(
                      icon: Icons.forum_outlined,
                      title: "No community posts yet",
                      message: "Be the first one to share something.",
                      onTap: openCreatePostSheet,
                    ),
                  ),
                )
              else
                SliverList.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];

                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _CommunityPostCard(
                        post: post,
                        onTap: openCommunityPage,
                        onLike: () => toggleCommunityLike(post),
                        onOpenComments: openCommunityPage,
                      ),
                    );
                  },
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 96)),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const AppBottomNavBar(currentPage: AppNavPage.home),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final int unreadNotificationCount;
  final VoidCallback onNotificationTap;

  const _HeaderSection({
    required this.unreadNotificationCount,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_run_rounded,
            color: Color(0xFF2563EB),
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Racetech",
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "Run. Train. Connect.",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        Badge(
          isLabelVisible: unreadNotificationCount > 0,
          label: Text(
            unreadNotificationCount > 9
                ? "9+"
                : unreadNotificationCount.toString(),
          ),
          child: IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF2563EB),
              shadowColor: Colors.black.withValues(alpha: 0.08),
              elevation: 2,
            ),
            onPressed: onNotificationTap,
            icon: const Icon(Icons.notifications_none),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

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
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
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

class _EventCarousel extends StatelessWidget {
  final bool isLoading;
  final List<Map<String, dynamic>> events;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final bool Function(Map<String, dynamic>) canJoinEvent;
  final String Function(Map<String, dynamic>) eventActionLabel;
  final String Function(Map<String, dynamic>) eventStatusLabel;
  final ValueChanged<Map<String, dynamic>> onOpenDetails;
  final Future<void> Function(Map<String, dynamic>) onJoin;

  const _EventCarousel({
    required this.isLoading,
    required this.events,
    required this.currentIndex,
    required this.onPageChanged,
    required this.canJoinEvent,
    required this.eventActionLabel,
    required this.eventStatusLabel,
    required this.onOpenDetails,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: _EventCardSkeleton(),
      );
    }

    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: _EmptyCard(
          icon: Icons.event_busy_outlined,
          title: "No events available",
          message: "Please check again later for upcoming events.",
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 340,
          child: PageView.builder(
            itemCount: events.length,
            controller: PageController(viewportFraction: 0.88),
            onPageChanged: onPageChanged,
            itemBuilder: (context, index) {
              final event = events[index];
              final canJoin = canJoinEvent(event);
              final actionLabel = eventActionLabel(event);
              final statusLabel = eventStatusLabel(event);

              return _EventCard(
                event: event,
                canJoin: canJoin,
                actionLabel: actionLabel,
                statusLabel: statusLabel,
                onOpenDetails: () => onOpenDetails(event),
                onJoin: () => onJoin(event),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(events.length, (index) {
            final selected = currentIndex == index;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: selected ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF2563EB)
                    : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final bool canJoin;
  final String actionLabel;
  final String statusLabel;
  final VoidCallback onOpenDetails;
  final VoidCallback onJoin;

  const _EventCard({
    required this.event,
    required this.canJoin,
    required this.actionLabel,
    required this.statusLabel,
    required this.onOpenDetails,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpenDetails,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: const Color(0xFF0F172A),
                child: _EventBannerImage(
                  bannerUrl: (event["banner_url"] ?? "").toString(),
                  assetPath: event["image"].toString(),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: _EventBadge(
                            icon: Icons.local_activity_outlined,
                            label: event["event"].toString(),
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _EventBadge(
                          icon: canJoin
                              ? Icons.event_available_outlined
                              : Icons.verified_outlined,
                          label: statusLabel,
                          color: canJoin
                              ? const Color(0xFF16A34A)
                              : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      event["title"].toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        height: 1.05,
                      ),
                    ),
                    if ((event["venue"] ?? "")
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Colors.white,
                            size: 17,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              event["venue"].toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _EventInfoChip(
                          icon: Icons.groups_2_outlined,
                          label: "${event["participants"]} participants",
                        ),
                        _EventInfoChip(
                          icon: Icons.calendar_month_outlined,
                          label: event["date"].toString(),
                        ),
                        _EventInfoChip(
                          icon: Icons.schedule_outlined,
                          label: event["time"].toString(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: canJoin ? onJoin : null,
                        icon: Icon(
                          canJoin ? Icons.arrow_forward_rounded : Icons.lock,
                        ),
                        label: Text(actionLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: canJoin
                              ? const Color(0xFF2563EB)
                              : Colors.grey,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _EventBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCardSkeleton extends StatelessWidget {
  const _EventCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 340,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBlock(width: 120, height: 30, radius: 99),
              const SizedBox(width: 8),
              _SkeletonBlock(width: 92, height: 30, radius: 99),
            ],
          ),
          const Spacer(),
          const _SkeletonBlock(width: double.infinity, height: 28),
          const SizedBox(height: 8),
          const _SkeletonBlock(width: 190, height: 28),
          const SizedBox(height: 14),
          Row(
            children: const [
              _SkeletonBlock(width: 92, height: 28, radius: 99),
              SizedBox(width: 8),
              _SkeletonBlock(width: 104, height: 28, radius: 99),
            ],
          ),
          const SizedBox(height: 16),
          const _SkeletonBlock(width: double.infinity, height: 48, radius: 14),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EventBannerImage extends StatelessWidget {
  final String bannerUrl;
  final String assetPath;

  const _EventBannerImage({required this.bannerUrl, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    if (bannerUrl.trim().isNotEmpty) {
      return Image.network(
        bannerUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _EventImageFallback(assetPath: assetPath),
      );
    }

    return _EventImageFallback(assetPath: assetPath);
  }
}

class _EventImageFallback extends StatelessWidget {
  final String assetPath;

  const _EventImageFallback({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Icon(Icons.event_outlined, color: Colors.white, size: 46),
          ),
        );
      },
    );
  }
}

class _EventInfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _EventInfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventNotice extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;

  const _EventNotice({
    required this.icon,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final Future<void> Function(Map<String, dynamic> announcement)? onOpenEvent;

  const _AnnouncementCard({required this.announcement, this.onOpenEvent});

  @override
  Widget build(BuildContext context) {
    final title = announcement["title"].toString();
    final content = announcement["content"].toString();
    final eventTitle = announcement["event_title"].toString();
    final imageUrl = announcementImageUrl(announcement);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => _AnnouncementDetailsSheet(
            announcement: announcement,
            onOpenEvent: onOpenEvent,
          ),
        );
      },
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF2FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    eventTitle.isEmpty ? "General" : eventTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Expanded(
                          child: Text(
                            content,
                            maxLines: imageUrl.isEmpty ? 3 : 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (imageUrl.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 82,
                      child: AnnouncementImage(
                        imageUrl: imageUrl,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementSkeletonList extends StatelessWidget {
  const _AnnouncementSkeletonList();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: 2,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => const _AnnouncementSkeletonCard(),
      ),
    );
  }
}

class _AnnouncementSkeletonCard extends StatelessWidget {
  const _AnnouncementSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBlock(width: 38, height: 38, radius: 14),
              SizedBox(width: 10),
              _SkeletonBlock(width: 150, height: 14),
            ],
          ),
          SizedBox(height: 18),
          _SkeletonBlock(width: double.infinity, height: 20),
          SizedBox(height: 8),
          _SkeletonBlock(width: 210, height: 20),
          SizedBox(height: 14),
          _SkeletonBlock(width: double.infinity, height: 14),
          SizedBox(height: 8),
          _SkeletonBlock(width: 190, height: 14),
        ],
      ),
    );
  }
}

class _AnnouncementDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final Future<void> Function(Map<String, dynamic> announcement)? onOpenEvent;

  const _AnnouncementDetailsSheet({
    required this.announcement,
    this.onOpenEvent,
  });

  @override
  Widget build(BuildContext context) {
    final title = announcement["title"].toString();
    final content = announcement["content"].toString();
    final eventTitle = announcement["event_title"].toString();
    final imageUrl = announcementImageUrl(announcement);
    final actionEventId = (announcement["action_event_id"] ?? "")
        .toString()
        .trim();
    final actionLabel = (announcement["action_label"] ?? "View Event")
        .toString();

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          22,
          18,
          22,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.campaign_outlined, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    eventTitle.isEmpty ? "General announcement" : eventTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 24,
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 14),
            if (imageUrl.isNotEmpty) ...[
              AnnouncementImage(imageUrl: imageUrl),
              const SizedBox(height: 16),
            ],
            Text(
              content,
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            if (actionEventId.isNotEmpty && onOpenEvent != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onOpenEvent?.call(announcement);
                },
                icon: const Icon(Icons.event_available_outlined),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CommunityPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onOpenComments;

  const _CommunityPostCard({
    required this.post,
    required this.onTap,
    required this.onLike,
    required this.onOpenComments,
  });

  @override
  Widget build(BuildContext context) {
    final title = (post["title"] ?? "").toString();
    final content = (post["content"] ?? "").toString();
    final name = (post["name"] ?? "Runner").toString();
    final avatarUrl = (post["avatar_url"] ?? "").toString();
    final initial = name.trim().isEmpty ? "R" : name.trim()[0].toUpperCase();
    final imageUrl = (post["image_url"] ?? "").toString();
    final videoUrl = (post["video_url"] ?? "").toString();
    final hasMedia = imageUrl.isNotEmpty || videoUrl.isNotEmpty;
    final likedByMe = post["liked_by_me"] == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(22)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF2FF),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: avatarUrl.isNotEmpty
                        ? Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _CommunityAvatarInitial(initial: initial),
                          )
                        : _CommunityAvatarInitial(initial: initial),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Icon(Icons.open_in_new, color: Color(0xFF64748B)),
                ],
              ),
              const SizedBox(height: 12),
              if (title.isNotEmpty) ...[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                content,
                maxLines: hasMedia ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasMedia) ...[
                const SizedBox(height: 12),
                if (videoUrl.isNotEmpty)
                  const _CommunityMediaFallback(
                    icon: Icons.play_circle_fill_rounded,
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: _CommunityPostImage(imageUrl),
                  ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  InkWell(
                    onTap: onLike,
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            likedByMe ? Icons.favorite : Icons.favorite_border,
                            size: 18,
                            color: likedByMe
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "${post["likes_count"]}",
                            style: TextStyle(
                              color: likedByMe
                                  ? const Color(0xFFE11D48)
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  InkWell(
                    onTap: onOpenComments,
                    borderRadius: BorderRadius.circular(99),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.mode_comment_outlined,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "${post["comments_count"]}",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
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

class _CommunitySkeletonList extends StatelessWidget {
  const _CommunitySkeletonList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: const [
          _CommunitySkeletonCard(),
          SizedBox(height: 14),
          _CommunitySkeletonCard(compact: true),
        ],
      ),
    );
  }
}

class _CommunitySkeletonCard extends StatelessWidget {
  final bool compact;

  const _CommunitySkeletonCard({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _SkeletonBlock(width: 44, height: 44, radius: 15),
              SizedBox(width: 10),
              _SkeletonBlock(width: 150, height: 16),
            ],
          ),
          const SizedBox(height: 14),
          const _SkeletonBlock(width: 210, height: 18),
          const SizedBox(height: 8),
          const _SkeletonBlock(width: double.infinity, height: 14),
          const SizedBox(height: 7),
          const _SkeletonBlock(width: 250, height: 14),
          if (!compact) ...[
            const SizedBox(height: 12),
            const _SkeletonBlock(
              width: double.infinity,
              height: 120,
              radius: 18,
            ),
          ],
          const SizedBox(height: 12),
          const Row(
            children: [
              _SkeletonBlock(width: 46, height: 18, radius: 99),
              SizedBox(width: 18),
              _SkeletonBlock(width: 46, height: 18, radius: 99),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommunityPostImage extends StatelessWidget {
  final String imageUrl;

  const _CommunityPostImage(this.imageUrl);

  @override
  Widget build(BuildContext context) {
    return Image.network(
      imageUrl,
      height: 150,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _CommunityMediaFallback(icon: Icons.broken_image_outlined),
    );
  }
}

class _CommunityMediaFallback extends StatelessWidget {
  final IconData icon;

  const _CommunityMediaFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: const Color(0xFF2563EB), size: 44),
    );
  }
}

class _CommunityAvatarInitial extends StatelessWidget {
  final String initial;

  const _CommunityAvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Color(0xFF2563EB),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 220,
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 42, color: const Color(0xFF2563EB)),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(height: 14),
                const Text(
                  "Tap to create a post",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// REGISTRATION DIALOG SA JOIN EVENT BUTTON
class RegisterDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  final String initialMedicalConditions;

  const RegisterDialog({
    super.key,
    required this.event,
    this.initialMedicalConditions = "",
  });

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  int step = 0;
  String size = "M";
  bool acceptedWaiver = false;
  bool firstAidKitConfirmed = false;
  bool isSubmitting = false;
  int? selectedCategoryId;
  String? selectedPaymentProvider;
  Map<String, dynamic>? createdRegistration;
  XFile? paymentProofImage;
  PlatformFile? medicalCertificateFile;

  final medicalConditionsController = TextEditingController();
  final paymentReferenceController = TextEditingController();
  final paymentNotesController = TextEditingController();
  final paymentProofPicker = ImagePicker();

  List<Map<String, dynamic>> get categories {
    return ((widget.event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
  }

  String get categoryLabel {
    final apiLabel = (widget.event["category_label"] ?? "").toString().trim();
    if (apiLabel.isNotEmpty) return apiLabel;

    final eventType = (widget.event["event"] ?? "").toString().toLowerCase();
    if (eventType.contains("cycling")) return "Ride Categories";
    if (eventType.contains("hiking")) {
      return "Hiking Routes / Registration Options";
    }
    if (eventType.contains("marathon") || eventType.contains("trail run")) {
      return "Race Categories";
    }
    if (eventType.contains("triathlon") || eventType.contains("duathlon")) {
      return "Competition Categories";
    }
    return "Categories";
  }

  Map<String, dynamic>? categoryById(int? id) {
    if (id == null) return null;

    for (final category in categories) {
      final categoryId = int.tryParse((category["id"] ?? "").toString());
      if (categoryId == id) {
        return category;
      }
    }

    return null;
  }

  Map<String, dynamic>? get selectedCategory =>
      categoryById(selectedCategoryId);

  String categoryOptionLabel(Map<String, dynamic> category) {
    final distance = category["distance_km"];
    final slots = category["slots_remaining"];
    final price = (category["price_amount"] ?? "").toString();
    final currency = (category["price_currency"] ?? "PHP").toString();
    final isFree =
        category["is_free"] == true ||
        (int.tryParse((category["price_cents"] ?? 0).toString()) ?? 0) == 0;
    final schedule = categoryScheduleLabel(
      category,
      eventStartDate: widget.event["event_start_date"],
      eventEndDate: widget.event["event_end_date"],
      legacyEventDate: widget.event["legacy_event_date"],
      eventStartTime: widget.event["time"],
      eventEndTime: widget.event["end_time"],
    );
    final segments = categorySegmentDistanceLabel(
      category,
      eventType: widget.event["event"],
      eventTypeDetails: widget.event["type_details"],
      eventTypeDetailItems: widget.event["type_detail_items"],
    );
    final gear = categoryGearLabel(
      category,
      eventType: widget.event["event"],
      eventTypeDetails: widget.event["type_details"],
      eventTypeDetailItems: widget.event["type_detail_items"],
    );
    final trailDifficulty = categoryTrailDifficultyLabel(
      category,
      eventType: widget.event["event"],
      eventTypeDetails: widget.event["type_details"],
      eventTypeDetailItems: widget.event["type_detail_items"],
    );
    final qualificationNotes = categoryQualificationNotes(category);
    final status = categoryStatusLabel(category);
    final label = [
      category["name"],
      if (segments.isNotEmpty) segments,
      if (gear.isNotEmpty) gear,
      if (trailDifficulty.isNotEmpty) trailDifficulty,
      if (qualificationNotes.isNotEmpty)
        "Qualification notes\n$qualificationNotes",
      if (schedule.isNotEmpty) schedule,
      if (distance != null) "${distance}km",
      isFree ? "Free" : "$currency $price",
      if (slots != null) "$slots slots left",
      if (!categoryCanRegister(category)) status,
    ];

    return label.join(" \u2014 ");
  }

  @override
  void initState() {
    super.initState();
    medicalConditionsController.text = widget.initialMedicalConditions.trim();
    final availableCategories = categories.where(categoryCanRegister).toList();
    if (availableCategories.isNotEmpty) {
      selectedCategoryId = int.tryParse(
        (availableCategories.first["id"] ?? "").toString(),
      );
    }
  }

  @override
  void dispose() {
    medicalConditionsController.dispose();
    paymentReferenceController.dispose();
    paymentNotesController.dispose();
    super.dispose();
  }

  Map<String, dynamic> get paymentCategory {
    final value = createdRegistration?["category"];
    return value is Map
        ? Map<String, dynamic>.from(value)
        : selectedCategory ?? <String, dynamic>{};
  }

  List<Map<String, dynamic>> get paymentOptions => enabledPaymentOptions(
    registration: createdRegistration,
    category: paymentCategory,
    event: widget.event,
  );

  Map<String, dynamic>? get selectedPaymentOption =>
      paymentOptionByProvider(paymentOptions, selectedPaymentProvider);

  bool get selectedPaymentIsPayMongo => isPayMongoOption(selectedPaymentOption);

  void selectInitialPaymentProvider(Map<String, dynamic> registration) {
    final preferred =
        registration["payment_provider"] ?? registration["provider"];
    final option = paymentOptionByProvider(paymentOptions, preferred);
    selectedPaymentProvider = option?["provider"]?.toString();
  }

  bool get selectedCategoryRequiresPayment {
    final category = selectedCategory;
    if (category == null) return false;

    if (category["is_free"] == true) return false;

    return (int.tryParse((category["price_cents"] ?? 0).toString()) ?? 0) > 0;
  }

  bool get selectedCategoryRequiresMedicalCertificate {
    final category = selectedCategory;
    if (category == null) return false;
    return categoryRequiresMedicalCertificate(category);
  }

  String moneyLabel(Map<String, dynamic>? category) {
    if (category == null) return "PHP 0.00";

    final currency = (category["price_currency"] ?? "PHP").toString();
    final amount = (category["price_amount"] ?? "").toString();
    if (amount.isNotEmpty) return "$currency $amount";

    final cents = int.tryParse((category["price_cents"] ?? 0).toString()) ?? 0;
    return "$currency ${(cents / 100).toStringAsFixed(2)}";
  }

  Future<void> pickPaymentProof() async {
    final picked = await paymentProofPicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (picked == null || !mounted) return;

    setState(() => paymentProofImage = picked);
  }

  Future<void> pickMedicalCertificate() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ["jpg", "jpeg", "png", "webp", "pdf"],
      allowMultiple: false,
    );

    final file = picked?.files.single;
    if (file == null || file.path == null || !mounted) return;

    setState(() => medicalCertificateFile = file);
  }

  Future<void> submitRegistration() async {
    final eventId = widget.event["id"];
    final categoryId = selectedCategoryId;

    if (eventId == null || categoryId == null) {
      showMessage("This event is not available for registration.");
      return;
    }

    if (!acceptedWaiver) {
      showMessage("Please agree to the waiver.");
      return;
    }

    if (!firstAidKitConfirmed) {
      showMessage(
        "Please confirm that you will bring a personal first aid kit.",
      );
      return;
    }

    if (selectedCategoryRequiresMedicalCertificate &&
        medicalCertificateFile?.path == null) {
      showMessage("Please upload your medical certificate.");
      return;
    }

    setState(() => isSubmitting = true);

    final result = await ApiService().registerForEventWithData(
      eventId: int.parse(eventId.toString()),
      categoryId: categoryId,
      shirtSize: size,
      medicalConditions: medicalConditionsController.text.trim(),
      firstAidKitConfirmed: firstAidKitConfirmed,
      waiverAccepted: acceptedWaiver,
      medicalCertificatePath: medicalCertificateFile?.path,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => isSubmitting = false);
      showMessage(result.message);
      return;
    }

    final registration = result.data ?? <String, dynamic>{};
    final paymentRequired = registration["payment_required"] == true;

    if (paymentRequired) {
      setState(() {
        createdRegistration = registration;
        selectInitialPaymentProvider(registration);
        isSubmitting = false;
        step = 2;
      });
      return;
    }

    setState(() => isSubmitting = false);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RegistrationSuccessDialog(
        eventTitle: widget.event["title"].toString(),
        message: result.message,
      ),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> submitPaymentProof() async {
    final registrationId = int.tryParse(
      (createdRegistration?["id"] ?? "").toString(),
    );

    if (registrationId == null) {
      showMessage("Registration was created, but payment details are missing.");
      return;
    }

    if (paymentReferenceController.text.trim().isEmpty &&
        paymentProofImage == null) {
      showMessage("Add a payment reference or upload proof of payment.");
      return;
    }

    setState(() => isSubmitting = true);

    final result = await ApiService().submitPaymentProof(
      registrationId: registrationId,
      provider: (selectedPaymentOption?["provider"] ?? "manual").toString(),
      providerReference: paymentReferenceController.text,
      notes: paymentNotesController.text,
      proofImagePath: paymentProofImage?.path,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => _RegistrationSuccessDialog(
        eventTitle: widget.event["title"].toString(),
        message: result.message,
      ),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> startPayMongoCheckout() async {
    final registrationId = int.tryParse(
      (createdRegistration?["id"] ?? "").toString(),
    );

    if (registrationId == null) {
      showMessage("Registration was created, but payment details are missing.");
      return;
    }

    setState(() => isSubmitting = true);

    final result = await ApiService().createPayMongoCheckout(
      registrationId: registrationId,
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    final checkoutUrl = (result.data?["checkout_url"] ?? "").toString();
    final updatedRegistration = result.data?["registration"];
    if (updatedRegistration is Map) {
      createdRegistration = Map<String, dynamic>.from(updatedRegistration);
    }

    final uri = Uri.tryParse(checkoutUrl);
    if (uri == null || checkoutUrl.isEmpty) {
      showMessage("Online checkout link is missing. Please try again.");
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;

    if (!opened) {
      showMessage("Unable to open PayMongo checkout.");
      return;
    }

    showMessage("Complete your payment in PayMongo, then return to the app.");
    Navigator.pop(context, true);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.86;
    final availableCategories = categories.where(categoryCanRegister).toList();
    final canContinue = step > 0 || availableCategories.isNotEmpty;
    final canSubmit = step != 1 || (acceptedWaiver && firstAidKitConfirmed);
    final submitLabel = step == 0
        ? "Next"
        : step == 1
        ? "Submit"
        : "Submit Payment";

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxDialogHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                step == 0
                    ? Icons.app_registration_rounded
                    : Icons.verified_user_outlined,
                size: 42,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              const Text(
                "Register",
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _RegistrationStepIndicator(step: step),
              const SizedBox(height: 18),
              _RegistrationEventSummary(
                title: widget.event["title"].toString(),
                date: widget.event["date"].toString(),
                time: widget.event["time"].toString(),
                venue: (widget.event["venue"] ?? "").toString(),
              ),
              const SizedBox(height: 22),

              if (step == 0) ...[
                if (availableCategories.isEmpty) ...[
                  const _EventNotice(
                    icon: Icons.lock_outline_rounded,
                    message:
                        "No compatible categories are available for another registration.",
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(height: 12),
                ],

                if (categories.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    itemHeight: null,
                    initialValue: selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: categoryLabel,
                      prefixIcon: const Icon(Icons.flag_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    items: categories.map((category) {
                      final enabled = categoryCanRegister(category);
                      return DropdownMenuItem(
                        value: int.tryParse((category["id"] ?? "").toString()),
                        enabled: enabled,
                        child: Text(
                          categoryOptionLabel(category),
                          maxLines: 7,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enabled ? null : const Color(0xFF64748B),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                        selectedPaymentProvider = null;
                      });
                    },
                  ),

                  if (selectedCategory != null &&
                      categoryQualificationNotes(
                        selectedCategory!,
                      ).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _EventNotice(
                      icon: Icons.fact_check_outlined,
                      message:
                          "Qualification notes\n${categoryQualificationNotes(selectedCategory!)}",
                      color: const Color(0xFF2563EB),
                    ),
                  ],

                  if (selectedCategory != null &&
                      categoryCheckpointMapUrl(
                        selectedCategory!,
                      ).isNotEmpty) ...[
                    const SizedBox(height: 12),
                    CategoryCheckpointMap(
                      imageUrl: categoryCheckpointMapUrl(selectedCategory!),
                    ),
                  ],

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: size,
                    decoration: const InputDecoration(
                      labelText: "Shirt Size",
                      prefixIcon: Icon(Icons.checkroom),
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "XS", child: Text("XS")),
                      DropdownMenuItem(value: "S", child: Text("S")),
                      DropdownMenuItem(value: "M", child: Text("M")),
                      DropdownMenuItem(value: "L", child: Text("L")),
                      DropdownMenuItem(value: "XL", child: Text("XL")),
                      DropdownMenuItem(value: "2XL", child: Text("2XL")),
                      DropdownMenuItem(value: "3XL", child: Text("3XL")),
                    ],
                    onChanged: (value) {
                      setState(() {
                        size = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  HealthConditionsSelector(
                    controller: medicalConditionsController,
                    enabled: !isSubmitting,
                    title: "Health notes for this event",
                  ),
                  if (selectedCategoryRequiresMedicalCertificate) ...[
                    const SizedBox(height: 12),
                    _MedicalCertificatePicker(
                      fileName: medicalCertificateFile?.name,
                      onPick: isSubmitting ? null : pickMedicalCertificate,
                    ),
                  ],
                  if (selectedCategoryRequiresPayment) ...[
                    const SizedBox(height: 12),
                    _PaymentNotice(
                      amount: moneyLabel(selectedCategory),
                      provider: paymentOptions
                          .map(
                            (option) =>
                                paymentProviderLabel(option["provider"]),
                          )
                          .join(", "),
                    ),
                  ],
                ],
              ],

              if (step == 1) ...[
                _WaiverAgreementSection(
                  accepted: acceptedWaiver,
                  firstAidConfirmed: firstAidKitConfirmed,
                  onChanged: (value) {
                    setState(() => acceptedWaiver = value ?? false);
                  },
                  onFirstAidChanged: (value) {
                    setState(() => firstAidKitConfirmed = value ?? false);
                  },
                ),
              ],

              if (step == 2) ...[
                _PaymentProofSection(
                  amount: moneyLabel(selectedCategory),
                  options: paymentOptions,
                  selectedProvider: selectedPaymentOption?["provider"]
                      ?.toString(),
                  onProviderChanged: isSubmitting
                      ? null
                      : (provider) {
                          setState(() => selectedPaymentProvider = provider);
                        },
                  referenceController: paymentReferenceController,
                  notesController: paymentNotesController,
                  proofImageName: paymentProofImage?.name,
                  onPickProof: isSubmitting ? null : pickPaymentProof,
                ),
              ],

              const SizedBox(height: 20),

              LayoutBuilder(
                builder: (context, constraints) {
                  final shouldStackActions = constraints.maxWidth < 320;
                  final backButton = step > 0
                      ? OutlinedButton(
                          onPressed: isSubmitting
                              ? null
                              : () {
                                  if (step == 2) {
                                    Navigator.pop(context, true);
                                    return;
                                  }

                                  setState(() {
                                    step--;
                                  });
                                },
                          child: Text(step == 2 ? "Pay Later" : "Back"),
                        )
                      : null;
                  final primaryButton = FilledButton(
                    onPressed: isSubmitting || !canContinue || !canSubmit
                        ? null
                        : () {
                            if (step == 0) {
                              final category = categoryById(selectedCategoryId);
                              if (category == null ||
                                  !categoryCanRegister(category)) {
                                showMessage(
                                  "Please choose an available compatible category.",
                                );
                                return;
                              }

                              setState(() {
                                step++;
                              });
                            } else if (step == 1) {
                              submitRegistration();
                            } else if (selectedPaymentIsPayMongo) {
                              startPayMongoCheckout();
                            } else {
                              submitPaymentProof();
                            }
                          },
                    child: Text(
                      isSubmitting
                          ? "Submitting..."
                          : step == 2 && selectedPaymentIsPayMongo
                          ? "Open PayMongo Checkout"
                          : submitLabel,
                    ),
                  );

                  if (shouldStackActions) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (backButton != null) ...[
                          backButton,
                          const SizedBox(height: 10),
                        ],
                        primaryButton,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      if (backButton != null) ...[
                        Expanded(child: backButton),
                        const SizedBox(width: 10),
                      ],
                      Expanded(child: primaryButton),
                    ],
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

class _RegistrationStepIndicator extends StatelessWidget {
  final int step;

  const _RegistrationStepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _RegistrationStepPill(
            label: "Details",
            active: step == 0,
            complete: step > 0,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RegistrationStepPill(
            label: "Waiver",
            active: step == 1,
            complete: step > 1,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _RegistrationStepPill(
            label: "Payment",
            active: step == 2,
            complete: false,
          ),
        ),
      ],
    );
  }
}

class _RegistrationStepPill extends StatelessWidget {
  final String label;
  final bool active;
  final bool complete;

  const _RegistrationStepPill({
    required this.label,
    required this.active,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final color = complete || active
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: complete || active ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: color.withValues(alpha: complete || active ? 0.22 : 0.12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            complete ? Icons.check_circle : Icons.circle_outlined,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 6),
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

class _RegistrationEventSummary extends StatelessWidget {
  final String title;
  final String date;
  final String time;
  final String venue;

  const _RegistrationEventSummary({
    required this.title,
    required this.date,
    required this.time,
    required this.venue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _RegistrationMiniChip(
                icon: Icons.calendar_month_outlined,
                label: date,
              ),
              _RegistrationMiniChip(icon: Icons.schedule_outlined, label: time),
              if (venue.trim().isNotEmpty)
                _RegistrationMiniChip(
                  icon: Icons.location_on_outlined,
                  label: venue,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegistrationMiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RegistrationMiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF2563EB), size: 14),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2563EB),
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

class _WaiverAgreementSection extends StatelessWidget {
  final bool accepted;
  final bool firstAidConfirmed;
  final ValueChanged<bool?> onChanged;
  final ValueChanged<bool?> onFirstAidChanged;

  const _WaiverAgreementSection({
    required this.accepted,
    required this.firstAidConfirmed,
    required this.onChanged,
    required this.onFirstAidChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Text(
              "I hereby declare that I am physically and medically fit to participate in this event. "
              "I fully understand and acknowledge the risks involved, including possible injury or accident. "
              "I voluntarily agree to assume all such risks and release the organizers, sponsors, and affiliated parties from any and all liability arising from my participation.",
              style: TextStyle(
                color: Color(0xFF334155),
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        CheckboxListTile(
          value: accepted,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "I have read and agree to the waiver",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: onChanged,
        ),
        CheckboxListTile(
          value: firstAidConfirmed,
          contentPadding: EdgeInsets.zero,
          title: const Text(
            "I confirm that I will bring my own personal first aid kit",
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: const Text(
            "This is mandatory for all participants.",
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: onFirstAidChanged,
        ),
        if (!accepted)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              "Accept the waiver to submit your registration.",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        if (!firstAidConfirmed)
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 4),
            child: Text(
              "Confirm your personal first aid kit to submit your registration.",
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

class _MedicalCertificatePicker extends StatelessWidget {
  final String? fileName;
  final VoidCallback? onPick;

  const _MedicalCertificatePicker({
    required this.fileName,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final hasFile = fileName != null && fileName!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasFile
                    ? Icons.verified_user_outlined
                    : Icons.medical_information_outlined,
                color: hasFile
                    ? const Color(0xFF16A34A)
                    : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Medical certificate required",
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasFile
                          ? fileName!
                          : "Required for 50km and above. Upload JPG, PNG, WEBP, or PDF.",
                      maxLines: hasFile ? 1 : 3,
                      overflow: hasFile ? TextOverflow.ellipsis : null,
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(hasFile ? "Change Certificate" : "Upload Certificate"),
          ),
        ],
      ),
    );
  }
}

class _PaymentNotice extends StatelessWidget {
  final String amount;
  final String provider;

  const _PaymentNotice({required this.amount, required this.provider});

  @override
  Widget build(BuildContext context) {
    return _EventNotice(
      icon: Icons.payments_outlined,
      message: provider.trim().isEmpty
          ? "This category requires payment of $amount after registration."
          : "This category requires payment of $amount via $provider after registration.",
      color: const Color(0xFF2563EB),
    );
  }
}

class _PaymentProofSection extends StatelessWidget {
  final String amount;
  final List<Map<String, dynamic>> options;
  final String? selectedProvider;
  final ValueChanged<String?>? onProviderChanged;
  final TextEditingController referenceController;
  final TextEditingController notesController;
  final String? proofImageName;
  final VoidCallback? onPickProof;

  const _PaymentProofSection({
    required this.amount,
    required this.options,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.referenceController,
    required this.notesController,
    required this.proofImageName,
    required this.onPickProof,
  });

  @override
  Widget build(BuildContext context) {
    final option = paymentOptionByProvider(options, selectedProvider);
    final provider = paymentProviderLabel(option?["provider"]);
    final accountName = (option?["account_name"] ?? "").toString();
    final accountNumber = (option?["account_number"] ?? "").toString();
    final instructionText = (option?["instructions"] ?? "").toString();
    final isPayMongo = isPayMongoOption(option);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (options.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: option?["provider"]?.toString(),
            decoration: const InputDecoration(
              labelText: "Payment method",
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(),
            ),
            items: options.map((paymentOption) {
              final value = paymentOption["provider"].toString();
              return DropdownMenuItem(
                value: value,
                child: Text(paymentProviderLabel(value)),
              );
            }).toList(),
            onChanged: onProviderChanged,
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Payment Instructions",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              _PaymentInstructionRow(label: "Amount", value: amount),
              _PaymentInstructionRow(label: "Method", value: provider),
              if (accountName.isNotEmpty)
                _PaymentInstructionRow(label: "Account", value: accountName),
              if (accountNumber.isNotEmpty)
                _PaymentInstructionRow(label: "Number", value: accountNumber),
              if (instructionText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  instructionText,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isPayMongo) ...[
          const SizedBox(height: 14),
          const Text(
            "Continue with the checkout button below. Payment proof is not required for PayMongo.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ] else ...[
          const SizedBox(height: 14),
          TextField(
            controller: referenceController,
            decoration: const InputDecoration(
              labelText: "Payment reference",
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPickProof,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(
              proofImageName == null ? "Upload proof image" : proofImageName!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: "Notes (optional)",
              prefixIcon: Icon(Icons.notes_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Your payment will be reviewed by the admin before approval.",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentInstructionRow extends StatelessWidget {
  final String label;
  final String value;

  const _PaymentInstructionRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistrationSuccessDialog extends StatelessWidget {
  final String eventTitle;
  final String message;

  const _RegistrationSuccessDialog({
    required this.eventTitle,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.check_circle_outline,
        color: Color(0xFF16A34A),
        size: 42,
      ),
      title: const Text("Registration submitted"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            eventTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Done"),
        ),
      ],
    );
  }
}
