import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/registration_feedback.dart';

void main() {
  test('reads feedback and flags from readiness first', () {
    final registration = <String, dynamic>{
      'feedback': {'overall_rating': 2},
      'feedback_required': false,
      'can_submit_feedback': false,
      'readiness': {
        'feedback': {
          'overall_rating': 5,
          'can_edit': true,
          'editable_until': '2026-09-07T12:00:00+08:00',
        },
        'feedback_required': true,
        'can_submit_feedback': true,
      },
    };

    final feedback = registrationFeedback(registration);
    expect(feedback?['overall_rating'], 5);
    expect(registrationFeedbackRequired(registration), isTrue);
    expect(registrationCanSubmitFeedback(registration), isTrue);
    expect(shouldShowFeedbackPrompt(registration), isTrue);
    expect(feedbackCanEdit(feedback, canSubmitFeedback: false), isTrue);
    expect(feedbackEditableUntil(feedback), '2026-09-07T12:00:00+08:00');
  });

  test('supports top-level feedback fields', () {
    final registration = <String, dynamic>{
      'feedback': {'overall_rating': '4', 'can_edit': false},
      'feedback_required': true,
      'can_submit_feedback': true,
    };

    final feedback = registrationFeedback(registration);
    expect(feedbackRating(feedback, 'overall_rating'), 4);
    expect(feedbackCanEdit(feedback, canSubmitFeedback: true), isFalse);
    expect(shouldShowFeedbackPrompt(registration), isTrue);
  });

  test('keeps legacy responses without feedback fields unchanged', () {
    final registration = <String, dynamic>{
      'id': 10,
      'status': 'completed',
      'readiness': {'registration_status': 'completed'},
    };

    expect(registrationFeedback(registration), isNull);
    expect(registrationFeedbackRequired(registration), isFalse);
    expect(registrationCanSubmitFeedback(registration), isFalse);
    expect(registrationHasFeedbackFields(registration), isFalse);
    expect(shouldShowFeedbackPrompt(registration), isFalse);
  });

  test('rejects ratings outside the supported 1-5 range', () {
    expect(feedbackRating({'overall_rating': 0}, 'overall_rating'), isNull);
    expect(feedbackRating({'overall_rating': 6}, 'overall_rating'), isNull);
    expect(feedbackRating({'overall_rating': 3}, 'overall_rating'), 3);
  });
}
