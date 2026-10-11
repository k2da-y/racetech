import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
const _gold = Color(0xFFF59E0B);
const _goldSoft = Color(0xFFFFF7ED);
const _goldBorder = Color(0xFFFED7AA);
const _success = Color(0xFF16A34A);
const _successSoft = Color(0xFFDCFCE7);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

enum _BadgeFilter { all, earned, locked }

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  bool isLoadingBadges = true;
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> issuedBadges = [];
  _BadgeFilter filter = _BadgeFilter.all;

  @override
  void initState() {
    super.initState();
    loadAchievements();
  }

  // ============================================================
  // DATA — logic unchanged
  // ============================================================

  Future<void> loadAchievements() async {
    final data = await ApiService().getAchievementData();

    if (!mounted) return;

    setState(() {
      achievements = data.achievements;
      issuedBadges = data.issuedBadges;
      isLoadingBadges = false;
    });
  }

  Future<void> refreshAchievements() async {
    setState(() => isLoadingBadges = true);
    await loadAchievements();
  }

  List<Map<String, dynamic>> get badgeCollection {
    return achievements.map((achievement) {
      final issuedBadge = issuedBadgeForAchievement(achievement);
      return {
        ...achievement,
        if (issuedBadge != null) ...issuedBadge,
        "unlocked": issuedBadge != null || achievement["unlocked"] == true,
        "issued_badge": issuedBadge,
      };
    }).toList();
  }

  Map<String, dynamic>? issuedBadgeForAchievement(
      Map<String, dynamic> achievement,
      ) {
    final achievementId = badgeKey(
      achievement["id"] ?? achievement["achievement_id"],
    );
    final title = badgeTitle(achievement).trim().toLowerCase();

    for (final badge in issuedBadges) {
      final badgeAchievementId = badgeKey(badge["achievement_id"]);
      final badgeTitleValue = badgeTitle(badge).trim().toLowerCase();

      if (achievementId.isNotEmpty && achievementId == badgeAchievementId) {
        return badge;
      }

      if (title.isNotEmpty && title == badgeTitleValue) {
        return badge;
      }
    }

    return null;
  }

  String badgeKey(dynamic value) {
    if (value == null) return "";
    final key = value.toString();
    return key == "null" ? "" : key;
  }

  String badgeTitle(Map<String, dynamic> badge) {
    return (badge["title"] ?? badge["name"] ?? "E-Certificate").toString();
  }

  String badgeDescription(Map<String, dynamic> badge) {
    return (badge["description"] ?? badge["desc"] ?? badge["criteria"] ?? "")
        .toString();
  }

  String badgeRuleLabel(Map<String, dynamic> badge) {
    return ruleLabelFromBadge(badge);
  }

  int badgeProgress(Map<String, dynamic> badge) {
    return int.tryParse((badge["progress"] ?? 0).toString()) ?? 0;
  }

  int badgeTarget(Map<String, dynamic> badge) {
    return int.tryParse((badge["target"] ?? 0).toString()) ?? 0;
  }

  String formatIssuedDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return "";

    final local = parsed.toLocal();
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];

    return "Issued ${months[local.month - 1]} ${local.day}, ${local.year}";
  }

  void openBadgeDetails(Map<String, dynamic> badge, {required bool isUnlocked}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _IssuedBadgeDetailsSheet(
        badge: badge,
        isUnlocked: isUnlocked,
        formatIssuedDate: formatIssuedDate,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final badges = isLoadingBadges
        ? const <Map<String, dynamic>>[]
        : badgeCollection;
    final earned = badges.where((badge) => badge["unlocked"] == true).toList();
    final locked = badges.where((badge) => badge["unlocked"] != true).toList();
    final visible = switch (filter) {
      _BadgeFilter.all => badges,
      _BadgeFilter.earned => earned,
      _BadgeFilter.locked => locked,
    };

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: RefreshIndicator(
          color: _primary,
          onRefresh: refreshAchievements,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _BadgesHero(
                  isLoading: isLoadingBadges,
                  earnedCount: earned.length,
                  totalCount: badges.length,
                  onBack: () => Navigator.pop(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: isLoadingBadges
                          ? const _LoadingList()
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (badges.isNotEmpty) ...[
                            _FilterTabs(
                              selected: filter,
                              allCount: badges.length,
                              earnedCount: earned.length,
                              lockedCount: locked.length,
                              onChanged: (value) =>
                                  setState(() => filter = value),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (badges.isEmpty)
                            const _EmptyState(
                              icon: Icons.workspace_premium_outlined,
                              title: "No E-Certificates available yet",
                              message:
                              "Admin-issued E-Certificates will appear here once available.",
                            )
                          else if (visible.isEmpty)
                            _EmptyState(
                              icon: filter == _BadgeFilter.earned
                                  ? Icons.emoji_events_outlined
                                  : Icons.celebration_outlined,
                              title: filter == _BadgeFilter.earned
                                  ? "No E-Certificates earned yet"
                                  : "You've unlocked everything!",
                              message: filter == _BadgeFilter.earned
                                  ? "Join and finish events to start earning them."
                                  : "Every available E-Certificate is already yours.",
                            )
                          else
                            ...visible.map(badgeCard),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget badgeCard(Map<String, dynamic> badge) {
    final isUnlocked = badge["unlocked"] == true;
    final issuedBadge = badge["issued_badge"] is Map
        ? Map<String, dynamic>.from(badge["issued_badge"])
        : <String, dynamic>{};
    final displayBadge = isUnlocked && issuedBadge.isNotEmpty
        ? {...badge, ...issuedBadge}
        : badge;
    final eventData = displayBadge["event"];
    final event = eventData is Map
        ? Map<String, dynamic>.from(eventData)
        : <String, dynamic>{};
    final imageUrl = (displayBadge["image_url"] ?? "").toString();
    final icon = displayBadge["icon"] is IconData
        ? displayBadge["icon"] as IconData
        : null;
    final eventTitle = (event["title"] ?? "").toString();
    final criteria = badgeRuleLabel(displayBadge);
    final description = badgeDescription(displayBadge);
    final issuedAt = formatIssuedDate(
      (displayBadge["issued_at"] ?? "").toString(),
    );
    final progress = badgeProgress(badge);
    final target = badgeTarget(badge);
    final hasProgress = !isUnlocked && target > 0;
    final progressValue = hasProgress
        ? (progress / target).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: isUnlocked ? _softShadow : null,
        ),
        child: Material(
          color: isUnlocked ? Colors.white : _fieldFill,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: () => openBadgeDetails(displayBadge, isUnlocked: isUnlocked),
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isUnlocked ? Colors.transparent : _border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _IssuedBadgeImage(
                    imageUrl: imageUrl,
                    icon: icon,
                    locked: !isUnlocked,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StatusLabel(unlocked: isUnlocked),
                        const SizedBox(height: 5),
                        Text(
                          badgeTitle(displayBadge),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w900,
                            height: 1.2,
                            color: isUnlocked ? _ink : _muted,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: _body,
                              height: 1.35,
                            ),
                          ),
                        ],
                        if (isUnlocked &&
                            (criteria.isNotEmpty ||
                                eventTitle.isNotEmpty ||
                                issuedAt.isNotEmpty)) ...[
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (issuedAt.isNotEmpty)
                                _BadgeMetaPill(
                                  icon: Icons.verified_outlined,
                                  label: issuedAt,
                                  highlighted: true,
                                ),
                              if (eventTitle.isNotEmpty)
                                _BadgeMetaPill(
                                  icon: Icons.event_outlined,
                                  label: eventTitle,
                                ),
                              if (criteria.isNotEmpty)
                                _BadgeMetaPill(
                                  icon: Icons.rule_outlined,
                                  label: criteria,
                                ),
                            ],
                          ),
                        ],
                        if (hasProgress) ...[
                          const SizedBox(height: 10),
                          _ProgressBar(value: progressValue),
                          const SizedBox(height: 6),
                          Text(
                            "$progress of $target completed",
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded, color: _faint),
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
// HERO HEADER
// ============================================================

class _BadgesHero extends StatelessWidget {
  final bool isLoading;
  final int earnedCount;
  final int totalCount;
  final VoidCallback onBack;

  const _BadgesHero({
    required this.isLoading,
    required this.earnedCount,
    required this.totalCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final progress = totalCount == 0 ? 0.0 : earnedCount / totalCount;

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
                    onTap: onBack,
                  ),
                  const Expanded(
                    child: Text(
                      "E-Certificates",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
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
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    isLoading ? "–" : "$earnedCount",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  if (!isLoading && totalCount > 0)
                    Text(
                      " / $totalCount",
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                "Official E-Certificates earned",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (!isLoading && totalCount > 0) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Collection progress",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            "${(progress * 100).round()}%",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: progress),
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 7,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.2,
                                ),
                                color: Colors.white,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
// FILTER TABS
// ============================================================

class _FilterTabs extends StatelessWidget {
  final _BadgeFilter selected;
  final int allCount;
  final int earnedCount;
  final int lockedCount;
  final ValueChanged<_BadgeFilter> onChanged;

  const _FilterTabs({
    required this.selected,
    required this.allCount,
    required this.earnedCount,
    required this.lockedCount,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      (_BadgeFilter.all, "All", allCount),
      (_BadgeFilter.earned, "Earned", earnedCount),
      (_BadgeFilter.locked, "Locked", lockedCount),
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
      ),
      child: Row(
        children: [
          for (final (value, label, count) in tabs)
            Expanded(
              child: Semantics(
                button: true,
                selected: selected == value,
                child: GestureDetector(
                  onTap: () => onChanged(value),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selected == value ? _primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: selected == value ? Colors.white : _body,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: selected == value
                                ? Colors.white.withValues(alpha: 0.22)
                                : _primarySoft,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            "$count",
                            style: TextStyle(
                              color: selected == value
                                  ? Colors.white
                                  : _primaryDeep,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// BADGE PIECES
// ============================================================

class _StatusLabel extends StatelessWidget {
  final bool unlocked;

  const _StatusLabel({required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: unlocked ? _successSoft : _border,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            unlocked ? Icons.check_circle_rounded : Icons.lock_outline_rounded,
            size: 12,
            color: unlocked ? _success : _muted,
          ),
          const SizedBox(width: 4),
          Text(
            unlocked ? "Earned" : "Locked",
            style: TextStyle(
              color: unlocked ? _success : _muted,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double value;
  final double height;

  const _ProgressBar({required this.value, this.height = 7});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          minHeight: height,
          value: animated,
          backgroundColor: _border,
          color: _primary,
        ),
      ),
    );
  }
}

class _IssuedBadgeImage extends StatelessWidget {
  final String imageUrl;
  final IconData? icon;
  final bool locked;
  final double size;
  final double radius;
  final double iconSize;

  const _IssuedBadgeImage({
    required this.imageUrl,
    this.icon,
    this.locked = false,
    this.size = 70,
    this.radius = 20,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: locked ? _border : _goldSoft,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: locked ? const Color(0xFFCBD5E1) : _goldBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: _BadgeImageContent(
        imageUrl: imageUrl,
        icon: icon,
        locked: locked,
        iconSize: iconSize,
      ),
    );

    if (!locked) return badge;

    return Stack(
      children: [
        badge,
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
        Positioned(
          right: size * 0.08,
          bottom: size * 0.08,
          child: Container(
            height: size * 0.32,
            width: size * 0.32,
            decoration: const BoxDecoration(
              color: _muted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_outline_rounded,
              color: Colors.white,
              size: size * 0.18,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeImageContent extends StatelessWidget {
  final String imageUrl;
  final IconData? icon;
  final bool locked;
  final double iconSize;

  const _BadgeImageContent({
    required this.imageUrl,
    this.icon,
    required this.locked,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      locked
          ? Icons.lock_outline_rounded
          : icon ?? Icons.workspace_premium_outlined,
      color: locked ? _muted : _gold,
      size: iconSize,
    );

    if (imageUrl.isEmpty) {
      return Center(child: fallback);
    }

    final image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) =>
      progress == null ? child : Center(child: fallback),
      errorBuilder: (context, error, stackTrace) => Center(child: fallback),
    );

    if (!locked) {
      return image;
    }

    return ColorFiltered(
      colorFilter: const ColorFilter.mode(
        Color(0xFFCBD5E1),
        BlendMode.saturation,
      ),
      child: image,
    );
  }
}

class _BadgeMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;

  const _BadgeMetaPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 64;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: highlighted ? _primarySoft : _fieldFill,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: highlighted ? Colors.transparent : _border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: highlighted ? _primary : _muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: highlighted ? _primaryDeep : _body,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String ruleLabelFromBadge(Map<String, dynamic> badge) {
  return (badge["auto_issue_rule_label"] ??
      badge["autoIssueRuleLabel"] ??
      badge["rule_label"] ??
      badge["ruleLabel"] ??
      badge["criteria"] ??
      "")
      .toString()
      .trim();
}

// ============================================================
// DETAILS SHEET
// ============================================================

class _IssuedBadgeDetailsSheet extends StatelessWidget {
  final Map<String, dynamic> badge;
  final bool isUnlocked;
  final String Function(String value) formatIssuedDate;

  const _IssuedBadgeDetailsSheet({
    required this.badge,
    required this.isUnlocked,
    required this.formatIssuedDate,
  });

  @override
  Widget build(BuildContext context) {
    final eventData = badge["event"];
    final categoryData = badge["category"];
    final event = eventData is Map
        ? Map<String, dynamic>.from(eventData)
        : <String, dynamic>{};
    final category = categoryData is Map
        ? Map<String, dynamic>.from(categoryData)
        : <String, dynamic>{};
    final imageUrl = (badge["image_url"] ?? "").toString();
    final icon = badge["icon"] is IconData ? badge["icon"] as IconData : null;
    final title = (badge["title"] ?? badge["name"] ?? "E-Certificate")
        .toString();
    final description =
    (badge["description"] ?? badge["desc"] ?? badge["criteria"] ?? "")
        .toString();
    final criteria = ruleLabelFromBadge(badge);
    final eventTitle = (event["title"] ?? "").toString();
    final categoryName = (category["name"] ?? "").toString();
    final notes = (badge["notes"] ?? "").toString();
    final issuedAt = formatIssuedDate((badge["issued_at"] ?? "").toString());
    final progress = int.tryParse((badge["progress"] ?? 0).toString()) ?? 0;
    final target = int.tryParse((badge["target"] ?? 0).toString()) ?? 0;
    final hasProgress = !isUnlocked && target > 0;

    final details = <(IconData, String, String)>[
      if (eventTitle.isNotEmpty) (Icons.event_outlined, "Event", eventTitle),
      if (categoryName.isNotEmpty)
        (Icons.flag_outlined, "Category", categoryName),
      if (criteria.isNotEmpty) (Icons.rule_outlined, "Earned for", criteria),
    ];

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: isUnlocked
                                ? const RadialGradient(
                              colors: [Color(0x33F59E0B), Color(0x00F59E0B)],
                            )
                                : null,
                          ),
                          child: _IssuedBadgeImage(
                            imageUrl: imageUrl,
                            icon: icon,
                            locked: !isUnlocked,
                            size: 150,
                            radius: 36,
                            iconSize: 72,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(child: _StatusLabel(unlocked: isUnlocked)),
                      const SizedBox(height: 12),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (isUnlocked && issuedAt.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          issuedAt,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _primaryDeep,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _body,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      if (isUnlocked && details.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _fieldFill,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _border),
                          ),
                          child: Column(
                            children: [
                              for (final (index, item) in details.indexed) ...[
                                if (index > 0)
                                  const Divider(height: 1, color: _border),
                                _DetailRow(
                                  icon: item.$1,
                                  label: item.$2,
                                  value: item.$3,
                                ),
                              ],
                            ],
                          ),
                        )
                      else if (!isUnlocked)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _primarySoft,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    color: _primaryDeep,
                                    size: 18,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    "How to unlock",
                                    style: TextStyle(
                                      color: _primaryDeep,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              Text(
                                criteria.isNotEmpty
                                    ? criteria
                                    : description.isNotEmpty
                                    ? description
                                    : "Complete the required event achievement to unlock this E-Certificate.",
                                style: const TextStyle(
                                  color: _body,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                              if (hasProgress) ...[
                                const SizedBox(height: 12),
                                _ProgressBar(
                                  value: (progress / target).clamp(0.0, 1.0),
                                  height: 8,
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  "$progress of $target completed",
                                  style: const TextStyle(
                                    color: _muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (notes.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _fieldFill,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: _border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.notes_outlined,
                                color: _muted,
                                size: 18,
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  notes,
                                  style: const TextStyle(
                                    color: _body,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
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
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _primary),
          const SizedBox(width: 10),
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// EMPTY + LOADING
// ============================================================

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: _primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatefulWidget {
  const _LoadingList();

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
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

  Widget block({double? width, required double height, double radius = 8}) {
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
    final content = Column(
      children: [
        block(height: 50, radius: 18),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _softShadow,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(width: 70, height: 70, radius: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      block(width: 60, height: 16, radius: 99),
                      const SizedBox(height: 8),
                      block(width: double.infinity, height: 16),
                      const SizedBox(height: 8),
                      block(width: 160, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}