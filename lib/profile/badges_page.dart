import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BadgesPage extends StatefulWidget {
  const BadgesPage({super.key});

  @override
  State<BadgesPage> createState() => _BadgesPageState();
}

class _BadgesPageState extends State<BadgesPage> {
  bool isLoadingBadges = true;
  List<Map<String, dynamic>> achievements = [];
  List<Map<String, dynamic>> issuedBadges = [];

  @override
  void initState() {
    super.initState();
    loadAchievements();
  }

  Future<void> loadAchievements() async {
    final data = await ApiService().getAchievementData();

    if (!mounted) return;

    setState(() {
      achievements = data.achievements;
      issuedBadges = data.issuedBadges;
      isLoadingBadges = false;
    });
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
    return (badge["title"] ?? badge["name"] ?? "E-Badge").toString();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEFF3F9),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 14),
              _BadgesHeader(onBack: () => Navigator.pop(context)),
              const SizedBox(height: 26),
              Expanded(child: _buildBadgesContent()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgesContent() {
    if (isLoadingBadges) {
      return const Center(child: CircularProgressIndicator());
    }

    final badges = badgeCollection;
    final earnedCount = badges
        .where((badge) => badge["unlocked"] == true)
        .length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        const SizedBox(height: 8),

        Text(
          "$earnedCount",
          style: const TextStyle(
            fontSize: 64,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
            height: 1,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          badges.isEmpty
              ? "E-Badges Earned"
              : "E-Badges Earned of ${badges.length}",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B5563),
          ),
        ),

        const SizedBox(height: 30),

        _SectionHeader(
          title: "E-Badge Collection",
          trailing: "$earnedCount/${badges.length}",
        ),

        const SizedBox(height: 14),

        if (badges.isEmpty)
          const _EmptyIssuedBadgesCard()
        else
          ...badges.map(_buildBadgeCollectionCard),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildBadgeCollectionCard(Map<String, dynamic> badge) {
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
      child: Material(
        color: isUnlocked ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () => openBadgeDetails(displayBadge, isUnlocked: isUnlocked),
          borderRadius: BorderRadius.circular(22),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isUnlocked
                    ? Colors.transparent
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
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
                      Text(
                        badgeTitle(displayBadge),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isUnlocked
                              ? const Color(0xFF111827)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ],
                      if (isUnlocked &&
                          (criteria.isNotEmpty ||
                              eventTitle.isNotEmpty ||
                              issuedAt.isNotEmpty)) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (criteria.isNotEmpty)
                              _BadgeMetaPill(
                                icon: Icons.rule_outlined,
                                label: criteria,
                              ),
                            if (eventTitle.isNotEmpty)
                              _BadgeMetaPill(
                                icon: Icons.event_outlined,
                                label: eventTitle,
                              ),
                            if (issuedAt.isNotEmpty)
                              _BadgeMetaPill(
                                icon: Icons.verified_outlined,
                                label: issuedAt,
                              ),
                          ],
                        ),
                      ],
                      if (!isUnlocked) ...[
                        const SizedBox(height: 10),
                        if (hasProgress) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              minHeight: 7,
                              value: progressValue,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "$progress/$target progress",
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ] else
                          const _LockedBadgePill(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void openBadgeDetails(
    Map<String, dynamic> badge, {
    required bool isUnlocked,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => _IssuedBadgeDetailsSheet(
        badge: badge,
        isUnlocked: isUnlocked,
        formatIssuedDate: formatIssuedDate,
      ),
    );
  }

  String formatIssuedDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return "";

    final local = parsed.toLocal();
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "Issued ${months[local.month - 1]} ${local.day}, ${local.year}";
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String trailing;

  const _SectionHeader({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2FF),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
      ],
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
    this.size = 68,
    this.radius = 18,
    this.iconSize = 34,
  });

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFE2E8F0) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: locked ? const Color(0xFFCBD5E1) : const Color(0xFFFED7AA),
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
          right: 6,
          bottom: 6,
          child: Container(
            height: 22,
            width: 22,
            decoration: const BoxDecoration(
              color: Color(0xFF64748B),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 13,
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
      locked ? Icons.lock_outline : icon ?? Icons.workspace_premium_outlined,
      color: locked ? const Color(0xFF64748B) : const Color(0xFFF59E0B),
      size: iconSize,
    );

    if (imageUrl.isEmpty) {
      return fallback;
    }

    final image = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
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

class _LockedBadgePill extends StatelessWidget {
  const _LockedBadgePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 13, color: Color(0xFF64748B)),
          SizedBox(width: 5),
          Text(
            "Locked",
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _BadgeMetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width - 64;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 13, color: const Color(0xFF64748B)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
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
    final title = (badge["title"] ?? badge["name"] ?? "E-Badge").toString();
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(
                      child: _IssuedBadgeImage(
                        imageUrl: imageUrl,
                        icon: icon,
                        locked: !isUnlocked,
                        size: 150,
                        radius: 34,
                        iconSize: 72,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: isUnlocked
                          ? _BadgeMetaPill(
                              icon: Icons.verified_outlined,
                              label: issuedAt.isEmpty ? "Unlocked" : issuedAt,
                            )
                          : const _LockedBadgePill(),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        description,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    if (isUnlocked)
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (criteria.isNotEmpty)
                            _BadgeMetaPill(
                              icon: Icons.rule_outlined,
                              label: criteria,
                            ),
                          if (eventTitle.isNotEmpty)
                            _BadgeMetaPill(
                              icon: Icons.event_outlined,
                              label: eventTitle,
                            ),
                          if (categoryName.isNotEmpty)
                            _BadgeMetaPill(
                              icon: Icons.flag_outlined,
                              label: categoryName,
                            ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "How to unlock",
                              style: TextStyle(
                                color: Color(0xFF111827),
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              criteria.isNotEmpty
                                  ? criteria
                                  : description.isNotEmpty
                                  ? description
                                  : "Complete the required event achievement to unlock this E-Badge.",
                              style: const TextStyle(
                                color: Color(0xFF475569),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            if (hasProgress) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  minHeight: 8,
                                  value: (progress / target).clamp(0.0, 1.0),
                                  backgroundColor: const Color(0xFFE2E8F0),
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        Color(0xFF2563EB),
                                      ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                "$progress of $target completed",
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.notes_outlined,
                              color: Color(0xFF64748B),
                              size: 18,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                notes,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
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

class _EmptyIssuedBadgesCard extends StatelessWidget {
  const _EmptyIssuedBadgesCard();

  @override
  Widget build(BuildContext context) {
    return const _EmptyBadgeSectionCard(
      icon: Icons.workspace_premium_outlined,
      title: "No E-Badges available yet",
      message: "Admin-uploaded E-Badges will appear here once available.",
    );
  }
}

class _EmptyBadgeSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyBadgeSectionCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
          Icon(icon, color: const Color(0xFF94A3B8), size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgesHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _BadgesHeader({required this.onBack});

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
                "E-Badges",
                style: TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 3),
              Text(
                "Your official event E-Badges",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
