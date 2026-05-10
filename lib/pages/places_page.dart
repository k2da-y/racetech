import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../profile/badges_page.dart';
import 'user_profile_page.dart';
import '../profile/training_module_page.dart';
import '../profile/create_post.dart';
import 'search_page.dart';
import 'profile_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/notification_dialog.dart';

class PlacesPage extends StatefulWidget {
  const PlacesPage({super.key});

  @override
  State<PlacesPage> createState() => _PlacesPageState();
}

class _PlacesPageState extends State<PlacesPage> {
  List<String> userActivities = [];
  List<Map<String, dynamic>> filteredEvents = [];
  List<Map<String, dynamic>> apiEvents = [];
  List<Map<String, dynamic>> posts = [];
  bool isLoadingEvents = true;
  bool isLoadingPosts = true;
  int unreadNotificationCount = 0;
  String? createPostError;
  StreamSubscription<RemoteMessage>? notificationSubscription;

  Future<void> loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList("activities") ?? [];
    final eventsFromApi = await ApiService().getEvents();
    final normalizedEvents = eventsFromApi.map(normalizeApiEvent).toList();
    final matchedEvents = activities.isEmpty
        ? normalizedEvents
        : normalizedEvents.where((event) {
            final tags = (event["tags"] as List?) ?? [];
            return tags.any((tag) => activities.contains(tag));
          }).toList();

    if (!mounted) return;

