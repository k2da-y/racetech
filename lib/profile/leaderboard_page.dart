import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/rank_data.dart';
import '../services/api_service.dart';
import '../utils/certificate_count.dart';
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

const _gold = Color(0xFFF59E0B);
const _goldSoft = Color(0xFFFFF7ED);
const _silver = Color(0xFFCBD5E1);
const _bronze = Color(0xFFD97706);

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
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
  );
}

Color _medalColor(int rank) {
  switch (rank) {
    case 1:
      return _gold;
    case 2:
      return _silver;
    case 3:
      return _bronze;
    default:
      return _primary;
  }
}

// Small view model so the build code stays readable. Values are read exactly
// the same way as before (rank → "rank" or index + 1, etc.).
class _Entry {
  final int rank;
  final String name;
  final int badges;
  final String rankTitle;
  final String avatarUrl;

  const _Entry({
    required this.rank,
    required this.name,
    required this.badges,
    required this.rankTitle,
    required this.avatarUrl,
  });

  factory _Entry.fromUser(Map<String, dynamic> user, int index) {
    final badges = certificateCountOrZero(user);
    return _Entry(
      rank: int.tryParse((user["rank"] ?? "").toString()) ?? index + 1,
      name: (user["name"] ?? "Unnamed User").toString(),
      badges: badges,
      rankTitle: rankTitleForBadges(badges),
      avatarUrl: (user["avatar_url"] ?? "").toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  bool isLoading = true;
  bool loadFailed = false;
  bool isFetching = false;
  List<Map<String, dynamic>> leaderboard = [];

  @override
  void initState() {
    super.initState();
    loadLeaderboard();
  }

  Future<void> loadLeaderboard() async {
    if (isFetching) return;
    isFetching = true;

    try {
      final data = await ApiService().getLeaderboard();

      if (!mounted) return;

      setState(() {
        leaderboard = data;
        isLoading = false;
        loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        loadFailed = true;
      });
    } finally {
      isFetching = false;
    }
  }

  /// Pull-to-refresh keeps the current list on screen while reloading.
  Future<void> refreshLeaderboard() async {
    if (leaderboard.isEmpty) {
      setState(() => isLoading = true);
    }
    await loadLeaderboard();
  }

  void openRankGuide() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          Theme(data: _brandTheme(context), child: const _RankGuideSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (var i = 0; i < leaderboard.length; i++)
        _Entry.fromUser(leaderboard[i], i),
    ];
    final podium = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <_Entry>[];
    final canPop = Navigator.canPop(context);

    return Theme(
      data: _brandTheme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          bottomNavigationBar: const AppBottomNavBar(
            currentPage: AppNavPage.leaderboard,
          ),
          body: RefreshIndicator(
            color: _primary,
            backgroundColor: Colors.white,
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: refreshLeaderboard,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(
                  child: _LeaderboardHero(
                    onBack: canPop ? () => Navigator.pop(context) : null,
                    onOpenRankGuide: openRankGuide,
                    isLoading: isLoading,
                    podium: podium,
                    totalUsers: entries.length,
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: _LeaderboardSummary(),
                  ),
                ),
                if (loadFailed && entries.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: _RefreshErrorBanner(onRetry: refreshLeaderboard),
                    ),
                  ),
                if (isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
                    sliver: SliverList.builder(
                      itemCount: 5,
                      itemBuilder: (context, index) => const _SkeletonCard(),
                    ),
                  )
                else if (entries.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: loadFailed
                        ? _StateCard(
                            icon: Icons.wifi_off_rounded,
                            iconColor: _danger,
                            iconBackground: _dangerSoft,
                            title: "Couldn't load leaderboard",
                            message: "Check your connection and try again.",
                            actionLabel: "Try again",
                            onAction: refreshLeaderboard,
                          )
                        : _StateCard(
                            icon: Icons.emoji_events_outlined,
                            iconColor: _gold,
                            iconBackground: _goldSoft,
                            title: "No leaderboard data yet",
                            message:
                                "Unlock E-Certificates from events to appear on the leaderboard.",
                            actionLabel: "Refresh",
                            onAction: refreshLeaderboard,
                          ),
                  )
                else ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                      child: Row(
                        children: [
                          Text(
                            rest.isEmpty ? "Top runners" : "Rankings",
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _CountBadge(count: entries.length),
                          const Spacer(),
                          const Text(
                            "By E-Certificates",
                            style: TextStyle(
                              color: _faint,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverList.builder(
                      // Top 3 are on the podium, but are listed again here
                      // compactly so every rank (and rank title) is visible.
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final entry = entries[index];
                        return _LeaderboardCard(entry: entry);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO + PODIUM
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardHero extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback onOpenRankGuide;
  final bool isLoading;
  final List<_Entry> podium;
  final int totalUsers;

  const _LeaderboardHero({
    required this.onBack,
    required this.onOpenRankGuide,
    required this.isLoading,
    required this.podium,
    required this.totalUsers,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final showPodium = isLoading || podium.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, showPodium ? 0 : 28),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: "Back",
                  onTap: onBack!,
                ),
              const Spacer(),
              _GlassButton(
                icon: Icons.info_outline_rounded,
                tooltip: "Rank guide",
                onTap: onOpenRankGuide,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Leaderboard",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      "Top users based on E-Certificates unlocked",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLoading && totalUsers > 0) ...[
            const SizedBox(height: 14),
            _HeroPill(
              icon: Icons.groups_rounded,
              label:
                  "$totalUsers ${totalUsers == 1 ? 'participant' : 'participants'} ranked",
            ),
          ],
          if (showPodium) ...[
            const SizedBox(height: 22),
            isLoading ? const _PodiumSkeleton() : _Podium(entries: podium),
          ],
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<_Entry> entries;

  const _Podium({required this.entries});

  @override
  Widget build(BuildContext context) {
    _Entry? at(int i) => i < entries.length ? entries[i] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: _PodiumSpot(entry: at(1), place: 2)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumSpot(entry: at(0), place: 1)),
        const SizedBox(width: 8),
        Expanded(child: _PodiumSpot(entry: at(2), place: 3)),
      ],
    );
  }
}

class _PodiumSpot extends StatelessWidget {
  final _Entry? entry;
  final int place;

  const _PodiumSpot({required this.entry, required this.place});

  @override
  Widget build(BuildContext context) {
    final isFirst = place == 1;
    final blockHeight = switch (place) {
      1 => 92.0,
      2 => 68.0,
      _ => 52.0,
    };
    final avatarSize = isFirst ? 72.0 : 58.0;
    final medal = _medalColor(entry?.rank ?? place);

    final block = Container(
      height: blockHeight,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: isFirst ? 0.30 : 0.22),
            Colors.white.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.4)),
        ),
      ),
      child: Text(
        "${entry?.rank ?? place}",
        style: TextStyle(
          color: Colors.white,
          fontSize: isFirst ? 34 : 26,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );

    if (entry == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: avatarSize,
            width: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.person_outline_rounded,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Open spot",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Opacity(opacity: 0.6, child: block),
        ],
      );
    }

    final e = entry!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: isFirst
              ? const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFFDE68A),
                  size: 24,
                )
              : null,
        ),
        const SizedBox(height: 4),
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            _UserAvatar(
              url: e.avatarUrl,
              name: e.name,
              size: avatarSize,
              ringColor: medal,
              ringWidth: 3,
              onDark: true,
            ),
            Positioned(
              bottom: -8,
              child: Container(
                height: 22,
                width: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: medal,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  "${e.rank}",
                  style: TextStyle(
                    color: e.rank == 2 ? _ink : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          e.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isFirst ? 14 : 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
              const SizedBox(width: 4),
              Text(
                "${e.badges}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        block,
      ],
    );
  }
}

