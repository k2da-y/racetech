import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'places_page.dart';
import '../data/activity_data.dart';
import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM
// ============================================================

const _primary = Color(0xFFE53935);
const _dark = Color(0xFF111827);
const _secondaryText = Color(0xFF64748B);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF8FAFC);

class ProfilingPage extends StatefulWidget {
  const ProfilingPage({super.key});

  @override
  State<ProfilingPage> createState() => _ProfilingPageState();
}

class _ProfilingPageState extends State<ProfilingPage> {
  List<String> activitiesList = ActivityData.activities;
  List<String> selectedActivities = [];

  bool isSaving = false;
  bool isLoadingActivities = true;

  // ============================================================
  // EXISTING INTEREST LOGIC — UNCHANGED
  // ============================================================

  List<String> allowedInterestOptions(List<String> apiInterests) {
    final apiInterestSet = apiInterests.map(normalizeInterest).toSet();
    final allowedInterests = ActivityData.activities;

    if (apiInterestSet.isEmpty) {
      return allowedInterests;
    }

    final matchedInterests = allowedInterests
        .where(
          (interest) =>
          apiInterestSet.contains(normalizeInterest(interest)),
    )
        .toList();

    return matchedInterests.isEmpty
        ? allowedInterests
        : matchedInterests;
  }

  String normalizeInterest(String interest) {
    return interest.trim().toLowerCase();
  }

  @override
  void initState() {
    super.initState();
    loadActivities();
  }

  Future<void> loadActivities() async {
    final interests = await ApiService().getInterestTypes();

    if (!mounted) return;

    setState(() {
      activitiesList = allowedInterestOptions(interests);

      selectedActivities = selectedActivities
          .where(
            (activity) => activitiesList.contains(activity),
      )
          .toList();

      isLoadingActivities = false;
    });
  }

  // ============================================================
  // SUBMIT PROFILE — EXISTING LOGIC UNCHANGED
  // ============================================================

  void finishProfiling() async {
    if (selectedActivities.isEmpty) {
      showDialog(
        context: context,
        builder: (_) => const AlertDialog(
          title: Text("Incomplete"),
          content: Text(
            "Please select at least one activity.",
          ),
        ),
      );

      return;
    }

    setState(() => isSaving = true);

    final result =
    await ApiService().updateInterests(selectedActivities);

    if (!mounted) return;

    if (!result.success) {
      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
        ),
      );

