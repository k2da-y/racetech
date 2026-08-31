import 'package:flutter/material.dart';
import '../pages/places_page.dart';
import '../pages/search_page.dart';
import '../pages/user_profile_page.dart';
import '../profile/leaderboard_page.dart';
import '../profile/training_module_page.dart';

enum AppNavPage { home, training, leaderboard, profile }

class AppBottomNavBar extends StatefulWidget {
  final AppNavPage currentPage;

  const AppBottomNavBar({super.key, required this.currentPage});

  @override
  State<AppBottomNavBar> createState() => _AppBottomNavBarState();
}

class _AppBottomNavBarState extends State<AppBottomNavBar> {
  void replaceWith(Widget page) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  void openHome() {
    if (widget.currentPage == AppNavPage.home) return;

    replaceWith(const PlacesPage());
  }

  void openTraining() {
    if (widget.currentPage == AppNavPage.training) return;

    replaceWith(const TrainingModulePage());
  }

  void openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchPage()),
    );
  }

  void openLeaderboard() {
    if (widget.currentPage == AppNavPage.leaderboard) return;

    replaceWith(const LeaderboardPage());
  }

  void openProfile() {
    if (widget.currentPage == AppNavPage.profile) return;

    replaceWith(const UserProfilePage());
  }

  Color navColor(bool active) {
    return active ? const Color(0xFF2563EB) : const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: NavigationBar(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFFEAF2FF),
          selectedIndex: switch (widget.currentPage) {
            AppNavPage.home => 0,
            AppNavPage.training => 1,
            AppNavPage.leaderboard => 3,
            AppNavPage.profile => 4,
          },
          labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
          destinations: [
            // HOME
            NavigationDestination(
              icon: IconButton(
                icon: Icon(
                  Icons.home_outlined,
                  color: navColor(widget.currentPage == AppNavPage.home),
                ),
                onPressed: openHome,
              ),
              label: "Home",
            ),

            // TRAINING MODULE
            NavigationDestination(
              icon: IconButton(
                icon: Icon(
                  Icons.menu_book_outlined,
                  color: navColor(widget.currentPage == AppNavPage.training),
                ),
                onPressed: openTraining,
              ),
              label: "Training",
            ),

            // SEARCH
            NavigationDestination(
              icon: IconButton(
                icon: Icon(Icons.search_outlined, color: navColor(false)),
                onPressed: openSearch,
              ),
              label: "Search",
            ),

            // LEADERBOARD
            NavigationDestination(
              icon: IconButton(
                icon: Icon(
                  Icons.leaderboard_outlined,
                  color: navColor(widget.currentPage == AppNavPage.leaderboard),
                ),
                onPressed: openLeaderboard,
              ),
              label: "Leaderboard",
            ),

            // PROFILE
            NavigationDestination(
              icon: IconButton(
                icon: Icon(
                  Icons.person_outline,
                  color: navColor(widget.currentPage == AppNavPage.profile),
                ),
                onPressed: openProfile,
              ),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}
