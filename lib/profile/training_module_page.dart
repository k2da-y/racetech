import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';

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
  List<Map<String, dynamic>> modules = [];
  List<String> trainingFocusTypes = [];
  String? nextTrainingModulesPageUrl;

  Future<void> loadTrainingModules() async {
    final prefs = await SharedPreferences.getInstance();
    final activities = prefs.getStringList("activities") ?? [];
    final results = await Future.wait([
      ApiService().getTrainingModulesPage(),
      ApiService().getTrainingFocusTypes(),
    ]);
    final modulesPage = results[0] as PaginatedApiResult<Map<String, dynamic>>;
    final focusTypes = results[1] as List<String>;

    if (!mounted) return;

    setState(() {
      selectedActivity = activities.isNotEmpty ? activities.first : "";
      modules = modulesPage.data;
      nextTrainingModulesPageUrl = modulesPage.nextPageUrl;
      trainingFocusTypes = focusTypes;
      isLoading = false;
      isLoadingMore = false;
    });
  }

  Future<void> loadMoreTrainingModules() async {
    final nextPageUrl = nextTrainingModulesPageUrl;
    if (nextPageUrl == null || isLoading || isLoadingMore) {
      return;
    }

    setState(() => isLoadingMore = true);

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
  }

  void handleModulesScroll() {
    if (!modulesScrollController.hasClients) {
      return;
    }

    final position = modulesScrollController.position;
    final nearBottom = position.pixels >= position.maxScrollExtent - 500;

    if (nearBottom) {
      loadMoreTrainingModules();
    }
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
    setState(() => selectedDifficulty = difficulty);
  }

  void selectType(String type) {
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

  Widget moduleCard(Map<String, dynamic> module) {
    final title = (module["title"] ?? "Untitled Module").toString();
    final description = (module["description"] ?? "").toString();
    final content = (module["content"] ?? "").toString();
    final type = normalizedType(moduleType(module));
    final interestType = moduleInterestType(module);
    final difficulty = normalizedDifficulty(module["difficulty_level"]);
    final duration = module["duration"];
    final color = difficultyColor(difficulty);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            builder: (_) => _TrainingModuleDetailsSheet(
              module: module,
              displayDifficulty: displayDifficulty,
              difficultyColor: difficultyColor,
              typeIcon: typeIcon,
            ),
          );
        },
        child: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(typeIcon(type), color: color, size: 30),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 5),
                  if (description.isNotEmpty)
                    Text(
                      description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _miniChip(
                        icon: Icons.signal_cellular_alt_rounded,
                        label: displayDifficulty(difficulty),
                        color: color,
                      ),
                      if (duration != null)
                        _miniChip(
                          icon: Icons.timer_outlined,
                          label: "$duration min",
                          color: const Color(0xFF2563EB),
                        ),
                      if (type.isNotEmpty)
                        _miniChip(
                          icon: Icons.category_outlined,
                          label: displayType(type),
                          color: const Color(0xFF64748B),
                        ),
                      _miniChip(
                        icon: Icons.local_offer_outlined,
                        label: interestType.isEmpty
                            ? "General"
                            : displayLabel(interestType),
                        color: const Color(0xFF0F766E),
                      ),
                    ],
                  ),
                  if (content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 10),

            const Icon(Icons.chevron_right_rounded, color: Color(0xFF64748B)),
          ],
        ),
      ),
    );
  }

  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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

  Widget _buildHeader() {
    return Column(
      children: [
        const SizedBox(height: 12),

        const SizedBox(height: 20),

        Text(
          "${modules.length}",
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            height: 1,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Training Modules",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          selectedActivity.isEmpty
              ? "Preparing your training plan"
              : "Focused on $selectedActivity",
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 26),

        Row(
          children: [
            Expanded(
              child: _statCard(
                label: "All",
                value: "${modules.length}",
                color: const Color(0xFF2563EB),
                isSelected: selectedDifficulty == "all",
                onTap: () => selectDifficulty("all"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                label: "Beginner",
                value: "$beginnerCount",
                color: const Color(0xFF22C55E),
                isSelected: selectedDifficulty == "beginner",
                onTap: () => selectDifficulty("beginner"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                label: "Intermediate",
                value: "$intermediateCount",
                color: const Color(0xFFF59E0B),
                isSelected: selectedDifficulty == "intermediate",
                onTap: () => selectDifficulty("intermediate"),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _statCard(
                label: "Advanced",
                value: "$advancedCount",
                color: const Color(0xFFEF4444),
                isSelected: selectedDifficulty == "advanced",
                onTap: () => selectDifficulty("advanced"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? color : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeFilterChip({
    required String type,
    required String label,
    required int count,
  }) {
    final isSelected = selectedType == type;
    final color = isSelected
        ? const Color(0xFF2563EB)
        : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: isSelected,
        showCheckmark: false,
        label: Text("$label ($count)"),
        avatar: Icon(
          type == "all" ? Icons.category_outlined : typeIcon(type),
          size: 16,
          color: isSelected ? Colors.white : color,
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF334155),
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
        selectedColor: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
        onSelected: (_) => selectType(type),
      ),
    );
  }

  Widget _buildTypeFilters() {
    final availableTypes = availableTrainingTypes;

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          _typeFilterChip(
            type: "all",
            label: "All Types",
            count: typeCount("all"),
          ),
          ...availableTypes.map(
            (type) => _typeFilterChip(
              type: type,
              label: displayType(type),
              count: typeCount(type),
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
      decoration: InputDecoration(
        hintText: "Search training modules",
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: searchQuery.trim().isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  searchController.clear();
                  updateSearchQuery("");
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.4),
        ),
      ),
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value) {
    final isSelected = selectedSort == value;

    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.check_rounded : Icons.sort_rounded,
            size: 18,
            color: isSelected
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 10),
          Text(
            displaySort(value),
            style: TextStyle(
              color: isSelected
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF111827),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<String>(
      tooltip: "Sort modules",
      initialValue: selectedSort,
      onSelected: selectSort,
      itemBuilder: (context) => [
        _sortMenuItem("default"),
        _sortMenuItem("shortest"),
        _sortMenuItem("longest"),
        _sortMenuItem("beginner_first"),
        _sortMenuItem("advanced_first"),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: selectedSort == "default"
              ? Colors.white
              : const Color(0xFFEAF2FF),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selectedSort == "default"
                ? const Color(0xFFE2E8F0)
                : const Color(0xFFBFDBFE),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 16,
              color: selectedSort == "default"
                  ? const Color(0xFF64748B)
                  : const Color(0xFF2563EB),
            ),
            const SizedBox(width: 5),
            Text(
              "Sort",
              style: TextStyle(
                color: selectedSort == "default"
                    ? const Color(0xFF64748B)
                    : const Color(0xFF2563EB),
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget loadingState() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          height: 120,
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
          child: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }

  Widget emptyState({
    String title = "No training modules yet",
    String message = "Training modules will appear here once available.",
    IconData icon = Icons.school_outlined,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(28),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54, color: const Color(0xFF2563EB)),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), height: 1.35),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () async {
                  setState(() => isLoading = true);
                  await loadTrainingModules();
                },
                icon: const Icon(Icons.refresh),
                label: const Text("Refresh"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return loadingState();
    }

    if (modules.isEmpty) {
      return emptyState();
    }

    final visibleModules = filteredModules;

    if (visibleModules.isEmpty) {
      return emptyState(
        title: emptyFilterTitle,
        message: "Try another filter or view all training modules.",
        icon: Icons.filter_alt_off_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() => isLoading = true);
        await loadTrainingModules();
      },
      child: ListView.builder(
        controller: modulesScrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.zero,
        itemCount: visibleModules.length + (isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= visibleModules.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return moduleCard(visibleModules[index]);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : const AppBottomNavBar(currentPage: AppNavPage.training),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (isKeyboardOpen)
                const SizedBox(height: 12)
              else ...[
                _buildHeader(),
                const SizedBox(height: 24),
              ],

              _buildTypeFilters(),

              const SizedBox(height: 12),

              _buildSearchField(),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      activeModuleTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (hasActiveFilters) ...[
                    TextButton.icon(
                      onPressed: clearFilters,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text(
                        "Clear",
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    "${filteredModules.length}",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildSortMenu(),
                ],
              ),

              const SizedBox(height: 14),

              Expanded(child: _buildContent()),
            ],
          ),
        ),
      ),
    );
  }
}

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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 72,
                          width: 72,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(typeIcon(type), color: color, size: 38),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF111827),
                                  height: 1.12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
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
                      const SizedBox(height: 18),
                      _DetailSection(title: "Overview", text: description),
                    ],
                    if (content.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _DetailSection(title: "Details", text: content),
                    ],
                    if (description.isEmpty && content.isEmpty) ...[
                      const SizedBox(height: 18),
                      const _DetailSection(
                        title: "Details",
                        text:
                            "No additional training details are available yet.",
                      ),
                    ],
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Done",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _DetailMetaTile(
                label: "Time",
                value: duration == null ? "Open" : "$duration min",
                icon: Icons.timer_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DetailMetaTile(
          label: "Interest",
          value: interestType,
          icon: Icons.local_offer_outlined,
          color: const Color(0xFF0F766E),
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
        color: color.withValues(alpha: 0.09),
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
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
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
  final String title;
  final String text;

  const _DetailSection({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 14,
              height: 1.48,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