      return;
    }

    final user = await ApiService().getUser();

    final normalizedInterests =
    ApiService().interestNamesFrom(user);

    final savedInterests = normalizedInterests.isEmpty
        ? selectedActivities
        : normalizedInterests;

    final prefs = await SharedPreferences.getInstance();

    // SAVE DATA
    await prefs.setBool("isProfiled", true);

    await prefs.setStringList(
      "activities",
      savedInterests,
    );

    if (!mounted) return;

    // GO TO PLACES PAGE
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const PlacesPage(),
      ),
    );
  }

  // ============================================================
  // INTEREST ICONS
  // UI ONLY
  // ============================================================

  IconData _getActivityIcon(String activity) {
    final value = activity.toLowerCase();

    if (value.contains("run")) {
      return Icons.directions_run_rounded;
    }

    if (value.contains("cycl") || value.contains("bike")) {
      return Icons.directions_bike_rounded;
    }

    if (value.contains("swim")) {
      return Icons.pool_rounded;
    }

    if (value.contains("walk") ||
        value.contains("hiking") ||
        value.contains("hike")) {
      return Icons.hiking_rounded;
    }

    if (value.contains("basketball")) {
      return Icons.sports_basketball_rounded;
    }

    if (value.contains("football") ||
        value.contains("soccer")) {
      return Icons.sports_soccer_rounded;
    }

    if (value.contains("volleyball")) {
      return Icons.sports_volleyball_rounded;
    }

    if (value.contains("tennis")) {
      return Icons.sports_tennis_rounded;
    }

    if (value.contains("gym") ||
        value.contains("fitness") ||
        value.contains("strength") ||
        value.contains("weight")) {
      return Icons.fitness_center_rounded;
    }

    if (value.contains("triathlon")) {
      return Icons.emoji_events_outlined;
    }

    return Icons.sports_rounded;
  }

  // ============================================================
  // INTEREST CHIP
  // ============================================================

  Widget buildChoice(String activity) {
    final isSelected =
    selectedActivities.contains(activity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isSaving
            ? null
            : () {
          setState(() {
            if (isSelected) {
              selectedActivities.remove(activity);
            } else {
              selectedActivities.add(activity);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 180,
          ),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: 13,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? _primary
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? _primary
                  : _border,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: _primary.withValues(
                  alpha: 0.18,
                ),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getActivityIcon(activity),
                color: isSelected
                    ? Colors.white
                    : _secondaryText,
                size: 18,
              ),

              const SizedBox(width: 7),

              Text(
                activity,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : _dark,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              if (isSelected) ...[
                const SizedBox(width: 7),

                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING STATE
  // ============================================================

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 35,
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor:
              AlwaysStoppedAnimation<Color>(
                _primary,
              ),
            ),
          ),

          SizedBox(height: 13),

          Text(
            "Loading activities...",
            style: TextStyle(
              color: _secondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INTEREST CARD
  // ============================================================

  Widget _buildInterestCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        22,
        24,
        22,
        22,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _primary.withValues(
                    alpha: 0.10,
                  ),
                  borderRadius:
                  BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.interests_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),

              const SizedBox(width: 13),

              const Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your interests",
                      style: TextStyle(
                        color: _dark,
                        fontSize: 16,
                        fontWeight:
                        FontWeight.w900,
                      ),
                    ),

                    SizedBox(height: 3),

                    Text(
                      "Select one or more activities.",
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 11.5,
                        fontWeight:
                        FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          if (isLoadingActivities)
            _buildLoadingState()
          else
            Wrap(
              spacing: 9,
              runSpacing: 9,
              children: activitiesList
                  .map(
                    (activity) =>
                    buildChoice(activity),
              )
                  .toList(),
            ),

          if (!isLoadingActivities) ...[
            const SizedBox(height: 22),

            AnimatedContainer(
              duration:
              const Duration(milliseconds: 180),
              width: double.infinity,
              padding:
              const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: selectedActivities.isEmpty
                    ? _background
                    : _primary.withValues(
                  alpha: 0.07,
                ),
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    selectedActivities.isEmpty
                        ? Icons.touch_app_outlined
                        : Icons
                        .check_circle_outline_rounded,
                    size: 17,
                    color:
                    selectedActivities.isEmpty
                        ? _secondaryText
                        : _primary,
                  ),

                  const SizedBox(width: 8),

                  Expanded(
                    child: Text(
                      selectedActivities.isEmpty
                          ? "Choose at least one interest to continue."
                          : "${selectedActivities.length} ${selectedActivities.length == 1 ? 'interest' : 'interests'} selected",
                      style: TextStyle(
                        color:
                        selectedActivities.isEmpty
                            ? _secondaryText
                            : _primary,
                        fontSize: 11.5,
                        fontWeight:
                        FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // GET STARTED BUTTON
  // ============================================================

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
        isSaving || isLoadingActivities
            ? null
            : finishProfiling,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
          _primary.withValues(alpha: 0.45),
          disabledForegroundColor:
          Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(15),
          ),
        ),
        child: AnimatedSwitcher(
          duration:
          const Duration(milliseconds: 200),
          child: isSaving
              ? const Row(
            key: ValueKey("saving"),
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 19,
                height: 19,
                child:
                CircularProgressIndicator(
                  strokeWidth: 2.3,
                  valueColor:
                  AlwaysStoppedAnimation<
                      Color>(
                    Colors.white,
                  ),
                ),
              ),

              SizedBox(width: 11),

              Text(
                "Saving interests...",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),
            ],
          )
              : const Row(
            key: ValueKey("continue"),
            mainAxisAlignment:
            MainAxisAlignment.center,
            children: [
              Text(
                "Start Exploring",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                  FontWeight.w800,
                ),
              ),

              SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_rounded,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics:
          const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            20,
            24,
            20,
            28,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
              const BoxConstraints(
                maxWidth: 430,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  // =============================================
                  // RACETECH BRAND
                  // =============================================

                  const Row(
                    children: [
                      Icon(
                        Icons.speed_rounded,
                        color: _primary,
                        size: 26,
                      ),

                      SizedBox(width: 8),

                      Text(
                        "RACETECH",
                        style: TextStyle(
                          color: _dark,
                          fontSize: 18,
                          letterSpacing: 1.8,
                          fontWeight:
                          FontWeight.w900,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // =============================================
                  // HERO
                  // =============================================

                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: _primary.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius:
                      BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons
                          .sports_score_rounded,
                      color: _primary,
                      size: 27,
                    ),
                  ),

                  const SizedBox(height: 18),

                  const Text(
                    "Make Racetech\nyours.",
                    style: TextStyle(
                      color: _dark,
                      fontSize: 32,
                      height: 1.05,
                      letterSpacing: -0.8,
                      fontWeight:
                      FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 11),

                  const Text(
                    "Choose the activities you're interested in so we can personalize your events and experience.",
                    style: TextStyle(
                      color: _secondaryText,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight:
                      FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 27),

                  _buildInterestCard(),

                  const SizedBox(height: 20),

                  _buildContinueButton(),

                  const SizedBox(height: 18),

                  const Center(
                    child: Text(
                      "You can update your interests later.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _secondaryText,
                        fontSize: 10.5,
                        fontWeight:
                        FontWeight.w500,
                      ),
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