import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/activity_data.dart';
import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _warning = Color(0xFFB45309);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

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

  /// Interests as they were when the page loaded — used to detect unsaved edits.
  Set<String> savedInterests = {};

  // ============================================================
  // DATA — logic unchanged
  // ============================================================

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
    final userInterests = interestsFromUser(user);
    final availableInterests = allowedInterestOptions(apiInterests);

    setState(() {
      interests = availableInterests;
      selectedInterests = userInterests
          .where((interest) => availableInterests.contains(interest))
          .toList();
      savedInterests = selectedInterests.toSet();
      isLoading = false;
    });
  }

  List<String> interestsFromUser(Map<String, dynamic>? user) {
    return ApiService().interestNamesFrom(user);
  }

  Future<void> refreshInterests() async {
    if (isLoading || isSaving) return;
    if (hasUnsavedChanges && !await confirmDiscardChanges()) return;
    if (!mounted) return;

    setState(() => isLoading = true);
    await loadInterests();
  }

  Future<void> saveInterests() async {
    if (selectedInterests.isEmpty) {
      showMessage("Please select at least one interest.");
      return;
    }

    setState(() => isSaving = true);

    final result = await ApiService().updateInterests(selectedInterests);

    if (!mounted) return;

    if (!result.success) {
      setState(() => isSaving = false);
      showMessage(result.message);
      return;
    }

    // Stay in the saving state until local prefs are updated too, so the
    // button can't be pressed twice in the meantime.
    final user = await ApiService().getUser();
    final normalizedInterests = ApiService().interestNamesFrom(user);
    final finalInterests = normalizedInterests.isEmpty
        ? selectedInterests
        : normalizedInterests;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isProfiled", true);
    await prefs.setStringList("activities", finalInterests);

    if (!mounted) return;

    savedInterests = selectedInterests.toSet();
    setState(() => isSaving = false);

    showMessage(result.message);
    Navigator.pop(context, true);
  }

  // ============================================================
  // SELECTION
  // ============================================================

  void toggleInterest(String interest) {
    HapticFeedback.selectionClick();
    setState(() {
      if (selectedInterests.contains(interest)) {
        selectedInterests.remove(interest);
      } else {
        selectedInterests.add(interest);
      }
    });
  }

  bool get allSelected =>
      interests.isNotEmpty && selectedInterests.length == interests.length;

  void toggleAll() {
    setState(() {
      selectedInterests = allSelected ? [] : List.of(interests);
    });
  }

  bool get hasUnsavedChanges =>
      !isLoading &&
      (selectedInterests.length != savedInterests.length ||
          !selectedInterests.every(savedInterests.contains));

  Future<bool> confirmDiscardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.edit_note_rounded, color: _primary, size: 30),
        ),
        title: const Text(
          "Discard changes?",
          style: TextStyle(fontWeight: FontWeight.w900, color: _ink),
        ),
        content: const Text(
          "Your interest changes haven't been saved yet.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Discard"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Keep editing"),
          ),
        ],
      ),
    );

    return discard == true;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(message)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final unsaved = hasUnsavedChanges;

    return PopScope(
      canPop: !isSaving && !unsaved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || isSaving) return;
        if (await confirmDiscardChanges() && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          body: RefreshIndicator(
            color: _primary,
            onRefresh: refreshInterests,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _InterestsHero(
                    isLoading: isLoading,
                    isSaving: isSaving,
                    hasUnsavedChanges: unsaved,
                    selectedCount: selectedInterests.length,
                    totalCount: interests.length,
                    onBack: () => Navigator.maybePop(context),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: isLoading
                            ? const _LoadingCard()
                            : interestsCard(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: isLoading ? null : saveBar(unsaved),
        ),
      ),
    );
  }

  Widget interestsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_outlined, color: _primaryDeep, size: 18),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  "We use these to recommend events on your home page.",
                  style: TextStyle(
                    color: _primaryDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: _softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: _primarySoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.tune_rounded,
                      color: _primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      "Your Interests",
                      style: TextStyle(
                        color: _ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (interests.length > 1)
                    TextButton(
                      onPressed: isSaving ? null : toggleAll,
                      style: TextButton.styleFrom(
                        foregroundColor: _primary,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(allSelected ? "Clear all" : "Select all"),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Two-column grid of tappable tiles (wraps on narrow screens).
              LayoutBuilder(
                builder: (context, constraints) {
                  const spacing = 10.0;
                  final columns = constraints.maxWidth >= 300 ? 2 : 1;
                  final tileWidth =
                      (constraints.maxWidth - spacing * (columns - 1)) /
                      columns;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final interest in interests)
                        SizedBox(
                          width: tileWidth,
                          child: _InterestTile(
                            label: interest,
                            icon: _iconForInterest(interest),
                            selected: selectedInterests.contains(interest),
                            onTap: isSaving
                                ? null
                                : () => toggleInterest(interest),
                          ),
                        ),
                    ],
                  );
                },
              ),

              if (selectedInterests.isEmpty) ...[
                const SizedBox(height: 14),
                const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: _faint),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Pick at least one to save.",
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
          ),
        ),
      ],
    );
  }

  Widget saveBar(bool unsaved) {
    final count = selectedInterests.length;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A94A3B8),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      unsaved ? "You have unsaved changes" : "$count selected",
                      style: TextStyle(
                        color: unsaved ? _warning : _muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primary.withValues(
                          alpha: 0.5,
                        ),
                        disabledForegroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isSaving || count == 0 ? null : saveInterests,
                      icon: isSaving
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.3,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        isSaving ? "Saving..." : "Save",
                        style: const TextStyle(
                          fontSize: 15,
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
      ),
    );
  }
}

