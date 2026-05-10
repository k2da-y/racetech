import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import 'places_page.dart';
import 'profiling_page.dart';

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  @override
  void initState() {
    super.initState();
    checkSession();
  }

  Future<void> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");

    if (token == null) {
      openPage(const LoginPage());
      return;
    }

    final user = await ApiService().getUser();

    if (!mounted) return;

    if (user == null) {
      await prefs.remove("token");
      await prefs.remove("isProfiled");
      await prefs.remove("activities");
      openPage(const LoginPage());
      return;
    }

    final interests = user["interests"];
    final apiInterests = interests is List
        ? interests.map((interest) => interest.toString()).toList()
        : <String>[];

    if (apiInterests.isNotEmpty) {
      await prefs.setBool("isProfiled", true);
      await prefs.setStringList("activities", apiInterests);
    }

    final savedActivities = prefs.getStringList("activities") ?? [];
    final isProfiled =
        (prefs.getBool("isProfiled") ?? false) && savedActivities.isNotEmpty;

    openPage(isProfiled ? const PlacesPage() : const ProfilingPage());
  }

  void openPage(Widget page) {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
