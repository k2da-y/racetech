import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/activity_data.dart';
import '../services/api_service.dart';

class EditInterestsPage extends StatefulWidget {
  const EditInterestsPage({super.key});

  @override
  State<EditInterestsPage> createState() => _EditInterestsPageState();
}

class _EditInterestsPageState extends State<EditInterestsPage> {
  List<String> interests = ActivityData.activities;
  List<String> selectedInterests = [];
  bool isLoading = true;
  bool isSaving = false;

  List<String> allowedInterestOptions(List<String> apiInterests) {
    final apiInterestSet = apiInterests.map(normalizeInterest).toSet();
    final allowedInterests = ActivityData.activities;

    if (apiInterestSet.isEmpty) {
      return allowedInterests;
    }

    final matchedInterests = allowedInterests
        .where(
          (interest) => apiInterestSet.contains(normalizeInterest(interest)),
        )
        .toList();

    return matchedInterests.isEmpty ? allowedInterests : matchedInterests;
  }

  String normalizeInterest(String interest) {
    return interest.trim().toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    loadInterests();
  }

  Future<void> loadInterests() async {
    final results = await Future.wait([
      ApiService().getInterestTypes(),
      ApiService().getUser(),
    ]);

    if (!mounted) return;

    final apiInterests = results[0] as List<String>;
    final user = results[1] as Map<String, dynamic>?;
    final savedInterests = interestsFromUser(user);
    final availableInterests = allowedInterestOptions(apiInterests);

    setState(() {
      interests = availableInterests;
      selectedInterests = savedInterests
          .where((interest) => availableInterests.contains(interest))
          .toList();
      isLoading = false;
    });
  }

  List<String> interestsFromUser(Map<String, dynamic>? user) {
    return ApiService().interestNamesFrom(user);
  }

  Future<void> saveInterests() async {
    if (selectedInterests.isEmpty) {
      showMessage("Please select at least one interest.");
      return;
    }

    setState(() => isSaving = true);

    final result = await ApiService().updateInterests(selectedInterests);

    if (!mounted) return;

    setState(() => isSaving = false);

    if (!result.success) {
      showMessage(result.message);
      return;
    }

    final user = await ApiService().getUser();
    final normalizedInterests = ApiService().interestNamesFrom(user);
    final savedInterests = normalizedInterests.isEmpty
        ? selectedInterests
        : normalizedInterests;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isProfiled", true);
    await prefs.setStringList("activities", savedInterests);

    if (!mounted) return;

    showMessage(result.message);
    Navigator.pop(context, true);
  }

  void toggleInterest(String interest) {
    setState(() {
      if (selectedInterests.contains(interest)) {
        selectedInterests.remove(interest);
      } else {
        selectedInterests.add(interest);
      }
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  Widget interestChip(String interest) {
    final isSelected = selectedInterests.contains(interest);

    return ChoiceChip(
      selected: isSelected,
      label: Text(interest),
      avatar: isSelected
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF111827),
        fontWeight: FontWeight.w700,
      ),
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onSelected: isSaving ? null : (_) => toggleInterest(interest),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: Column(
          children: [
            _HeaderSection(
              isSaving: isSaving,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() => isLoading = true);
                        await loadInterests();
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
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
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.tune_outlined,
                                        color: Color(0xFF2563EB),
                                      ),
                                      SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          "Your Interests",
                                          style: TextStyle(
                                            color: Color(0xFF111827),
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 10,
                                    children: interests
                                        .map(
                                          (interest) => interestChip(interest),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                onPressed: isSaving ? null : saveInterests,
                                icon: isSaving
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  isSaving ? "Saving..." : "Save Interests",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
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
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onBack;

  const _HeaderSection({required this.isSaving, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFEAF2FF),
                foregroundColor: const Color(0xFF2563EB),
              ),
              onPressed: isSaving ? null : onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Edit Interests",
                    style: TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isSaving
                        ? "Saving your interests..."
                        : "Update your event preferences",
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.interests_outlined,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