class _PodiumSkeleton extends StatelessWidget {
  const _PodiumSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget spot(double avatar, double block) {
      final tone = Colors.white.withValues(alpha: 0.18);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: avatar,
            width: avatar,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Container(
            height: 12,
            width: 60,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: block,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
          ),
        ],
      );
    }

    return _Pulse(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: spot(58, 68)),
          const SizedBox(width: 8),
          Expanded(child: spot(72, 92)),
          const SizedBox(width: 8),
          Expanded(child: spot(58, 52)),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            width: 42,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUMMARY + LIST
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderboardSummary extends StatelessWidget {
  const _LeaderboardSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: _goldSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: _gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Compare progress with other participants while your E-Certificates stay personal on the E-Certificates page.",
              style: TextStyle(
                color: _body,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardCard extends StatelessWidget {
  final _Entry entry;

  const _LeaderboardCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    final isTop3 = rank <= 3;
    final medal = _medalColor(rank);
    final badges = entry.badges;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
        border: isTop3
            ? Border.all(color: medal.withValues(alpha: 0.45), width: 1.4)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isTop3 ? medal.withValues(alpha: 0.15) : _fieldFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isTop3 ? medal.withValues(alpha: 0.35) : _border,
              ),
            ),
            child: Text(
              "$rank",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isTop3 ? (rank == 2 ? _muted : medal) : _body,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          _UserAvatar(
            url: entry.avatarUrl,
            name: entry.name,
            size: 50,
            ringColor: isTop3 ? medal : const Color(0xFFE0E7FF),
            ringWidth: 2.5,
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  "$badges E-Certificate${badges == 1 ? "" : "s"} unlocked",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                _RankTitlePill(title: entry.rankTitle),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Trailing
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: isTop3 ? medal.withValues(alpha: 0.12) : _primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isTop3
                  ? Icons.workspace_premium_rounded
                  : Icons.trending_up_rounded,
              color: isTop3 ? (rank == 2 ? _faint : medal) : _primary,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  final Color ringColor;
  final double ringWidth;
  final bool onDark;

  const _UserAvatar({
    required this.url,
    required this.name,
    required this.size,
    required this.ringColor,
    this.ringWidth = 2,
    this.onDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? "?" : trimmed[0].toUpperCase();

    Widget fallback() => Container(
      color: onDark ? Colors.white.withValues(alpha: 0.18) : _primarySoft,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: onDark ? Colors.white : _primary,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return Container(
      height: size,
      width: size,
      padding: EdgeInsets.all(ringWidth),
      decoration: BoxDecoration(color: ringColor, shape: BoxShape.circle),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: onDark ? _primaryDeep : Colors.white,
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: url.isEmpty
              ? fallback()
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  errorBuilder: (context, error, stackTrace) => fallback(),
                ),
        ),
      ),
    );
  }
}

class _RankTitlePill extends StatelessWidget {
  final String title;

  const _RankTitlePill({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.military_tech_rounded, size: 13, color: _primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
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

// ─────────────────────────────────────────────────────────────────────────────
// RANK GUIDE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _RankGuideSheet extends StatelessWidget {
  const _RankGuideSheet();

  @override
  Widget build(BuildContext context) {
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    height: 50,
                    width: 50,
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
                    child: const Icon(
                      Icons.military_tech_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Rank Guide",
                          style: TextStyle(
                            color: _ink,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "Unlock E-Certificates to climb through each Racetech rank.",
                          style: TextStyle(
                            color: _muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < rankTiers.length; index++)
                _RankGuideRow(
                  tier: rankTiers[index],
                  level: index + 1,
                  isLast: index == rankTiers.length - 1,
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
  final int level;
  final bool isLast;

  const _RankGuideRow({
    required this.tier,
    required this.level,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final isUltimate = tier.badges == null;
    final tone = isUltimate ? _gold : _primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline rail
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    color: isUltimate ? _goldSoft : _primarySoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: tone.withValues(alpha: 0.25)),
                  ),
                  child: Icon(
                    isUltimate
                        ? Icons.workspace_premium_rounded
                        : Icons.military_tech_rounded,
                    color: tone,
                    size: 19,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isUltimate ? _goldSoft : _fieldFill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isUltimate ? _gold.withValues(alpha: 0.3) : _border,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "LEVEL $level",
                            style: TextStyle(
                              color: tone,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tier.title,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: _border),
                      ),
                      child: Text(
                        tier.requirement,
                        style: const TextStyle(
                          color: _body,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING / EMPTY / ERROR
// ─────────────────────────────────────────────────────────────────────────────

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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: _Pulse(
        child: Row(
          children: [
            block(34, 34, 12),
            const SizedBox(width: 12),
            block(50, 50, 99),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  block(14, 140, 8),
                  const SizedBox(height: 7),
                  block(11, 110, 8),
                  const SizedBox(height: 8),
                  block(18, 90, 99),
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
  final Future<void> Function() onAction;

  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 24),
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
                icon: const Icon(Icons.refresh_rounded, size: 19),
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
              "Couldn't refresh. Showing the last loaded rankings.",
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
