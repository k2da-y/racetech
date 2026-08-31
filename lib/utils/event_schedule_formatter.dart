import 'event_category_registration.dart';
import 'event_time_formatter.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

DateTime? _parseDate(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty || raw.toLowerCase() == 'tba') return null;
  return DateTime.tryParse(raw)?.toLocal();
}

String _dateLabel(DateTime date) {
  return '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

String _timeLabel(DateTime date) {
  return formatEventStartTime(
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
  );
}

bool _sameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String formatEventDateRange({
  dynamic eventStartDate,
  dynamic eventEndDate,
  dynamic legacyEventDate,
}) {
  final start = _parseDate(eventStartDate) ?? _parseDate(legacyEventDate);
  if (start == null) {
    return legacyEventDate?.toString().trim().isNotEmpty == true
        ? legacyEventDate.toString().trim()
        : 'TBA';
  }

  final end = _parseDate(eventEndDate);
  if (end == null || _sameDay(start, end)) return _dateLabel(start);
  return '${_dateLabel(start)} – ${_dateLabel(end)}';
}

String categoryScheduleLabel(
  Map<String, dynamic> category, {
  dynamic eventStartDate,
  dynamic eventEndDate,
  dynamic legacyEventDate,
  dynamic eventStartTime,
  dynamic eventEndTime,
}) {
  final completeStart = _parseDate(category['scheduled_start_at']);
  final completeEnd = _parseDate(category['scheduled_end_at']);

  final fallbackStartDate =
      _parseDate(category['scheduled_start_date']) ??
      _parseDate(eventStartDate) ??
      _parseDate(legacyEventDate);
  final fallbackEndDate =
      _parseDate(category['scheduled_end_date']) ??
      _parseDate(eventEndDate) ??
      fallbackStartDate;

  final startDate = completeStart ?? fallbackStartDate;
  final endDate = completeEnd ?? fallbackEndDate;
  final startTime = completeStart != null
      ? _timeLabel(completeStart)
      : categoryScheduledStartTime(category, eventStartTime);
  final endTime = completeEnd != null
      ? _timeLabel(completeEnd)
      : formatEventStartTime(categoryCutoffTime(category, eventEndTime));

  if (startDate == null && endDate == null) {
    if (startTime.isNotEmpty && endTime.isNotEmpty) {
      return '$startTime – $endTime';
    }
    return startTime.isNotEmpty ? 'Starts $startTime' : endTime;
  }

  if (startDate != null && endDate != null && !_sameDay(startDate, endDate)) {
    final start = [
      _dateLabel(startDate),
      if (startTime.isNotEmpty) startTime,
    ].join(' • ');
    final end = [
      _dateLabel(endDate),
      if (endTime.isNotEmpty) endTime,
    ].join(' • ');
    return '$start – $end';
  }

  final date = startDate ?? endDate!;
  final times = [
    if (startTime.isNotEmpty) startTime,
    if (endTime.isNotEmpty) endTime,
  ].join(' – ');
  return times.isEmpty ? _dateLabel(date) : '${_dateLabel(date)} • $times';
}
