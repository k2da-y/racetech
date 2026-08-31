import 'package:flutter/material.dart';

import '../data/rank_data.dart';
import '../services/api_service.dart';
import '../widgets/bottom_nav_bar.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> leaderboard = [];

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    final data = await ApiService().getLeaderboard();

    if (!mounted) return;

    setState(() {
      leaderboard = data;
      isLoading = false;
    });
  }

  Future<void> refreshLeaderboard() async {
    setState(() => isLoading = true);
    await loadLeaderboard();
  }

  void openRankGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (_) => const _RankGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      bottomNavigationBar: const AppBottomNavBar(
        currentPage: AppNavPage.leaderboard,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _LeaderboardHeader(
                onBack: () => Navigator.pop(context),
                onOpenRankGuide: openRankGuide,
              ),
              const SizedBox(height: 18),
              const _LeaderboardSummary(),
              const SizedBox(height: 18),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : leaderboard.isEmpty
                    ? const _EmptyLeaderboard()
                    : RefreshIndicator(
                        onRefresh: refreshLeaderboard,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          itemCount: leaderboard.length,
                          itemBuilder: (context, index) {
                            final user = leaderboard[index];
                            final badges =
                                int.tryParse(
                                  (user["badges_count"] ?? "").toString(),
                                ) ??
                                0;

                            return _LeaderboardCard(
                              rank:
                                  int.tryParse(
                                    (user["rank"] ?? "").toString(),
                                  ) ??
                                  index + 1,
                              name: (user["name"] ?? "Unnamed User").toString(),
                              badges: badges,
                              rankTitle: rankTitleForBadges(badges),
                              avatarUrl: (user["avatar_url"] ?? "").toString(),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onOpenRankGuide;

  const _LeaderboardHeader({
    required this.onBack,
    required this.onOpenRankGuide,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2563EB),
          ),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Leaderboard",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Top users based on badges unlocked",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton.filledTonal(
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF2563EB),
          ),
          onPressed: onOpenRankGuide,
          icon: const Icon(Icons.info_outline),
        ),
      ],
    );
  }
}

class _LeaderboardSummary extends StatelessWidget {
  const _LeaderboardSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: const Row(
        children: [
          Icon(Icons.emoji_events_outlined, color: Color(0xFFF59E0B), size: 34),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Compare progress with other participants while your badges stay personal on the Badges page.",
              style: TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final int rank;
  final String name;
  final int badges;
  final String rankTitle;
  final String avatarUrl;

  const _LeaderboardCard({
    required this.rank,
    required this.name,
    required this.badges,
    required this.rankTitle,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isTopOne = rank == 1;
    final cardColor = isTopOne ? const Color(0xFF2563EB) : Colors.white;
    final foreground = isTopOne ? Colors.white : const Color(0xFF111827);
    final muted = isTopOne ? Colors.white70 : const Color(0xFF64748B);

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
          Container(
            height: 30,
            width: 30,
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
                color: isTopOne ? Colors.white : const Color(0xFF2563EB),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 58,
            width: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isTopOne
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0xFFEAF2FF),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$badges badge${badges == 1 ? "" : "s"} unlocked",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                _RankTitlePill(title: rankTitle, isTopOne: isTopOne),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            rank <= 3 ? Icons.workspace_premium : Icons.trending_up,
            color: isTopOne ? Colors.white : const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _RankTitlePill extends StatelessWidget {
  final String title;
  final bool isTopOne;

  const _RankTitlePill({required this.title, required this.isTopOne});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isTopOne
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 13,
            color: isTopOne ? Colors.white : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isTopOne ? Colors.white : const Color(0xFF2563EB),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankGuideSheet extends StatelessWidget {
  const _RankGuideSheet();

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Rank Guide",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Unlock E-Badges to climb through each Racetech rank.",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < rankTiers.length; index++) ...[
                      _RankGuideRow(tier: rankTiers[index]),
                      if (index != rankTiers.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE2E8F0),
                        ),
                    ],
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

class _RankGuideRow extends StatelessWidget {
  final RankTier tier;

  const _RankGuideRow({required this.tier});

  @override
  Widget build(BuildContext context) {
    final isUltimate = tier.badges == null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            decoration: BoxDecoration(
              color: isUltimate
                  ? const Color(0xFFFFF7ED)
                  : const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isUltimate
                  ? Icons.workspace_premium_outlined
                  : Icons.military_tech_outlined,
              color: isUltimate
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF2563EB),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tier.title,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            tier.requirement,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLeaderboard extends StatelessWidget {
  const _EmptyLeaderboard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "No leaderboard data yet",
        style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
      ),
    );
  }
}