    setState(() {
      userActivities = activities;
      apiEvents = normalizedEvents;
      filteredEvents = matchedEvents.isEmpty ? normalizedEvents : matchedEvents;
      isLoadingEvents = false;
    });
  }

  Map<String, dynamic> normalizeApiEvent(Map<String, dynamic> event) {
    final categories = ((event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
    final interest = (event["interest_type"] ?? "").toString();

    return {
      "id": event["id"],
      "event": interest.isEmpty ? "Race Event" : interest,
      "title": event["title"] ?? "Untitled Event",
      "participants": event["participants_count"] ?? 0,
      "date": event["event_date"] ?? "TBA",
      "time": event["start_time"] ?? "TBA",
      "image": "assets/map.jpg",
      "banner_url": event["banner_url"],
      "venue": event["venue"] ?? "",
      "status": event["status"] ?? "",
      "is_registered": event["is_registered"] == true,
      "registration_status": event["registration_status"],
      "registered_category_id": event["registered_category_id"],
      "description": event["description"] ?? "",
      "tags": [
        if (interest.isNotEmpty) interest,
        ...categories.map((category) => (category["name"] ?? "").toString()),
      ],
      "categories": categories,
      "from_api": true,
    };
  }

  String eventActionLabel(Map<String, dynamic> event) {
    if (event["is_registered"] == true) {
      final status = (event["registration_status"] ?? "registered").toString();

      return switch (status) {
        "pending" => "Pending",
        "approved" => "Approved",
        "checked_in" => "Checked In",
        "completed" => "Completed",
        _ => "Registered",
      };
    }

    return event["status"] == "upcoming" ? "Join Event" : "Unavailable";
  }

  bool canJoinEvent(Map<String, dynamic> event) {
    return event["is_registered"] != true && event["status"] == "upcoming";
  }

  @override
  void initState() {
    super.initState();
    loadUserPreferences();
    loadCommunityPosts();
    loadUnreadNotificationCount();
    listenForForegroundNotifications();
  }

  @override
  void dispose() {
    notificationSubscription?.cancel();
    super.dispose();
  }

  void listenForForegroundNotifications() {
    notificationSubscription = FirebaseMessaging.onMessage.listen((message) {
      loadUnreadNotificationCount();

      final title = message.notification?.title ?? message.data["title"];
      final body = message.notification?.body ?? message.data["body"];
      final text = [title, body]
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .join("\n");

      if (!mounted || text.isEmpty) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(text),
          action: SnackBarAction(
            label: "View",
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (_) => const NotificationDialog(),
              );
              await loadUnreadNotificationCount();
            },
          ),
        ),
      );
    });
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text("Complete Your Profile"),
          content: const Text(
            "Please add your phone, address, birthdate, and emergency contact before joining an event.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Later"),
            ),
            ElevatedButton(
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
      builder: (_) => RegisterDialog(event: event),
    );

    if (!mounted || registered != true) return;

    setState(() => isLoadingEvents = true);
    await loadUserPreferences();
    await loadUnreadNotificationCount();
  }

  Map<String, dynamic> normalizeCommunityPost(Map<String, dynamic> post) {
    final user = Map<String, dynamic>.from(post["user"] ?? {});
    final title = (post["title"] ?? "").toString().trim();
    final content = (post["content"] ?? "").toString().trim();

    return {
      "name": (user["name"] ?? "Runner").toString(),
      "title": title,
      "content": content,
      "image_url": (post["image_url"] ?? "").toString(),
      "comments_count": ((post["comments"] as List?) ?? []).length,
      "likes_count": int.tryParse((post["likes_count"] ?? 0).toString()) ?? 0,
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

  Future<bool> addPost(String title, String content) async {
    createPostError = null;

    final result = await ApiService().createCommunityPost(
      title: title,
      content: content,
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

  //TRACK CURRENT CAROUSEL INDEX
  int currentIndex = 0;

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Conquer",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
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
                    if (isLoadingEvents)
                      const SizedBox(
                        height: 250,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (filteredEvents.isEmpty)
                      const SizedBox(
                        height: 250,
                        child: Center(child: Text("No events available")),
                      )
                    else
                      SizedBox(
                        height: 250,
                        child: PageView.builder(
                          itemCount: filteredEvents.length,
                          controller: PageController(viewportFraction: 0.9),

                          //UPDATE CURRENT INDEX (for dots)
                          onPageChanged: (index) {
                            setState(() {
                              currentIndex = index;
                            });
                          },

                          itemBuilder: (context, index) {
                            final event = filteredEvents[index];
                            final canJoin = canJoinEvent(event);
                            final actionLabel = eventActionLabel(event);

                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),

                              //CARD DESIGN
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                image: DecorationImage(
                                  image:
                                      (event["banner_url"] ?? "")
                                          .toString()
                                          .isNotEmpty
                                      ? NetworkImage(event["banner_url"])
                                      : AssetImage(event["image"]),
                                  fit: BoxFit.cover,
                                ),
                              ),

                              //DARK OVERLAY
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  color: Colors.black.withValues(alpha: 0.4),
                                ),

                                //EVENT DETAILS INSIDE CARD
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
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
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),

                                    const SizedBox(height: 8),

                                    //PARTICIPANTS
                                    Text(
                                      "Participants: ${event["participants"]}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),

                                    //DATE + TIME
                                    Text(
                                      "${event["date"]} • ${event["time"]}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),

                                    const SizedBox(height: 10),

                                    //JOIN BUTTON
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: canJoin
                                            ? () => handleJoinEvent(event)
                                            : null,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: canJoin
                                              ? Colors.pink
                                              : Colors.grey,
                                          disabledBackgroundColor: Colors.grey,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          actionLabel,
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
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
                      children: List.generate(filteredEvents.length, (index) {
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentIndex == index ? 12 : 8,
                          height: currentIndex == index ? 12 : 8,
                          decoration: BoxDecoration(
                            color: currentIndex == index
                                ? Colors.pink
                                : Colors.grey,
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
                child: isLoadingPosts
                    ? const Center(child: CircularProgressIndicator())
                    : posts.isEmpty
                    ? const Center(child: Text("No community posts yet"))
                    : RefreshIndicator(
                        onRefresh: () async {
                          setState(() => isLoadingPosts = true);
                          await loadCommunityPosts();
                        },
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: posts.length,
                          itemBuilder: (context, index) {
                            final post = posts[index];
                            final title = (post["title"] ?? "").toString();
                            final content = (post["content"] ?? "").toString();
                            final imageUrl = (post["image_url"] ?? "")
                                .toString();

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(15),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: [
                                    BoxShadow(
                                      blurRadius: 8,
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
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
                                        Expanded(
                                          child: Text(
                                            (post["name"] ?? "Runner")
                                                .toString(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (title.isNotEmpty) ...[
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      content,
                                      maxLines: imageUrl.isEmpty ? 3 : 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (imageUrl.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.network(
                                          imageUrl,
                                          height: 90,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  const SizedBox.shrink(),
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    Text(
                                      "${post["likes_count"]} likes - ${post["comments_count"]} comments",
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
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
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
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
                    MaterialPageRoute(
                      builder: (_) => const TrainingModulePage(),
                    ),
                  );
                },
              ),

              //SEARCH PAGE
              IconButton(
                icon: const Icon(Icons.search_outlined, color: Colors.grey),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchPage()),
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
                    builder: (_) => CreatePostSheet(
                      onPost: addPost,
                      errorMessage: () =>
                          createPostError ?? "Unable to create post.",
                    ),
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
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none, color: Colors.grey),
                    if (unreadNotificationCount > 0)
                      Positioned(
                        right: -7,
                        top: -7,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadNotificationCount > 9
                                ? "9+"
                                : unreadNotificationCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () async {
                  await showDialog(
                    context: context,
                    builder: (_) => const NotificationDialog(),
                  );
                  await loadUnreadNotificationCount();
                },
              ),

              //BADGES SA NAVIGATION
              IconButton(
                icon: const Icon(
                  Icons.emoji_events_outlined,
                  color: Colors.grey,
                ),
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
  final Map<String, dynamic> event;

  const RegisterDialog({super.key, required this.event});

  @override
  State<RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<RegisterDialog> {
  int step = 0;
  String size = "M";
  bool acceptedWaiver = false;
  bool isSubmitting = false;
  int? selectedCategoryId;

  final medicalConditionsController = TextEditingController();

  List<Map<String, dynamic>> get categories {
    return ((widget.event["categories"] as List?) ?? [])
        .whereType<Map>()
        .map((category) => Map<String, dynamic>.from(category))
        .toList();
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

  @override
  void initState() {
    super.initState();
    final openCategories = categories
        .where((category) => category["status"] == "open")
        .toList();
    if (openCategories.isNotEmpty) {
      selectedCategoryId = int.tryParse(
        (openCategories.first["id"] ?? "").toString(),
      );
    }
  }

  @override
  void dispose() {
    medicalConditionsController.dispose();
    super.dispose();
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

    setState(() => isSubmitting = true);

    final result = await ApiService().registerForEvent(
      eventId: int.parse(eventId.toString()),
      categoryId: categoryId,
      shirtSize: size,
      medicalConditions: medicalConditionsController.text.trim(),
    );

    if (!mounted) return;

    setState(() => isSubmitting = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Success"),
        content: Text(result.message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final openCategories = categories
        .where((category) => category["status"] == "open")
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Register (${step + 1}/2)",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            if (step == 0) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  widget.event["title"].toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: selectedCategoryId,
                decoration: InputDecoration(
                  hintText: "Category",
                  prefixIcon: const Icon(Icons.flag_outlined),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: openCategories.map((category) {
                  final distance = category["distance_km"];
                  final slots = category["slots_remaining"];
                  final label = [
                    category["name"],
                    if (distance != null) "${distance}km",
                    if (slots != null) "$slots slots left",
                  ].join(" • ");

                  return DropdownMenuItem(
                    value: int.tryParse((category["id"] ?? "").toString()),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  );
                }).toList(),
                onChanged: openCategories.isEmpty
                    ? null
                    : (value) {
                        setState(() => selectedCategoryId = value);
                      },
              ),

              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: size,
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

              TextField(
                controller: medicalConditionsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Medical conditions (optional)",
                  prefixIcon: const Icon(Icons.medical_information_outlined),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
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
                      onPressed: isSubmitting
                          ? null
                          : () {
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
                    onPressed: isSubmitting
                        ? null
                        : () {
                            if (step < 1) {
                              if (categoryById(selectedCategoryId) == null) {
                                showMessage("Please choose an open category.");
                                return;
                              }

                              setState(() {
                                step++;
                              });
                            } else {
                              submitRegistration();
                            }
                          },
                    child: Text(
                      isSubmitting
                          ? "Submitting..."
                          : step < 1
                          ? "Next"
                          : "Submit",
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
