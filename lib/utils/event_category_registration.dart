bool categoryHasRegistrationMetadata(Map<String, dynamic> category) {
  return const [
    "can_register",
    "registration_allowed",
    "is_eligible",
    "is_registered",
    "registration_status",
    "user_registration_status",
    "conflict_reason",
    "registration_conflict_reason",
  ].any(category.containsKey);
}

String categoryRegistrationStatus(Map<String, dynamic> category) {
  final registration = category["registration"];
  final nestedStatus = registration is Map ? registration["status"] : null;
  final status =
      category["registration_status"] ??
      category["user_registration_status"] ??
      nestedStatus;
  final normalized = status?.toString().trim().toLowerCase() ?? "";
  if (normalized.isNotEmpty) return normalized;
  return category["is_registered"] == true ? "registered" : "";
}

bool categoryIsJoined(Map<String, dynamic> category) {
  if (category["is_registered"] == true) return true;
  return const {
    "registered",
    "pending",
    "approved",
    "checked_in",
    "completed",
  }.contains(categoryRegistrationStatus(category));
}

String categoryConflictReason(Map<String, dynamic> category) {
  for (final key in const [
    "conflict_reason",
    "registration_conflict_reason",
    "ineligibility_reason",
    "unavailable_reason",
  ]) {
    final value = category[key]?.toString().trim() ?? "";
    if (value.isNotEmpty) return value;
  }
  return "";
}

bool categoryCanRegister(Map<String, dynamic> category) {
  if (categoryIsJoined(category) ||
      categoryConflictReason(category).isNotEmpty) {
    return false;
  }

  for (final key in const [
    "can_register",
    "registration_allowed",
    "is_eligible",
  ]) {
    if (category[key] is bool) return category[key] == true;
  }

  return (category["status"] ?? "").toString().toLowerCase() == "open";
}

String categoryStatusLabel(Map<String, dynamic> category) {
  final status = categoryRegistrationStatus(category);
  if (status.isNotEmpty) {
    return status
        .split("_")
        .map(
          (word) => word.isEmpty
              ? word
              : "${word[0].toUpperCase()}${word.substring(1)}",
        )
        .join(" ");
  }
  final conflict = categoryConflictReason(category);
  if (conflict.isNotEmpty) return conflict;
  return categoryCanRegister(category) ? "Available" : "Unavailable";
}

String categoryCutoffTime(Map<String, dynamic> category, dynamic eventEndTime) {
  for (final key in const ["cutoff_time", "scheduled_end_time", "end_time"]) {
    final value = category[key]?.toString().trim() ?? "";
    if (value.isNotEmpty) return value;
  }
  return eventEndTime?.toString().trim() ?? "";
}
