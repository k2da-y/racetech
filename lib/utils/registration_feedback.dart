Map<String, dynamic>? registrationFeedback(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  final readinessFeedback = readiness is Map ? readiness['feedback'] : null;
  final value = readinessFeedback ?? registration['feedback'];
  return value is Map ? Map<String, dynamic>.from(value) : null;
}

bool registrationFeedbackRequired(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  return _boolValue(readiness is Map ? readiness['feedback_required'] : null) ??
      _boolValue(registration['feedback_required']) ??
      false;
}

bool registrationCanSubmitFeedback(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  return _boolValue(
        readiness is Map ? readiness['can_submit_feedback'] : null,
      ) ??
      _boolValue(registration['can_submit_feedback']) ??
      false;
}

bool registrationHasFeedbackFields(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  return registration.containsKey('feedback') ||
      registration.containsKey('feedback_required') ||
      registration.containsKey('can_submit_feedback') ||
      (readiness is Map &&
          (readiness.containsKey('feedback') ||
              readiness.containsKey('feedback_required') ||
              readiness.containsKey('can_submit_feedback')));
}

bool shouldShowFeedbackPrompt(Map<String, dynamic> registration) {
  if (!registrationHasFeedbackFields(registration)) return false;
  return registrationFeedback(registration) != null ||
      registrationFeedbackRequired(registration) ||
      registrationCanSubmitFeedback(registration);
}

bool feedbackCanEdit(
  Map<String, dynamic>? feedback, {
  required bool canSubmitFeedback,
}) {
  if (feedback == null) return canSubmitFeedback;
  return _boolValue(feedback['can_edit']) ?? false;
}

String feedbackEditableUntil(Map<String, dynamic>? feedback) {
  return (feedback?['editable_until'] ?? '').toString().trim();
}

int? feedbackRating(Map<String, dynamic>? feedback, String key) {
  final value = feedback?[key];
  final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed >= 1 && parsed <= 5 ? parsed : null;
}

bool? _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase();
  if (normalized == 'true' || normalized == '1') return true;
  if (normalized == 'false' || normalized == '0') return false;
  return null;
}
