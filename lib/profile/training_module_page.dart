import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as the rest of the app)
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF6366F1);
const _primaryDeep = Color(0xFF4F46E5);
const _accent = Color(0xFF0EA5E9);
const _primarySoft = Color(0xFFEEF2FF);

const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);

const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);

const _teal = Color(0xFF0F766E);
const _danger = Color(0xFFEF4444);
const _dangerSoft = Color(0xFFFEF2F2);

const _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_primaryDeep, _primary, _accent],
);

ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _primary,
      secondary: _accent,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _primary,
      selectionColor: Color(0x336366F1),
      selectionHandleColor: _primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class TrainingModulePage extends StatefulWidget {
  const TrainingModulePage({super.key});

  @override
  State<TrainingModulePage> createState() => _TrainingModulePageState();
}

class _TrainingModulePageState extends State<TrainingModulePage> {
  String selectedActivity = "";
  String selectedDifficulty = "all";
  String selectedType = "all";
  String selectedSort = "default";
  String searchQuery = "";
  final TextEditingController searchController = TextEditingController();
  final ScrollController modulesScrollController = ScrollController();
  bool isLoading = true;
  bool isLoadingMore = false;
  bool loadFailed = false;
  bool loadMoreFailed = false;
  List<Map<String, dynamic>> modules = [];
  List<String> trainingFocusTypes = [];
  String? nextTrainingModulesPageUrl;

  Future<void> loadTrainingModules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activities = prefs.getStringList("activities") ?? [];
      final results = await Future.wait([
        ApiService().getTrainingModulesPage(),
        ApiService().getTrainingFocusTypes(),
      ]);
      final modulesPage =
      results[0] as PaginatedApiResult<Map<String, dynamic>>;
      final focusTypes = results[1] as List<String>;

      if (!mounted) return;

