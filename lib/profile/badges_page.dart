import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  int selectedTab = 0;
  bool isLoadingBadges = true;
  bool isLoadingLeaderboard = true;
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> leaderboard = [];

  @override
  void initState() {
    super.initState();
    loadAchievements();
    loadLeaderboard();
  }

  Future<void> loadAchievements() async {
    final data = await ApiService().getAchievements();

    if (!mounted) return;

    setState(() {
      achievements = data;
      isLoadingBadges = false;
    });
  }

  Future<void> loadLeaderboard() async {
    final data = await ApiService().getLeaderboard();

    if (!mounted) return;

    setState(() {
      leaderboard = data;
      isLoadingLeaderboard = false;
    });
  }

  IconData achievementIcon(String key) {
    switch (key) {
      case "first_event":
        return Icons.flag_outlined;
      case "explorer":
        return Icons.explore_outlined;
      case "consistent_athlete":
        return Icons.directions_run_outlined;
      case "early_bird":
        return Icons.wb_twilight_outlined;
      case "social_athlete":
        return Icons.forum_outlined;
      case "champion":
        return Icons.emoji_events_outlined;
      default:
        return Icons.military_tech_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlockedCount = achievements
        .where((item) => item["unlocked"] == true)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 12),

              // TOP TABS
              Container(
                height: 48,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildTab(title: "Badges", index: 0),
                    _buildTab(title: "Leaderboard", index: 1),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              Expanded(
                child: selectedTab == 0
                    ? _buildBadgesContent(unlockedCount)
                    : _buildLeaderboardContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab({required String title, required int index}) {
    final bool isActive = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            selectedTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFEAF2FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesContent(int unlockedCount) {
    if (isLoadingBadges) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        const SizedBox(height: 8),

        Text(
          "$unlockedCount",
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            height: 1,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "Badges Unlocked",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),

        const SizedBox(height: 40),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              "All Achievements",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              "See All",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2563EB),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Expanded(
          child: achievements.isEmpty
              ? const Center(child: Text("No achievements found"))
              : ListView.builder(
                  itemCount: achievements.length,
                  itemBuilder: (context, index) {
                    final item = achievements[index];

                    final bool unlocked = item["unlocked"] == true;
                    final int progress = unlocked ? 1 : 0;
                    const int target = 1;
                    final double percentage = target == 0
                        ? 0
                        : progress / target;

                    return _buildAchievementCard(
                      title: (item["title"] ?? "").toString(),
                      desc: (item["description"] ?? "").toString(),
                      icon: achievementIcon((item["key"] ?? "").toString()),
                      progress: progress,
                      target: target,
                      percentage: percentage,
                      unlocked: unlocked,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildAchievementCard({
    required String title,
    required String desc,
    required IconData icon,
    required int progress,
    required int target,
    required double percentage,
    required bool unlocked,
  }) {
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
      child: Row(
        children: [
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              unlocked ? icon : Icons.lock_outline,
              color: unlocked
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF64748B),
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          SizedBox(
            height: 54,
            width: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 54,
                  width: 54,
                  child: CircularProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    strokeWidth: 5,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      unlocked
                          ? const Color(0xFF22C55E)
                          : const Color(0xFF2563EB),
                    ),
                  ),
                ),
                Text(
                  "$progress/$target",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderboardContent() {
    return Column(
      children: [
        const SizedBox(height: 6),

        const Text(
          "Leaderboard",
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          "Top users based on badges unlocked",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),

        const SizedBox(height: 24),

        Expanded(
          child: isLoadingLeaderboard
              ? const Center(child: CircularProgressIndicator())
              : leaderboard.isEmpty
              ? const Center(child: Text("No leaderboard data yet"))
              : RefreshIndicator(
                  onRefresh: () async {
                    setState(() => isLoadingLeaderboard = true);
                    await loadLeaderboard();
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: leaderboard.length,
                    itemBuilder: (context, index) {
                      final user = leaderboard[index];

                      return _buildLeaderboardCard(
                        rank:
                            int.tryParse((user["rank"] ?? "").toString()) ??
                            index + 1,
                        name: (user["name"] ?? "Unnamed User").toString(),
                        badges:
                            int.tryParse(
                              (user["badges_count"] ?? "").toString(),
                            ) ??
                            0,
                        avatarUrl: (user["avatar_url"] ?? "").toString(),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardCard({
    required int rank,
    required String name,
    required int badges,
    required String avatarUrl,
  }) {
    final bool isTopOne = rank == 1;
    final bool isTopTwo = rank == 2;
    final bool isTopThree = rank == 3;

    Color cardColor = Colors.white;
    Color rankColor = const Color(0xFF2563EB);
    Color avatarColor = const Color(0xFFEAF2FF);

    if (isTopOne) {
      cardColor = const Color(0xFF2563EB);
      rankColor = Colors.white;
      avatarColor = Colors.white.withValues(alpha: 0.18);
    } else if (isTopTwo) {
      cardColor = const Color(0xFFFFFFFF);
      rankColor = const Color(0xFF2563EB);
      avatarColor = const Color(0xFFEAF2FF);
    } else if (isTopThree) {
      cardColor = const Color(0xFFFFFFFF);
      rankColor = const Color(0xFF2563EB);
      avatarColor = const Color(0xFFEAF2FF);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // RANK NUMBER
          Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTopOne
                  ? Colors.white.withValues(alpha: 0.20)
                  : const Color(0xFFEAF2FF),
            ),
            child: Text(
              "$rank",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: rankColor,
              ),
            ),
          ),

          const SizedBox(width: 10),

          // AVATAR
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
              border: Border.all(
                color: isTopOne
                    ? Colors.white.withValues(alpha: 0.45)
                    : const Color(0xFFD8E7FF),
                width: 3,
              ),
            ),
            child: avatarUrl.isEmpty
                ? Icon(
                    Icons.person_outline,
                    color: isTopOne ? Colors.white : const Color(0xFF2563EB),
                    size: 31,
                  )
                : ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person_outline,
                        color: isTopOne
                            ? Colors.white
                            : const Color(0xFF2563EB),
                        size: 31,
                      ),
                    ),
                  ),
          ),

          const SizedBox(width: 14),

          // NAME
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isTopOne ? Colors.white : const Color(0xFF111827),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // BADGE COUNT
          Text(
            "$badges badges",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isTopOne ? Colors.white : const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
