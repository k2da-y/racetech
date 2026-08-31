String formatEventStartTime(dynamic value) {
  final raw = value?.toString().trim() ?? "";
  if (raw.isEmpty || raw.toLowerCase() == "tba") return "";

  final twelveHour = RegExp(
    r"^(\d{1,2}):(\d{2})(?::\d{2})?\s*([ap]m)$",
    caseSensitive: false,
  ).firstMatch(raw);
  if (twelveHour != null) {
    final hour = int.tryParse(twelveHour.group(1)!);
    final minute = int.tryParse(twelveHour.group(2)!);
    if (hour != null &&
        minute != null &&
        hour >= 1 &&
        hour <= 12 &&
        minute <= 59) {
      return "$hour:${minute.toString().padLeft(2, '0')} ${twelveHour.group(3)!.toUpperCase()}";
    }
  }

  final twentyFourHour = RegExp(
    r"^(\d{1,2}):(\d{2})(?::\d{2})?",
  ).firstMatch(raw);
  if (twentyFourHour == null) return raw;

  final hour = int.tryParse(twentyFourHour.group(1)!);
  final minute = int.tryParse(twentyFourHour.group(2)!);
  if (hour == null || minute == null || hour > 23 || minute > 59) return raw;

  final period = hour >= 12 ? "PM" : "AM";
  final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
  return "$displayHour:${minute.toString().padLeft(2, '0')} $period";
}

String categoryScheduledStartTime(
  Map<String, dynamic> category,
  dynamic eventStartTime,
) {
  final scheduled = formatEventStartTime(category["scheduled_start_time"]);
  return scheduled.isNotEmpty
      ? scheduled
      : formatEventStartTime(eventStartTime);
}