      setState(() {
        selectedActivity = activities.isNotEmpty ? activities.first : "";
        modules = modulesPage.data;
        nextTrainingModulesPageUrl = modulesPage.nextPageUrl;
        trainingFocusTypes = focusTypes;
        isLoading = false;
        isLoadingMore = false;
        loadFailed = false;
        loadMoreFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        isLoadingMore = false;
        loadFailed = true;
      });
    }
  }

  Future<void> loadMoreTrainingModules() async {
    final nextPageUrl = nextTrainingModulesPageUrl;
    if (nextPageUrl == null || isLoading || isLoadingMore) {
      return;
    }

    setState(() {
      isLoadingMore = true;
      loadMoreFailed = false;
    });

    try {
      final modulesPage = await ApiService().getTrainingModulesPage(
        pageUrl: nextPageUrl,
      );

      if (!mounted) return;

      setState(() {
        final existingIds = modules
            .map((module) => module["id"]?.toString())
            .whereType<String>()
            .toSet();
        final newModules = modulesPage.data.where((module) {
          final id = module["id"]?.toString();
          return id == null || !existingIds.contains(id);
        });

        modules.addAll(newModules);
        nextTrainingModulesPageUrl = modulesPage.nextPageUrl;
        isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoadingMore = false;
        loadMoreFailed = true;
      });
    }
  }

  void handleModulesScroll() {
    if (!modulesScrollController.hasClients) {
      return;
    }

    final position = modulesScrollController.position;
    final nearBottom = position.pixels >= position.maxScrollExtent - 500;

    if (nearBottom && !loadMoreFailed) {
      loadMoreTrainingModules();
    }
  }

  /// Full reload with skeletons (used by the Refresh buttons).
  Future<void> reloadWithSkeleton() async {
    setState(() => isLoading = true);
    await loadTrainingModules();
  }

  /// Pull-to-refresh keeps the current list visible while reloading.
  Future<void> pullToRefresh() async {
    if (modules.isEmpty) {
      setState(() => isLoading = true);
    }
    await loadTrainingModules();
  }

  @override
  void initState() {
    super.initState();
    modulesScrollController.addListener(handleModulesScroll);
    loadTrainingModules();
  }

  @override
  void dispose() {
    modulesScrollController.removeListener(handleModulesScroll);
    modulesScrollController.dispose();
    searchController.dispose();
    super.dispose();
  }

  String normalizedDifficulty(dynamic difficulty) {
    return (difficulty ?? "").toString().trim().toLowerCase();
  }

  String normalizedType(dynamic type) {
    return (type ?? "").toString().trim().toLowerCase();
  }

  String moduleType(Map<String, dynamic> item) {
    final directType = (item["type"] ?? "").toString().trim();
    if (directType.isNotEmpty) {
      return directType;
    }

    final focus = item["training_focus_type"] ?? item["focus_type"];
    if (focus is Map) {
      return (focus["name"] ?? focus["title"] ?? focus["label"] ?? "")
          .toString()
          .trim();
    }

    return (focus ?? item["training_focus"] ?? item["focus"] ?? "")
        .toString()
        .trim();
  }

  String moduleInterestType(Map<String, dynamic> item) {
    final interest = item["interest_type"];
    if (interest is Map) {
      return (interest["name"] ?? interest["title"] ?? interest["label"] ?? "")
          .toString()
          .trim();
    }

    return (interest ?? "").toString().trim();
  }

  String displayDifficulty(String difficulty) {
    switch (difficulty) {
      case "all":
        return "All";
      case "beginner":
        return "Beginner";
      case "intermediate":
        return "Intermediate";
      case "advanced":
        return "Advanced";
      default:
        return difficulty.isEmpty ? "General" : difficulty;
    }
  }

  Color difficultyColor(String difficulty) {
    switch (difficulty) {
      case "beginner":
        return const Color(0xFF22C55E);
      case "intermediate":
        return const Color(0xFFF59E0B);
      case "advanced":
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String displayType(String type) {
    switch (type) {
      case "all":
        return "All Types";
      case "warmup":
        return "Warmup";
      case "safety":
        return "Safety";
      case "guideline":
        return "Guideline";
      case "program":
        return "Program";
      default:
        return type.isEmpty ? "General" : displayLabel(type);
    }
  }

  String displayLabel(String value) {
    return value
        .trim()
        .split(RegExp(r"[\s_-]+"))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(" ");
  }

  IconData typeIcon(String type) {
    switch (type) {
      case "warmup":
        return Icons.directions_run_outlined;
      case "safety":
        return Icons.health_and_safety_outlined;
      case "guideline":
        return Icons.menu_book_outlined;
      case "program":
        return Icons.fitness_center_outlined;
      default:
        return Icons.school_outlined;
    }
  }

  String displaySort(String sort) {
    switch (sort) {
      case "shortest":
        return "Shortest";
      case "longest":
        return "Longest";
      case "beginner_first":
        return "Beginner First";
      case "advanced_first":
        return "Advanced First";
      default:
        return "Default";
    }
  }

  IconData sortIcon(String sort) {
    switch (sort) {
      case "shortest":
        return Icons.timer_outlined;
      case "longest":
        return Icons.hourglass_bottom_rounded;
      case "beginner_first":
        return Icons.trending_up_rounded;
      case "advanced_first":
        return Icons.trending_down_rounded;
      default:
        return Icons.sort_rounded;
    }
  }

  int difficultyRank(String difficulty) {
    switch (difficulty) {
      case "beginner":
        return 0;
      case "intermediate":
        return 1;
      case "advanced":
        return 2;
      default:
        return 3;
    }
  }

  int durationMinutes(Map<String, dynamic> item) {
    return int.tryParse((item["duration"] ?? "").toString()) ?? 0;
  }

  List<Map<String, dynamic>> get difficultyFilteredModules {
    if (selectedDifficulty == "all") {
      return modules;
    }

    return modules
        .where(
          (item) =>
      normalizedDifficulty(item["difficulty_level"]) ==
          selectedDifficulty,
    )
        .toList();
  }

  int get beginnerCount {
    return modules
        .where(
          (item) =>
      normalizedDifficulty(item["difficulty_level"]) == "beginner",
    )
        .length;
  }

  int get intermediateCount {
    return modules
        .where(
          (item) =>
      normalizedDifficulty(item["difficulty_level"]) == "intermediate",
    )
        .length;
  }

  int get advancedCount {
    return modules
        .where(
          (item) =>
      normalizedDifficulty(item["difficulty_level"]) == "advanced",
    )
        .length;
  }

  int typeCount(String type) {
    if (type == "all") {
      return difficultyFilteredModules.length;
    }

    return difficultyFilteredModules
        .where((item) => normalizedType(moduleType(item)) == type)
        .length;
  }

  List<String> get availableTrainingTypes {
    final configuredTypes = trainingFocusTypes
        .map(normalizedType)
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();

    if (configuredTypes.isNotEmpty) {
      return configuredTypes;
    }

    return modules
        .map((module) => normalizedType(moduleType(module)))
        .where((type) => type.isNotEmpty)
        .toSet()
        .toList();
  }

  List<Map<String, dynamic>> get filteredModules {
    final byDifficulty = difficultyFilteredModules;
    final byType = selectedType == "all"
        ? byDifficulty
        : byDifficulty
        .where((item) => normalizedType(moduleType(item)) == selectedType)
        .toList();
    final query = searchQuery.trim().toLowerCase();

    final bySearch = query.isEmpty
        ? byType
        : byType.where((item) {
      final title = (item["title"] ?? "").toString().toLowerCase();
      final description = (item["description"] ?? "")
          .toString()
          .toLowerCase();
      final content = (item["content"] ?? "").toString().toLowerCase();
      final type = displayType(
        normalizedType(moduleType(item)),
      ).toLowerCase();
      final difficulty = displayDifficulty(
        normalizedDifficulty(item["difficulty_level"]),
      ).toLowerCase();

      return title.contains(query) ||
          description.contains(query) ||
          content.contains(query) ||
          type.contains(query) ||
          difficulty.contains(query);
    }).toList();
    final sorted = List<Map<String, dynamic>>.from(bySearch);

    switch (selectedSort) {
      case "shortest":
        sorted.sort((a, b) => durationMinutes(a).compareTo(durationMinutes(b)));
        break;
      case "longest":
        sorted.sort((a, b) => durationMinutes(b).compareTo(durationMinutes(a)));
        break;
      case "beginner_first":
        sorted.sort(
              (a, b) => difficultyRank(normalizedDifficulty(a["difficulty_level"]))
              .compareTo(
            difficultyRank(normalizedDifficulty(b["difficulty_level"])),
          ),
        );
        break;
      case "advanced_first":
        sorted.sort(
              (a, b) => difficultyRank(normalizedDifficulty(b["difficulty_level"]))
              .compareTo(
            difficultyRank(normalizedDifficulty(a["difficulty_level"])),
          ),
        );
        break;
    }

    return sorted;
  }

  void selectDifficulty(String difficulty) {
    HapticFeedback.selectionClick();
    setState(() => selectedDifficulty = difficulty);
  }

  void selectType(String type) {
    HapticFeedback.selectionClick();
    setState(() => selectedType = type);
  }

  void updateSearchQuery(String value) {
    setState(() => searchQuery = value);
  }

  void selectSort(String sort) {
    setState(() => selectedSort = sort);
  }

  bool get hasActiveFilters {
    return selectedDifficulty != "all" ||
        selectedType != "all" ||
        searchQuery.trim().isNotEmpty;
  }

  void clearFilters() {
    searchController.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      selectedDifficulty = "all";
      selectedType = "all";
      searchQuery = "";
    });
  }

  String get activeModuleTitle {
    if (selectedDifficulty == "all" &&
        selectedType == "all" &&
        searchQuery.trim().isEmpty) {
      return "All Training Modules";
    }

    final difficultyText = selectedDifficulty == "all"
        ? ""
        : displayDifficulty(selectedDifficulty);
    final typeText = selectedType == "all" ? "" : displayType(selectedType);
    final label = [
      difficultyText,
      typeText,
    ].where((part) => part.isNotEmpty).join(" ");

    if (label.isEmpty) {
      return "Search Results";
    }

    return "$label Modules";
  }

  String get emptyFilterTitle {
    if (searchQuery.trim().isNotEmpty) {
      return "No modules found";
    }

    if (selectedDifficulty != "all" && selectedType != "all") {
      final difficulty = displayDifficulty(selectedDifficulty).toLowerCase();
      final type = displayType(selectedType).toLowerCase();
      return "No $difficulty $type modules";
    }

    if (selectedType != "all") {
      return "No ${displayType(selectedType).toLowerCase()} modules";
    }

    return "No ${displayDifficulty(selectedDifficulty).toLowerCase()} modules";
  }

  void openModuleDetails(Map<String, dynamic> module) {
    FocusScope.of(context).unfocus();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Theme(
        data: _brandTheme(context),
        child: _TrainingModuleDetailsSheet(
          module: module,
          displayDifficulty: displayDifficulty,
          difficultyColor: difficultyColor,
          typeIcon: typeIcon,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // MODULE CARD
  // ───────────────────────────────────────────────────────────────────────────

  Widget moduleCard(Map<String, dynamic> module) {
    final title = (module["title"] ?? "Untitled Module").toString();
    final description = (module["description"] ?? "").toString();
    final content = (module["content"] ?? "").toString();
    final type = normalizedType(moduleType(module));
    final interestType = moduleInterestType(module);
    final difficulty = normalizedDifficulty(module["difficulty_level"]);
    final duration = module["duration"];
    final color = difficultyColor(difficulty);
    final preview = description.isNotEmpty ? description : content;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openModuleDetails(module),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Difficulty strip
                Container(width: 5, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 54,
                          width: 54,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: color.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Icon(typeIcon(type), color: color, size: 27),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w900,
                                  color: _ink,
                                  height: 1.25,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              if (preview.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  preview,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: _body,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 11),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MiniChip(
                                    icon: Icons.signal_cellular_alt_rounded,
                                    label: displayDifficulty(difficulty),
                                    color: color,
                                  ),
                                  if (duration != null)
                                    _MiniChip(
                                      icon: Icons.timer_outlined,
                                      label: "$duration min",
                                      color: _primary,
                                    ),
                                  if (type.isNotEmpty)
                                    _MiniChip(
                                      icon: Icons.category_outlined,
                                      label: displayType(type),
                                      color: _muted,
                                    ),
                                  _MiniChip(
                                    icon: Icons.local_offer_outlined,
                                    label: interestType.isEmpty
                                        ? "General"
                                        : displayLabel(interestType),
                                    color: _teal,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          height: 30,
                          width: 30,
                          decoration: BoxDecoration(
                            color: _fieldFill,
                            shape: BoxShape.circle,
                            border: Border.all(color: _border),
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: _faint,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HEADER
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHero() {
    final topInset = MediaQuery.paddingOf(context).top;
    final hasMore = nextTrainingModulesPageUrl != null;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 18, 20, 64),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isLoading
                              ? "–"
                              : "${modules.length}${hasMore ? '+' : ''}",
                          style: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 5),
                          child: Text(
                            "Training Modules",
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            selectedActivity.isEmpty
                                ? Icons.auto_awesome_rounded
                                : Icons.my_location_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              selectedActivity.isEmpty
                                  ? "Preparing your training plan"
                                  : "Focused on $selectedActivity",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSearchField(),
        ],
      ),
    );
  }

  Widget _buildDifficultyTiles() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E6366F1),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _DifficultyTile(
              label: "All",
              value: isLoading ? "–" : "${modules.length}",
              color: _primary,
              isSelected: selectedDifficulty == "all",
              onTap: () => selectDifficulty("all"),
            ),
          ),
          Expanded(
            child: _DifficultyTile(
              label: "Beginner",
              value: isLoading ? "–" : "$beginnerCount",
              color: const Color(0xFF22C55E),
              isSelected: selectedDifficulty == "beginner",
              onTap: () => selectDifficulty("beginner"),
            ),
          ),
          Expanded(
            child: _DifficultyTile(
              label: "Intermediate",
              value: isLoading ? "–" : "$intermediateCount",
              color: const Color(0xFFF59E0B),
              isSelected: selectedDifficulty == "intermediate",
              onTap: () => selectDifficulty("intermediate"),
            ),
          ),
          Expanded(
            child: _DifficultyTile(
              label: "Advanced",
              value: isLoading ? "–" : "$advancedCount",
              color: const Color(0xFFEF4444),
              isSelected: selectedDifficulty == "advanced",
              onTap: () => selectDifficulty("advanced"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilters() {
    final availableTypes = availableTrainingTypes;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _TypeChip(
            icon: Icons.apps_rounded,
            label: "All Types",
            count: typeCount("all"),
            isSelected: selectedType == "all",
            onTap: () => selectType("all"),
          ),
          ...availableTypes.map(
                (type) => _TypeChip(
              icon: typeIcon(type),
              label: displayType(type),
              count: typeCount(type),
              isSelected: selectedType == type,
              onTap: () => selectType(type),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: searchController,
      onChanged: updateSearchQuery,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      decoration: InputDecoration(
        hintText: "Search training modules",
        hintStyle: const TextStyle(
          color: _faint,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const Icon(Icons.search_rounded, color: _muted),
        suffixIcon: searchQuery.trim().isEmpty
            ? null
            : IconButton(
          tooltip: "Clear search",
          onPressed: () {
            searchController.clear();
            updateSearchQuery("");
          },
          icon: const Icon(Icons.close_rounded, color: _muted),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFC7D2FE), width: 2),
        ),
      ),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _ink,
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value) {
    final isSelected = selectedSort == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(
            height: 30,
            width: 30,
            decoration: BoxDecoration(
              color: isSelected ? _primarySoft : _fieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              sortIcon(value),
              size: 16,
              color: isSelected ? _primary : _muted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              displaySort(value),
              style: TextStyle(
                color: isSelected ? _primaryDeep : _ink,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded, size: 18, color: _primary),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    final isDefault = selectedSort == "default";

    return PopupMenuButton<String>(
      tooltip: "Sort modules",
      initialValue: selectedSort,
      onSelected: selectSort,
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        _sortMenuItem("default"),
        _sortMenuItem("shortest"),
        _sortMenuItem("longest"),
        _sortMenuItem("beginner_first"),
        _sortMenuItem("advanced_first"),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: isDefault ? Colors.white : _primarySoft,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: isDefault ? _border : const Color(0xFFC7D2FE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sortIcon(selectedSort),
              size: 16,
              color: isDefault ? _muted : _primary,
            ),
            const SizedBox(width: 5),
            Text(
              isDefault ? "Sort" : displaySort(selectedSort),
              style: TextStyle(
                color: isDefault ? _muted : _primaryDeep,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              activeModuleTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w900,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CountBadge(count: count),
          const Spacer(),
          if (hasActiveFilters) ...[
            TextButton.icon(
              onPressed: clearFilters,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: _primary,
              ),
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text(
                "Clear",
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
              ),
            ),
            const SizedBox(width: 4),
          ],
          _buildSortMenu(),
        ],
      ),
    );
  }

  Widget _buildListFooter() {
    if (isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            height: 26,
            width: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
        ),
      );
    }

    if (nextTrainingModulesPageUrl != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Column(
          children: [
            if (loadMoreFailed)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  "Couldn't load more modules.",
                  style: TextStyle(
                    color: _danger,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: loadMoreTrainingModules,
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                backgroundColor: Colors.white,
                minimumSize: const Size(170, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                loadMoreFailed
                    ? Icons.refresh_rounded
                    : Icons.expand_more_rounded,
                size: 20,
              ),
              label: Text(
                loadMoreFailed ? "Try again" : "Load more modules",
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      );
    }

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 16, color: _faint),
          SizedBox(width: 6),
          Text(
            "You've seen all modules",
            style: TextStyle(
              color: _faint,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContentSlivers() {
    if (isLoading) {
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          sliver: SliverList.builder(
            itemCount: 4,
            itemBuilder: (context, index) => const _SkeletonCard(),
          ),
        ),
      ];
    }

    if (modules.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: loadFailed
              ? _StateCard(
            icon: Icons.wifi_off_rounded,
            iconColor: _danger,
            iconBackground: _dangerSoft,
            title: "Couldn't load modules",
            message: "Check your connection and try again.",
            actionLabel: "Try again",
            actionIcon: Icons.refresh_rounded,
            onAction: reloadWithSkeleton,
          )
              : _StateCard(
            icon: Icons.school_outlined,
            iconColor: _primary,
            iconBackground: _primarySoft,
            title: "No training modules yet",
            message: "Training modules will appear here once available.",
            actionLabel: "Refresh",
            actionIcon: Icons.refresh_rounded,
            onAction: reloadWithSkeleton,
          ),
        ),
      ];
    }

    final visibleModules = filteredModules;

    return [
      if (loadFailed)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _RefreshErrorBanner(onRetry: pullToRefresh),
          ),
        ),
      SliverToBoxAdapter(child: _buildResultsHeader(visibleModules.length)),
      if (visibleModules.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: _StateCard(
            icon: Icons.filter_alt_off_outlined,
            iconColor: _primary,
            iconBackground: _primarySoft,
            title: emptyFilterTitle,
            message: "Try another filter or view all training modules.",
            actionLabel: "Clear filters",
            actionIcon: Icons.close_rounded,
            onAction: () async {
              clearFilters();
            },
            topPadding: 0,
          ),
        )
      else ...[
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: visibleModules.length,
            itemBuilder: (context, index) => moduleCard(visibleModules[index]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _buildListFooter(),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Theme(
      data: _brandTheme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          bottomNavigationBar: isKeyboardOpen
              ? null
              : const AppBottomNavBar(currentPage: AppNavPage.training),
          body: RefreshIndicator(
            color: _primary,
            backgroundColor: Colors.white,
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: pullToRefresh,
            child: CustomScrollView(
              controller: modulesScrollController,
              keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 40),
                        child: _buildHero(),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 0,
                        child: _buildDifficultyTiles(),
                      ),
                    ],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
                SliverToBoxAdapter(child: _buildTypeFilters()),
                ..._buildContentSlivers(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _DifficultyTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyTile({
    required this.label,
    required this.value,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.45)
                    : Colors.transparent,
                width: 1.4,
              ),
            ),
            child: Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? color : _muted,
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

class _TypeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Semantics(
        selected: isSelected,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(99),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
              decoration: BoxDecoration(
                gradient: isSelected ? _heroGradient : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(
                  color: isSelected ? Colors.transparent : _border,
                ),
                boxShadow: isSelected
                    ? const [
                  BoxShadow(
                    color: Color(0x336366F1),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : _muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : _body,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.22)
                          : _fieldFill,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      "$count",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _muted,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
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

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    Widget block(double h, double w, double r) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFE9EDF5),
        borderRadius: BorderRadius.circular(r),
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: _Pulse(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            block(54, 54, 17),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(15, double.infinity, 8),
                  const SizedBox(height: 8),
                  block(12, 200, 8),
                  const SizedBox(height: 6),
                  block(12, 150, 8),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      block(22, 70, 99),
                      const SizedBox(width: 6),
                      block(22, 56, 99),
                      const SizedBox(width: 6),
                      block(22, 64, 99),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final Future<void> Function() onAction;
  final double topPadding;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
    this.topPadding = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 24),
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
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
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(160, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: Icon(actionIcon, size: 19),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
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
              "Couldn't refresh. Showing the last loaded modules.",
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

// ─────────────────────────────────────────────────────────────────────────────
// DETAILS SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _TrainingModuleDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> module;
  final String Function(String difficulty) displayDifficulty;
  final Color Function(String difficulty) difficultyColor;
  final IconData Function(String type) typeIcon;

  const _TrainingModuleDetailsSheet({
    required this.module,
    required this.displayDifficulty,
    required this.difficultyColor,
    required this.typeIcon,
  });

  String displayType(String type) {
    switch (type) {
      case "warmup":
        return "Warmup";
      case "safety":
        return "Safety";
      case "guideline":
        return "Guideline";
      case "program":
        return "Program";
      default:
        return type.isEmpty ? "General" : displayLabel(type);
    }
  }

  String displayLabel(String value) {
    return value
        .trim()
        .split(RegExp(r"[\s_-]+"))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(" ");
  }

  String moduleType() {
    final directType = (module["type"] ?? "").toString().trim();
    if (directType.isNotEmpty) {
      return directType;
    }

    final focus = module["training_focus_type"] ?? module["focus_type"];
    if (focus is Map) {
      return (focus["name"] ?? focus["title"] ?? focus["label"] ?? "")
          .toString()
          .trim();
    }

    return (focus ?? module["training_focus"] ?? module["focus"] ?? "")
        .toString()
        .trim();
  }

  String moduleInterestType() {
    final interest = module["interest_type"];
    if (interest is Map) {
      return (interest["name"] ?? interest["title"] ?? interest["label"] ?? "")
          .toString()
          .trim();
    }

    return (interest ?? "").toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final title = (module["title"] ?? "Untitled Module").toString();
    final description = (module["description"] ?? "").toString();
    final content = (module["content"] ?? "").toString();
    final type = moduleType().toLowerCase();
    final interestType = moduleInterestType();
    final difficulty = (module["difficulty_level"] ?? "")
        .toString()
        .trim()
        .toLowerCase();
    final duration = module["duration"];
    final color = difficultyColor(difficulty);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header band
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            color.withValues(alpha: 0.14),
                            Colors.white,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _border,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 64,
                                width: 64,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.3),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.18),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  typeIcon(type),
                                  color: color,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayType(type).toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w900,
                                        color: _ink,
                                        height: 1.2,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _DetailMetaRow(
                            difficulty: displayDifficulty(difficulty),
                            difficultyColor: color,
                            type: displayType(type),
                            interestType: interestType.isEmpty
                                ? "General"
                                : displayLabel(interestType),
                            duration: duration,
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _DetailSection(
                              icon: Icons.notes_rounded,
                              title: "Overview",
                              text: description,
                            ),
                          ],
                          if (content.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _DetailSection(
                              icon: Icons.article_outlined,
                              title: "Details",
                              text: content,
                            ),
                          ],
                          if (description.isEmpty && content.isEmpty) ...[
                            const SizedBox(height: 16),
                            const _DetailSection(
                              icon: Icons.article_outlined,
                              title: "Details",
                              text:
                              "No additional training details are available yet.",
                            ),
                          ],
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _heroGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x406366F1),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(context),
                      child: const Center(
                        child: Text(
                          "Done",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
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

class _DetailMetaRow extends StatelessWidget {
  final String difficulty;
  final Color difficultyColor;
  final String type;
  final String interestType;
  final dynamic duration;

  const _DetailMetaRow({
    required this.difficulty,
    required this.difficultyColor,
    required this.type,
    required this.interestType,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _DetailMetaTile(
                label: "Level",
                value: difficulty,
                icon: Icons.signal_cellular_alt_rounded,
                color: difficultyColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DetailMetaTile(
                label: "Type",
                value: type,
                icon: Icons.category_outlined,
                color: _muted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DetailMetaTile(
                label: "Time",
                value: duration == null ? "Open" : "$duration min",
                icon: Icons.timer_outlined,
                color: _primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _teal.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _teal.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: _teal, size: 18),
              const SizedBox(width: 10),
              const Text(
                "Interest",
                style: TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  interestType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: _teal,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailMetaTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _DetailMetaTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _DetailSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _primary, size: 17),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SelectableText(
            text,
            style: const TextStyle(
              color: _body,
              fontSize: 14,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}