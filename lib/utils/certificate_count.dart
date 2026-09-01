const certificateCountKeys = [
  'certificates_count',
  'badges_count',
  'badge_count',
  'unlocked_badges_count',
  'achievements_count',
];

int? certificateCountFromUser(Map<String, dynamic>? user) {
  if (user == null) return null;

  for (final key in certificateCountKeys) {
    final value = user[key];
    final parsed = value is num
        ? value.toInt()
        : int.tryParse(value?.toString().trim() ?? '');
    if (parsed != null) return parsed < 0 ? 0 : parsed;
  }
  return null;
}

int certificateCountOrZero(Map<String, dynamic>? user) {
  return certificateCountFromUser(user) ?? 0;
}
