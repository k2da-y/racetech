import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/registration_feedback.dart';

typedef FeedbackLoader = Future<ApiDataResult<Map<String, dynamic>>> Function();
typedef FeedbackSubmitter =
    Future<ApiDataResult<Map<String, dynamic>>> Function(
      Map<String, dynamic> values,
    );

class EventFeedbackSheet extends StatefulWidget {
  final Map<String, dynamic>? initialFeedback;
  final bool canSubmitFeedback;
  final FeedbackLoader onLoad;
  final FeedbackSubmitter onSubmit;
  final VoidCallback onSaved;

  const EventFeedbackSheet({
    super.key,
    required this.initialFeedback,
    required this.canSubmitFeedback,
    required this.onLoad,
    required this.onSubmit,
    required this.onSaved,
  });

  @override
  State<EventFeedbackSheet> createState() => _EventFeedbackSheetState();
}

class _EventFeedbackSheetState extends State<EventFeedbackSheet> {
  final commentController = TextEditingController();
  Map<String, dynamic>? feedback;
  int? overallRating;
  int? organizationRating;
  int? routeRating;
  int? safetyRating;
  int? experienceRating;
  bool isLoading = true;
  bool isSubmitting = false;
  String errorMessage = '';

  bool get canEdit =>
      feedbackCanEdit(feedback, canSubmitFeedback: widget.canSubmitFeedback);

  @override
  void initState() {
    super.initState();
    _applyFeedback(widget.initialFeedback);
    _loadFeedback();
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  void _applyFeedback(Map<String, dynamic>? value) {
    if (value == null) return;
    feedback = Map<String, dynamic>.from(value);
    overallRating = feedbackRating(feedback, 'overall_rating');
    organizationRating = feedbackRating(feedback, 'organization_rating');
    routeRating = feedbackRating(feedback, 'route_rating');
    safetyRating = feedbackRating(feedback, 'safety_rating');
    experienceRating = feedbackRating(feedback, 'experience_rating');
    commentController.text = (feedback?['comment'] ?? '').toString();
  }

  Future<void> _loadFeedback() async {
    final result = await widget.onLoad();
    if (!mounted) return;

    if (result.success && result.data != null && result.data!.isNotEmpty) {
      final nested = result.data!['feedback'];
      final loaded = nested is Map
          ? <String, dynamic>{
              ...Map<String, dynamic>.from(nested),
              if (result.data!.containsKey('can_edit'))
                'can_edit': result.data!['can_edit'],
              if (result.data!.containsKey('editable_until'))
                'editable_until': result.data!['editable_until'],
            }
          : result.data!;
      _applyFeedback(loaded);
    } else if (!result.success && feedback == null) {
      errorMessage = result.message;
    }

    setState(() => isLoading = false);
  }

  Future<void> _submit() async {
    if (overallRating == null) {
      setState(() => errorMessage = 'Please provide an overall rating.');
      return;
    }

    setState(() {
      isSubmitting = true;
      errorMessage = '';
    });

    final result = await widget.onSubmit({
      'overall_rating': overallRating,
      'organization_rating': organizationRating,
      'route_rating': routeRating,
      'safety_rating': safetyRating,
      'experience_rating': experienceRating,
      'comment': commentController.text.trim(),
    });
    if (!mounted) return;

    if (!result.success) {
      setState(() {
        isSubmitting = false;
        errorMessage = result.message;
      });
      return;
    }

    widget.onSaved();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final deadline = feedbackEditableUntil(feedback);
    final hasFeedback = feedback != null;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.of(context).viewInsets.bottom + 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.rate_review_outlined,
                          color: Color(0xFF2563EB),
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hasFeedback ? 'Event Feedback' : 'Rate This Event',
                            style: const TextStyle(
                              color: Color(0xFF111827),
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your feedback is linked to your participant account and is not anonymous.',
                      key: Key('feedback-privacy-notice'),
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    if (deadline.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        canEdit
                            ? 'Editable until: ${_formatDeadline(deadline)}'
                            : 'Editing closed: ${_formatDeadline(deadline)}',
                        key: const Key('feedback-editable-until'),
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (isLoading) ...[
                      const SizedBox(height: 18),
                      const Center(child: CircularProgressIndicator()),
                    ] else ...[
                      const SizedBox(height: 18),
                      _RatingField(
                        label: 'Overall Rating',
                        required: true,
                        value: overallRating,
                        enabled: canEdit,
                        onChanged: (value) =>
                            setState(() => overallRating = value),
                      ),
                      _RatingField(
                        label: 'Organization',
                        value: organizationRating,
                        enabled: canEdit,
                        onChanged: (value) =>
                            setState(() => organizationRating = value),
                      ),
                      _RatingField(
                        label: 'Route',
                        value: routeRating,
                        enabled: canEdit,
                        onChanged: (value) =>
                            setState(() => routeRating = value),
                      ),
                      _RatingField(
                        label: 'Safety',
                        value: safetyRating,
                        enabled: canEdit,
                        onChanged: (value) =>
                            setState(() => safetyRating = value),
                      ),
                      _RatingField(
                        label: 'Experience',
                        value: experienceRating,
                        enabled: canEdit,
                        onChanged: (value) =>
                            setState(() => experienceRating = value),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const Key('feedback-comment'),
                        controller: commentController,
                        enabled: canEdit,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        decoration: const InputDecoration(
                          labelText: 'Comment (optional)',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    if (!canEdit && hasFeedback && !isLoading) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'This feedback is now read-only.',
                        key: Key('feedback-read-only'),
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    if (errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorMessage,
                        key: const Key('feedback-error'),
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ),
            if (!isLoading && canEdit)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('feedback-submit'),
                  onPressed: isSubmitting ? null : _submit,
                  icon: isSubmitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    hasFeedback ? 'Update Feedback' : 'Submit Feedback',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RatingField extends StatelessWidget {
  final String label;
  final bool required;
  final int? value;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  const _RatingField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                required ? '$label *' : label,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (!required && enabled && value != null)
                TextButton(
                  onPressed: () => onChanged(null),
                  child: const Text('Clear'),
                ),
            ],
          ),
          Row(
            children: [
              for (var rating = 1; rating <= 5; rating++)
                IconButton(
                  key: Key('rating-${label.toLowerCase()}-$rating'),
                  tooltip: '$rating out of 5',
                  visualDensity: VisualDensity.compact,
                  onPressed: enabled ? () => onChanged(rating) : null,
                  icon: Icon(
                    rating <= (value ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: rating <= (value ?? 0)
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF94A3B8),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDeadline(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  final hour = parsed.hour == 0
      ? 12
      : parsed.hour > 12
      ? parsed.hour - 12
      : parsed.hour;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${parsed.month}/${parsed.day}/${parsed.year} $hour:$minute $period';
}
