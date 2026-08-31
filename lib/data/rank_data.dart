class RankTier {
  final String title;
  final String requirement;
  final int? badges;

  const RankTier({required this.title, required this.requirement, this.badges});
}

const List<RankTier> rankTiers = [
  RankTier(title: "Rookie Racetech", requirement: "1 E-Badge", badges: 1),
  RankTier(title: "Rising Warrior", requirement: "3 E-Badges", badges: 3),
  RankTier(title: "Trailblazer", requirement: "5 E-Badges", badges: 5),
  RankTier(title: "Elite Challenger", requirement: "8 E-Badges", badges: 8),
  RankTier(title: "Legendary Victor", requirement: "12 E-Badges", badges: 12),
  RankTier(title: "Mythic Champion", requirement: "15 E-Badges", badges: 15),
  RankTier(title: "Ultimate Racetech", requirement: "All E-Badges"),
];

String rankTitleForBadges(int badges) {
  for (final tier in rankTiers.reversed) {
    final requiredBadges = tier.badges;
    if (requiredBadges != null && badges >= requiredBadges) {
      return tier.title;
    }
  }

  return "Badge Seeker";
}
