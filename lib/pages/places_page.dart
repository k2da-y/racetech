import 'package:flutter/material.dart';
import '../utils/registration_group.dart';
import '../widgets/registration_group_page.dart';
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

// ---------------------------------------------------------------------------
// Brand palette (soft indigo — matches the Racetech admin and landing page).
// Change these few values to re-theme the whole page.
// ---------------------------------------------------------------------------
const Color _brandPrimary = Color(0xFF6366F1); // indigo-500
const Color _brandDeep = Color(0xFF4F46E5); // indigo-600
const Color _brandAccent = Color(0xFF0EA5E9); // sky-500
const Color _brandSoft = Color(0xFFEEF2FF); // indigo-50
const Color _ink = Color(0xFF1E293B); // slate-800
const Color _body = Color(0xFF475569); // slate-600
const Color _muted = Color(0xFF64748B); // slate-500
const Color _faint = Color(0xFF94A3B8); // slate-400
const Color _border = Color(0xFFE2E8F0); // slate-200
const Color _background = Color(0xFFF5F7FB);
const Color _surfaceAlt = Color(0xFFF8FAFC); // slate-50
const Color _success = Color(0xFF16A34A);
const Color _like = Color(0xFFE11D48);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const OutlineInputBorder _roundedField = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(14)),
);

/// Brand theme for dialogs and sheets so buttons, checkboxes and focus colors
/// follow the indigo palette regardless of the app-wide theme.
ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));

  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _brandPrimary,
      onPrimary: Colors.white,
      secondary: _brandAccent,
      secondaryContainer: _brandSoft,
      onSecondaryContainer: _brandDeep,
      surfaceTint: Colors.transparent,
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