/// Picks a fitting icon from the interest name; falls back to a generic one.
IconData _iconForInterest(String interest) {
  final name = interest.toLowerCase();

  if (name.contains("trail")) return Icons.terrain_rounded;
  if (name.contains("hik") || name.contains("trek") || name.contains("climb")) {
    return Icons.hiking_rounded;
  }
  if (name.contains("cycl") || name.contains("bike") || name.contains("ride")) {
    return Icons.directions_bike_rounded;
  }
  if (name.contains("swim")) return Icons.pool_rounded;
  if (name.contains("triathlon") || name.contains("duathlon")) {
    return Icons.emoji_events_outlined;
  }
  if (name.contains("walk")) return Icons.directions_walk_rounded;
  if (name.contains("run") ||
      name.contains("marathon") ||
      name.contains("fun")) {
    return Icons.directions_run_rounded;
  }
  if (name.contains("yoga") ||
      name.contains("fitness") ||
      name.contains("gym")) {
    return Icons.fitness_center_rounded;
  }

  return Icons.local_activity_outlined;
}

// ============================================================
// HERO HEADER
// ============================================================

class _InterestsHero extends StatelessWidget {
  final bool isLoading;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final int selectedCount;
  final int totalCount;
  final VoidCallback onBack;

  const _InterestsHero({
    required this.isLoading,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.selectedCount,
    required this.totalCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDeep, _primary, _accent],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  _GlassButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: "Back",
                    onTap: isSaving ? null : onBack,
                  ),
                  const Expanded(
                    child: Text(
                      "Edit Interests",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: hasUnsavedChanges
                        ? const Tooltip(
                            message: "Unsaved changes",
                            child: Icon(
                              Icons.circle,
                              color: Color(0xFFFCD34D),
                              size: 12,
                            ),
                          )
                        : null,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Container(
                height: 76,
                width: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.interests_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                "What do you love doing?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                isSaving
                    ? "Saving your interests..."
                    : "Choose the activities you want to see events for.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      color: _primary,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLoading
                          ? "Loading..."
                          : "$selectedCount of $totalCount selected",
                      style: const TextStyle(
                        color: _primaryDeep,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
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

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// INTEREST TILE
// ============================================================

class _InterestTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  const _InterestTile({
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
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _primary : _fieldFill,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? _primary : _border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.2)
                          : _primarySoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: selected ? Colors.white : _primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : _body,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 160),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: selected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey(true),
                            color: Colors.white,
                            size: 20,
                          )
                        : const Icon(
                            Icons.circle_outlined,
                            key: ValueKey(false),
                            color: Color(0xFFCBD5E1),
                            size: 20,
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

// ============================================================
// LOADING
// ============================================================

class _LoadingCard extends StatefulWidget {
  const _LoadingCard();

  @override
  State<_LoadingCard> createState() => _LoadingCardState();
}

class _LoadingCardState extends State<_LoadingCard>
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

  Widget block({double? width, required double height, double radius = 14}) {
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
    final content = Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              block(width: 40, height: 40, radius: 13),
              const SizedBox(width: 12),
              block(width: 130, height: 16, radius: 8),
            ],
          ),
          const SizedBox(height: 16),
          for (var row = 0; row < 3; row++) ...[
            if (row > 0) const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: block(height: 60, radius: 18)),
                const SizedBox(width: 10),
                Expanded(child: block(height: 60, radius: 18)),
              ],
            ),
          ],
        ],
      ),
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}
