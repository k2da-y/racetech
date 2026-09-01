Map<String, dynamic>? registrationFeedback(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  final readinessFeedback = readiness is Map ? readiness['feedback'] : null;
  return submittedFeedbackFromValue(readinessFeedback) ??
      submittedFeedbackFromValue(registration['feedback']);
}

bool registrationFeedbackRequired(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  final readinessFeedback = readiness is Map ? readiness['feedback'] : null;
  return _boolValue(
        readinessFeedback is Map ? readinessFeedback['required'] : null,
      ) ??
      _boolValue(readiness is Map ? readiness['feedback_required'] : null) ??
      _boolValue(registration['feedback_required']) ??
      false;
}

bool registrationCanSubmitFeedback(Map<String, dynamic> registration) {
  final readiness = registration['readiness'];
  final readinessFeedback = readiness is Map ? readiness['feedback'] : null;
  final topLevelFeedback = registration['feedback'];
  return feedbackCanSubmitFromValue(readinessFeedback) ??
      _boolValue(readiness is Map ? readiness['can_submit_feedback'] : null) ??
      feedbackCanSubmitFromValue(topLevelFeedback) ??
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

Map<String, dynamic>? submittedFeedbackFromValue(dynamic value) {
  if (value is! Map) return null;
  final wrapper = Map<String, dynamic>.from(value);

  for (final key in const ['feedback', 'data']) {
    final nested = wrapper[key];
    if (nested is! Map) continue;
    final submitted = submittedFeedbackFromValue(nested);
    if (submitted == null) continue;
    return {
      ...submitted,
      if (wrapper.containsKey('can_edit')) 'can_edit': wrapper['can_edit'],
      if (wrapper.containsKey('editable_until'))
        'editable_until': wrapper['editable_until'],
    };
  }

  if (wrapper['overall_rating'] == null) return null;
  return wrapper;
}

bool? feedbackCanSubmitFromValue(dynamic value) {
  if (value is! Map) return null;
  final data = Map<String, dynamic>.from(value);
  return _boolValue(data['can_submit']) ??
      _boolValue(data['can_submit_feedback']);
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
