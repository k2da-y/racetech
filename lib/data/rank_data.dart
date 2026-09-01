class RankTier {
  final String title;
  final String requirement;
  final int? badges;

  const RankTier({required this.title, required this.requirement, this.badges});
}

const List<RankTier> rankTiers = [
  RankTier(title: "Rookie Racetech", requirement: "1 E-Certificate", badges: 1),
  RankTier(title: "Rising Warrior", requirement: "3 E-Certificates", badges: 3),
  RankTier(title: "Trailblazer", requirement: "5 E-Certificates", badges: 5),
  RankTier(
    title: "Elite Challenger",
    requirement: "8 E-Certificates",
    badges: 8,
  ),
  RankTier(
    title: "Legendary Victor",
    requirement: "12 E-Certificates",
    badges: 12,
  ),
  RankTier(
    title: "Mythic Champion",
    requirement: "15 E-Certificates",
    badges: 15,
  ),
  RankTier(title: "Ultimate Racetech", requirement: "All E-Certificates"),
];

String rankTitleForBadges(int badges) {
  for (final tier in rankTiers.reversed) {
    final requiredBadges = tier.badges;
    if (requiredBadges != null && badges >= requiredBadges) {
      return tier.title;
    }
  }

  return "Certificate Seeker";
}
