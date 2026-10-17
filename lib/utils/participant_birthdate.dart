const birthdateRequiredMessage =
    'Birthdate is required for participant accounts.';
const birthdateInvalidMessage = 'Birthdate must be a valid date.';
const birthdateBeforeTodayMessage = 'Birthdate must be before today.';
const birthdateTooOldMessage = 'Birthdate must be within the last 120 years.';
const birthdateRegistrationBlockMessage =
    'Add a valid birthdate to your profile before registering for an event.';

({DateTime first, DateTime last, DateTime today}) birthdateLimits({
  DateTime? now,
}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  return (
    first: DateTime(today.year - 120, today.month, today.day),
    last: DateTime(today.year, today.month, today.day - 1),
    today: today,
  );
}

DateTime? parseParticipantBirthdate(String? value) {
  final text = value?.trim() ?? '';
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final parsed = DateTime.tryParse(text);
  return parsed != null && formatParticipantBirthdate(parsed) == text
      ? parsed
      : null;
}

String formatParticipantBirthdate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String? validateParticipantBirthdate(String? value, {DateTime? now}) {
  if (value == null || value.trim().isEmpty) return birthdateRequiredMessage;
  final date = parseParticipantBirthdate(value);
  if (date == null) return birthdateInvalidMessage;
  final limits = birthdateLimits(now: now);
  if (!date.isBefore(limits.today)) return birthdateBeforeTodayMessage;
  if (date.isBefore(limits.first)) return birthdateTooOldMessage;
  return null;
}

DateTime initialParticipantBirthdate(String? value, {DateTime? now}) {
  final limits = birthdateLimits(now: now);
  final date = parseParticipantBirthdate(value) ?? DateTime(2000);
  if (date.isBefore(limits.first)) return limits.first;
  if (date.isAfter(limits.last)) return limits.last;
  return date;
}

String registrationBlockReason(
  Map<String, dynamic> event, {
  Map<String, dynamic>? user,
}) {
  for (final source in [event, ?user]) {
    final reason = source['registration_block_reason']?.toString().trim() ?? '';
    if (reason.isNotEmpty) return reason;
  }
  return user != null &&
          validateParticipantBirthdate(user['birthdate']?.toString()) != null
      ? birthdateRegistrationBlockMessage
      : '';
}