String _shortDate(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return "";

  const months = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
  ];
  final local = parsed.toLocal();
  return "${months[local.month - 1]} ${local.day}";
}

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

  /// Bumped whenever the event list is reloaded so the carousel starts fresh
  /// at page 1 (keeps the dots and the visible card in sync).
  int carouselGeneration = 0;

  final eventsSectionKey = GlobalKey();

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
      carouselGeneration++;
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

  void scrollToEvents() {
    final sectionContext = eventsSectionKey.currentContext;
    if (sectionContext == null) return;

    Scrollable.ensureVisible(
      sectionContext,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Future<void> handleJoinEvent(Map<String, dynamic> event) async {
    final apiService = ApiService();
    final user = await apiService.getUser();

    if (!mounted) return;

    if (!apiService.profileIsComplete(user)) {
      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        builder: (context) => Theme(
          data: _brandTheme(context),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            icon: const _DialogIcon(icon: Icons.account_circle_outlined),
            title: const Text(
              "Complete Your Profile",
              style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
            content: const Text(
              "Please add your phone, address, birthdate, and emergency contact before joining an event.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _body, height: 1.4),
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
          availabilityMessage: eventAvailabilityMessage(event),
          onJoin: () async {
            Navigator.pop(sheetContext);
            await handleJoinEvent(event);
          },
        ),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => Theme(
        data: _brandTheme(sheetContext),
        child: CreatePostSheet(
          onPost: addPost,
          errorMessage: () => createPostError ?? "Unable to create post.",
        ),
      ),
    );
  }

  Future<void> openNotifications() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Theme(
        data: _brandTheme(dialogContext),
        child: const NotificationDialog(),
      ),
    );

    await loadUnreadNotificationCount();
  }

  Future<void> refreshAll() async {
    setState(() {
      isLoadingEvents = true;
      isLoadingAnnouncements = true;
      isLoadingPosts = true;
    });

    // Independent requests — load them in parallel instead of one by one.
    await Future.wait([
      loadUserPreferences(),
      loadAnnouncements(),
      loadCommunityPosts(),
      loadUnreadNotificationCount(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: RefreshIndicator(
        color: _brandPrimary,
        onRefresh: refreshAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeHeader(
                unreadNotificationCount: unreadNotificationCount,
                onNotificationTap: openNotifications,
                onExploreTap: scrollToEvents,
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                key: eventsSectionKey,
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: _SectionTitle(
                  title: "Upcoming Events",
                  subtitle: userActivities.isEmpty
                      ? "Discover available events for your next challenge"
                      : "Recommended from your interests",
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            SliverToBoxAdapter(
              child: _EventCarousel(
                key: ValueKey("carousel-$carouselGeneration"),
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

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _SectionTitle(
                  title: "Announcements",
                  subtitle: "Latest updates from organizers",
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            if (isLoadingAnnouncements)
              const SliverToBoxAdapter(child: _AnnouncementSkeletonList())
            else if (announcements.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
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
                  height: 196,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
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

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _SectionTitle(
                  title: "Community",
                  subtitle: "Latest public posts",
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: _brandPrimary,
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: openCommunityPage,
                        child: const Text("View all"),
                      ),
                      const SizedBox(width: 2),
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: _brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: openCreatePostSheet,
                        icon: const Icon(Icons.add_rounded),
                        tooltip: "Create post",
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            if (isLoadingPosts)
              const SliverToBoxAdapter(child: _CommunitySkeletonList())
            else if (posts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _EmptyCard(
                    icon: Icons.forum_outlined,
                    title: "No community posts yet",
                    message: "Be the first one to share something.",
                    actionLabel: "Create a post",
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
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
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
      bottomNavigationBar: const AppBottomNavBar(currentPage: AppNavPage.home),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _HomeHeader extends StatelessWidget {
  final int unreadNotificationCount;
  final VoidCallback onNotificationTap;
  final VoidCallback onExploreTap;

  const _HomeHeader({
    required this.unreadNotificationCount,
    required this.onNotificationTap,
    required this.onExploreTap,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandDeep, _brandPrimary, _brandAccent],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                "RACETECH",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.8,
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: unreadNotificationCount > 0
                    ? "Notifications, $unreadNotificationCount unread"
                    : "Notifications",
                child: Badge(
                  isLabelVisible: unreadNotificationCount > 0,
                  backgroundColor: Colors.white,
                  textColor: _brandDeep,
                  label: Text(
                    unreadNotificationCount > 9
                        ? "9+"
                        : unreadNotificationCount.toString(),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(15),
                    child: InkWell(
                      onTap: onNotificationTap,
                      borderRadius: BorderRadius.circular(15),
                      child: const SizedBox(
                        height: 46,
                        width: 46,
                        child: Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 20, 16, 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text(
                          "YOUR NEXT RACE",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "TRAIN. COMPETE.\nCONQUER.",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Discover your next event and keep moving forward.",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onExploreTap,
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Explore Events",
                                  style: TextStyle(
                                    color: _brandDeep,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.arrow_downward_rounded,
                                  color: _brandDeep,
                                  size: 15,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: AspectRatio(
                    aspectRatio: 0.9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          FractionallySizedBox(
                            widthFactor: 0.82,
                            heightFactor: 0.82,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                          ),
                          const FittedBox(
                            child: Padding(
                              padding: EdgeInsets.all(18),
                              child: Icon(
                                Icons.directions_run_rounded,
                                color: Colors.white,
                                size: 76,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      crossAxisAlignment: CrossAxisAlignment.end,
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
                  color: _ink,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
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

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

class _EventCarousel extends StatefulWidget {
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
    super.key,
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
  State<_EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<_EventCarousel> {
  // Owned here (not created in build) so it is reused across rebuilds and
  // disposed properly.
  final PageController controller = PageController(viewportFraction: 0.88);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: _SkeletonPulse(child: _EventCardSkeleton()),
      );
    }

    if (widget.events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: _EmptyCard(
          icon: Icons.event_busy_outlined,
          title: "No events available",
          message: "Please check again later for upcoming events.",
        ),
      );
    }

    final total = widget.events.length;
    final current = widget.currentIndex.clamp(0, total - 1);

    return Column(
      children: [
        SizedBox(
          height: 360,
          child: PageView.builder(
            itemCount: total,
            controller: controller,
            clipBehavior: Clip.none,
            onPageChanged: widget.onPageChanged,
            itemBuilder: (context, index) {
              final event = widget.events[index];

              return _EventCard(
                event: event,
                canJoin: widget.canJoinEvent(event),
                actionLabel: widget.eventActionLabel(event),
                statusLabel: widget.eventStatusLabel(event),
                onOpenDetails: () => widget.onOpenDetails(event),
                onJoin: () => widget.onJoin(event),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (total > 1)
          total <= 8
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(total, (index) {
                    final selected = current == index;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: selected ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: selected
                            ? _brandPrimary
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    );
                  }),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _brandSoft,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    "${current + 1} / $total",
                    style: const TextStyle(
                      color: _brandDeep,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
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
    final venue = (event["venue"] ?? "").toString().trim();
    final eventType = (event["event"] ?? "").toString().trim();

    return Container(
      margin: const EdgeInsets.fromLTRB(6, 0, 6, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _brandDeep.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: const Color(0xFF0F172A),
          child: InkWell(
            onTap: onOpenDetails,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _EventBannerImage(
                  bannerUrl: (event["banner_url"] ?? "").toString(),
                  assetPath: (event["image"] ?? "").toString(),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.10),
                        Colors.black.withValues(alpha: 0.30),
                        const Color(0xFF0F172A).withValues(alpha: 0.92),
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
                          if (eventType.isNotEmpty) ...[
                            Flexible(
                              child: _EventBadge(
                                icon: Icons.local_activity_outlined,
                                label: eventType,
                                color: _brandPrimary,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          _EventBadge(
                            icon: canJoin
                                ? Icons.event_available_outlined
                                : Icons.verified_outlined,
                            label: statusLabel,
                            color: canJoin ? _success : _muted,
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        (event["title"] ?? "").toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (venue.isNotEmpty) ...[
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
                                venue,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
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
                            label: "${event["participants"] ?? 0} joined",
                          ),
                          _EventInfoChip(
                            icon: Icons.calendar_month_outlined,
                            label: (event["date"] ?? "").toString(),
                          ),
                          if ((event["time"] ?? "")
                              .toString()
                              .trim()
                              .isNotEmpty)
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
                            canJoin
                                ? Icons.arrow_forward_rounded
                                : Icons.lock_outline_rounded,
                            size: 19,
                          ),
                          label: Text(actionLabel),
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandPrimary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.white.withValues(
                              alpha: 0.16,
                            ),
                            disabledForegroundColor: Colors.white.withValues(
                              alpha: 0.75,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
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
        color: Colors.white.withValues(alpha: 0.94),
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
                color: _ink,
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
      height: 350,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: _softShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBlock(width: 120, height: 30, radius: 99),
              SizedBox(width: 8),
              _SkeletonBlock(width: 92, height: 30, radius: 99),
            ],
          ),
          Spacer(),
          _SkeletonBlock(width: double.infinity, height: 28),
          SizedBox(height: 8),
          _SkeletonBlock(width: 190, height: 28),
          SizedBox(height: 14),
          Row(
            children: [
              _SkeletonBlock(width: 92, height: 28, radius: 99),
              SizedBox(width: 8),
              _SkeletonBlock(width: 104, height: 28, radius: 99),
            ],
          ),
          SizedBox(height: 16),
          _SkeletonBlock(width: double.infinity, height: 50, radius: 16),
        ],
      ),
    );
  }
}

/// Gentle fade pulse for loading skeletons (one controller per skeleton group).
class _SkeletonPulse extends StatefulWidget {
  final Widget child;

  const _SkeletonPulse({required this.child});

  @override
  State<_SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<_SkeletonPulse>
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

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;

    return FadeTransition(opacity: opacity, child: widget.child);
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
        color: const Color(0xFFE8ECF4),
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
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const _EventImagePlaceholder();
        },
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
    if (assetPath.trim().isEmpty || assetPath == "null") {
      return const _EventImagePlaceholder();
    }

    return Image.asset(
      assetPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _EventImagePlaceholder(),
    );
  }
}

class _EventImagePlaceholder extends StatelessWidget {
  const _EventImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brandDeep, Color(0xFF0F172A)],
        ),
      ),
      child: Align(
        alignment: Alignment(0, -0.35),
        child: Icon(Icons.event_outlined, color: Colors.white24, size: 64),
      ),
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
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Announcements
// ---------------------------------------------------------------------------

class _AnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcement;
  final Future<void> Function(Map<String, dynamic> announcement)? onOpenEvent;

  const _AnnouncementCard({required this.announcement, this.onOpenEvent});

  @override
  Widget build(BuildContext context) {
    final title = (announcement["title"] ?? "").toString();
    final content = (announcement["content"] ?? "").toString();
    final eventTitle = (announcement["event_title"] ?? "").toString();
    final publishedLabel = _shortDate(
      (announcement["published_at"] ?? "").toString(),
    );
    final imageUrl = announcementImageUrl(announcement);

    return Container(
      width: 284,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
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
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 38,
                      width: 38,
                      decoration: BoxDecoration(
                        color: _brandSoft,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.campaign_outlined,
                        color: _brandPrimary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        eventTitle.isEmpty ? "General" : eventTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (publishedLabel.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        publishedLabel,
                        style: const TextStyle(
                          color: _faint,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
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
                                color: _ink,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                content,
                                maxLines: imageUrl.isEmpty ? 3 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
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
                const SizedBox(height: 6),
                const Row(
                  children: [
                    Text(
                      "Read more",
                      style: TextStyle(
                        color: _brandPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: _brandPrimary,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnnouncementSkeletonList extends StatelessWidget {
  const _AnnouncementSkeletonList();

  @override
  Widget build(BuildContext context) {
    return _SkeletonPulse(
      child: SizedBox(
        height: 196,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 2,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (context, index) => const _AnnouncementSkeletonCard(),
        ),
      ),
    );
  }
}

class _AnnouncementSkeletonCard extends StatelessWidget {
  const _AnnouncementSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 284,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBlock(width: 38, height: 38, radius: 13),
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
    final title = (announcement["title"] ?? "").toString();
    final content = (announcement["content"] ?? "").toString();
    final eventTitle = (announcement["event_title"] ?? "").toString();
    final publishedLabel = _shortDate(
      (announcement["published_at"] ?? "").toString(),
    );
    final imageUrl = announcementImageUrl(announcement);
    final actionEventId = (announcement["action_event_id"] ?? "")
        .toString()
        .trim();
    final actionLabel = (announcement["action_label"] ?? "View Event")
        .toString();

    return Theme(
      data: _brandTheme(context),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              22,
              12,
              22,
              MediaQuery.viewInsetsOf(context).bottom + 24,
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _brandSoft,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.campaign_outlined,
                            color: _brandPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 220),
                            child: Text(
                              eventTitle.isEmpty
                                  ? "General announcement"
                                  : eventTitle,
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
                    ),
                    const Spacer(),
                    if (publishedLabel.isNotEmpty)
                      Text(
                        publishedLabel,
                        style: const TextStyle(
                          color: _faint,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 14),
                if (imageUrl.isNotEmpty) ...[
                  AnnouncementImage(imageUrl: imageUrl),
                  const SizedBox(height: 16),
                ],
                SelectableText(
                  content,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (actionEventId.isNotEmpty && onOpenEvent != null) ...[
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onOpenEvent?.call(announcement);
                      },
                      icon: const Icon(Icons.event_available_outlined),
                      label: Text(actionLabel),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Community
// ---------------------------------------------------------------------------

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

    return Container(
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: _brandSoft,
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
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            "Community post",
                            style: TextStyle(
                              color: _faint,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _faint),
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
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                if (content.isNotEmpty)
                  Text(
                    content,
                    maxLines: hasMedia ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _body,
                      height: 1.4,
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
                const SizedBox(height: 10),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _PostAction(
                      icon: likedByMe
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      label: "${post["likes_count"]}",
                      color: likedByMe ? _like : _muted,
                      tooltip: likedByMe ? "Unlike" : "Like",
                      onTap: onLike,
                    ),
                    const SizedBox(width: 8),
                    _PostAction(
                      icon: Icons.mode_comment_outlined,
                      label: "${post["comments_count"]}",
                      color: _muted,
                      tooltip: "Comments",
                      onTap: onOpenComments,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(icon, key: ValueKey(icon), size: 19, color: color),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
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
    return const _SkeletonPulse(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _CommunitySkeletonCard(),
            SizedBox(height: 14),
            _CommunitySkeletonCard(compact: true),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
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
      height: 170,
      width: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(height: 170, color: _surfaceAlt);
      },
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
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _brandSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: _brandPrimary, size: 44),
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
          color: _brandPrimary,
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
  final String? actionLabel;
  final VoidCallback? onTap;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: _brandSoft,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(icon, size: 30, color: _brandPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  if (onTap != null && actionLabel != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _brandPrimary,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        actionLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _DialogIcon({
    super.key,
    required this.icon,
    this.color = _brandPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      width: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(icon, color: color, size: 30),
    );
  }
}

// ---------------------------------------------------------------------------
// REGISTRATION DIALOG SA JOIN EVENT BUTTON
// ---------------------------------------------------------------------------

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
  String groupAction = 'create';
  final groupNameController = TextEditingController();
  final invitationCodeController = TextEditingController();
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
    final distance = categoryDistanceLabel(category);
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
      if (distance.isNotEmpty) distance,
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
    groupNameController.dispose();
    invitationCodeController.dispose();
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
    if (isGroupCategory(selectedCategory) &&
        (groupAction == 'create'
                ? groupNameController.text
                : invitationCodeController.text)
            .trim()
            .isEmpty) {
      showMessage(
        groupAction == 'create'
            ? 'Enter a group name.'
            : 'Enter an invitation code.',
      );
      return;
    }
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
      groupAction: isGroupCategory(selectedCategory) ? groupAction : null,
      groupName: groupNameController.text,
      invitationCode: invitationCodeController.text,
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() => isSubmitting = false);
      showMessage(result.message);
      return;
    }

    final registration = result.data ?? <String, dynamic>{};
    final code = registration.remove('invitation_code')?.toString() ?? '';
    invitationCodeController.clear();
    if (code.isNotEmpty) await showInvitationCode(context, code);
    if (!mounted) return;
    if (!groupAllowsPayment(registration)) {
      await showDialog<void>(
        context: context,
        builder: (context) => Theme(
          data: _brandTheme(context),
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            icon: const _DialogIcon(icon: Icons.groups_2_outlined),
            title: const Text(
              'Group registration created',
              style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
            content: Text(
              '${groupPaymentReason(registration)} View and manage your group in My Activity.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _body, height: 1.4),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }
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
    if (!await checkGroupPayment(context, createdRegistration) || !mounted) {
      return;
    }
    if (!groupAllowsPayment(createdRegistration)) {
      showMessage(groupPaymentReason(createdRegistration));
      return;
    }
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
    if (!await checkGroupPayment(context, createdRegistration) || !mounted) {
      return;
    }
    if (!groupAllowsPayment(createdRegistration)) {
      showMessage(groupPaymentReason(createdRegistration));
      return;
    }
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
    final stepTitle = switch (step) {
      0 => "Registration Details",
      1 => "Waiver & Safety",
      _ => "Payment",
    };
    final stepIcon = switch (step) {
      0 => Icons.app_registration_rounded,
      1 => Icons.verified_user_outlined,
      _ => Icons.payments_outlined,
    };

    return Theme(
      data: _brandTheme(context),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: maxDialogHeight,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _DialogIcon(key: ValueKey(step), icon: stepIcon),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "STEP ${step + 1} OF 3",
                            style: const TextStyle(
                              color: _brandPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            stepTitle,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
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
                      color: _muted,
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (categories.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      itemHeight: null,
                      initialValue: selectedCategoryId,
                      borderRadius: BorderRadius.circular(16),
                      decoration: InputDecoration(
                        labelText: categoryLabel,
                        prefixIcon: const Icon(Icons.flag_outlined),
                        border: _roundedField,
                      ),
                      items: categories.map((category) {
                        final enabled = categoryCanRegister(category);
                        return DropdownMenuItem(
                          value: int.tryParse(
                            (category["id"] ?? "").toString(),
                          ),
                          enabled: enabled,
                          child: Text(
                            categoryOptionLabel(category),
                            maxLines: 7,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: enabled ? null : _muted),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategoryId = value;
                          groupNameController.clear();
                          invitationCodeController.clear();
                          groupAction = 'create';
                          selectedPaymentProvider = null;
                        });
                      },
                    ),

                    if (isGroupCategory(selectedCategory)) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'create',
                              icon: Icon(Icons.group_add_outlined),
                              label: Text('Create Group'),
                            ),
                            ButtonSegment(
                              value: 'join',
                              icon: Icon(Icons.login_rounded),
                              label: Text('Join Group'),
                            ),
                          ],
                          selected: {groupAction},
                          onSelectionChanged: (value) =>
                              setState(() => groupAction = value.single),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: groupAction == 'create'
                            ? groupNameController
                            : invitationCodeController,
                        decoration: InputDecoration(
                          labelText: groupAction == 'create'
                              ? 'Group name'
                              : 'Invitation code',
                          prefixIcon: Icon(
                            groupAction == 'create'
                                ? Icons.badge_outlined
                                : Icons.key_outlined,
                          ),
                          border: _roundedField,
                        ),
                      ),
                    ],
                    if (selectedCategory != null &&
                        categoryQualificationNotes(
                          selectedCategory!,
                        ).isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _EventNotice(
                        icon: Icons.fact_check_outlined,
                        message:
                            "Qualification notes\n${categoryQualificationNotes(selectedCategory!)}",
                        color: _brandDeep,
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
                      borderRadius: BorderRadius.circular(16),
                      decoration: const InputDecoration(
                        labelText: "Shirt Size",
                        prefixIcon: Icon(Icons.checkroom),
                        border: _roundedField,
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

                const SizedBox(height: 22),

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
                                final category = categoryById(
                                  selectedCategoryId,
                                );
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
                      child: isSubmitting
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text("Submitting..."),
                              ],
                            )
                          : Text(
                              step == 2 && selectedPaymentIsPayMongo
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
    final highlighted = complete || active;
    final foreground = active
        ? Colors.white
        : highlighted
        ? _brandDeep
        : _muted;
    final background = active
        ? _brandPrimary
        : highlighted
        ? _brandSoft
        : _surfaceAlt;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: highlighted ? Colors.transparent : _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: foreground,
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
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
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
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
              if (time.trim().isNotEmpty && time != "null")
                _RegistrationMiniChip(
                  icon: Icons.schedule_outlined,
                  label: time,
                ),
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
        color: _brandSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _brandPrimary, size: 14),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
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
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: const SingleChildScrollView(
            physics: BouncingScrollPhysics(),
            child: Text(
              "I hereby declare that I am physically and medically fit to participate in this event. "
              "I fully understand and acknowledge the risks involved, including possible injury or accident. "
              "I voluntarily agree to assume all such risks and release the organizers, sponsors, and affiliated parties from any and all liability arising from my participation.",
              style: TextStyle(
                color: Color(0xFF334155),
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AgreementTile(
          value: accepted,
          title: "I have read and agree to the waiver",
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
        _AgreementTile(
          value: firstAidConfirmed,
          title: "I confirm that I will bring my own personal first aid kit",
          subtitle: "This is mandatory for all participants.",
          onChanged: onFirstAidChanged,
        ),
        if (!accepted || !firstAidConfirmed) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 15, color: _faint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  !accepted && !firstAidConfirmed
                      ? "Check both boxes to submit your registration."
                      : !accepted
                      ? "Accept the waiver to submit your registration."
                      : "Confirm your personal first aid kit to submit your registration.",
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AgreementTile extends StatelessWidget {
  final bool value;
  final String title;
  final String? subtitle;
  final ValueChanged<bool?> onChanged;

  const _AgreementTile({
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: value ? _brandSoft : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value ? _brandPrimary.withValues(alpha: 0.35) : _border,
        ),
      ),
      child: CheckboxListTile(
        value: value,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        activeColor: _brandPrimary,
        title: Text(
          title,
          style: const TextStyle(
            color: _ink,
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: onChanged,
      ),
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
        color: hasFile ? _success.withValues(alpha: 0.06) : _surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasFile ? _success.withValues(alpha: 0.25) : _border,
        ),
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
                color: hasFile ? _success : _brandPrimary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Medical certificate required",
                      style: TextStyle(
                        color: _ink,
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
                        color: _body,
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
      color: _brandDeep,
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
            borderRadius: BorderRadius.circular(16),
            decoration: const InputDecoration(
              labelText: "Payment method",
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              border: _roundedField,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surfaceAlt,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      "Payment Instructions",
                      style: TextStyle(
                        color: _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: _brandPrimary,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                    color: _body,
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
          const _EventNotice(
            icon: Icons.lock_outline_rounded,
            message:
                "Continue with the checkout button below. Payment proof is not required for PayMongo.",
            color: _muted,
          ),
        ] else ...[
          const SizedBox(height: 14),
          TextField(
            controller: referenceController,
            decoration: const InputDecoration(
              labelText: "Payment reference",
              prefixIcon: Icon(Icons.confirmation_number_outlined),
              border: _roundedField,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onPickProof,
            icon: Icon(
              proofImageName == null
                  ? Icons.upload_file_outlined
                  : Icons.check_circle_outline_rounded,
            ),
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
              border: _roundedField,
            ),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 15, color: _faint),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Your payment will be reviewed by the admin before approval.",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
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
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: _ink, fontWeight: FontWeight.w900),
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
    return Theme(
      data: _brandTheme(context),
      child: AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const _DialogIcon(
          icon: Icons.check_circle_outline_rounded,
          color: _success,
        ),
        title: const Text(
          "Registration submitted",
          style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              eventTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, color: _ink),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _body, height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ),
        ],
      ),
    );
  }
}
