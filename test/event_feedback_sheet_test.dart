import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/services/api_service.dart';
import 'package:racetechph/widgets/event_feedback_sheet.dart';

void main() {
  testWidgets('requires overall rating and submits optional values', (
    tester,
  ) async {
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(
      _app(
        EventFeedbackSheet(
          initialFeedback: null,
          canSubmitFeedback: true,
          onLoad: () async => const ApiDataResult.success({}),
          onSubmit: (values) async {
            submitted = values;
            return const ApiDataResult.success({});
          },
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Your feedback is linked to your participant account and is not anonymous.',
      ),
      findsOneWidget,
    );
    final comment = tester.widget<TextField>(
      find.byKey(const Key('feedback-comment')),
    );
    expect(comment.maxLength, 2000);

    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pump();
    expect(find.text('Please provide an overall rating.'), findsOneWidget);
    expect(submitted, isNull);

    await tester.tap(find.byKey(const Key('rating-overall rating-5')));
    await tester.tap(find.byKey(const Key('rating-safety-4')));
    await tester.enterText(
      find.byKey(const Key('feedback-comment')),
      'Well organized and safe.',
    );
    await tester.tap(find.byKey(const Key('feedback-submit')));
    await tester.pumpAndSettle();

    expect(submitted?['overall_rating'], 5);
    expect(submitted?['safety_rating'], 4);
    expect(submitted?['organization_rating'], isNull);
    expect(submitted?['comment'], 'Well organized and safe.');
  });

  testWidgets('loads existing editable feedback and shows its deadline', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        EventFeedbackSheet(
          initialFeedback: null,
          canSubmitFeedback: true,
          onLoad: () async => const ApiDataResult.success({
            'feedback': {'overall_rating': 4, 'comment': 'Good event.'},
            'can_edit': true,
            'editable_until': '2026-09-07T12:00:00+08:00',
          }),
          onSubmit: (values) async => const ApiDataResult.success({}),
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Update Feedback'), findsOneWidget);
    expect(find.textContaining('Editable until:'), findsOneWidget);
    expect(find.text('Good event.'), findsOneWidget);
  });

  testWidgets('shows seven-day-closed feedback as read-only', (tester) async {
    await tester.pumpWidget(
      _app(
        EventFeedbackSheet(
          initialFeedback: const {
            'overall_rating': 5,
            'organization_rating': 4,
            'comment': 'Excellent race.',
            'can_edit': false,
            'editable_until': '2026-08-29T17:00:00+08:00',
          },
          canSubmitFeedback: false,
          onLoad: () async => const ApiDataResult.success({}),
          onSubmit: (values) async => const ApiDataResult.success({}),
          onSaved: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('feedback-read-only')), findsOneWidget);
    expect(find.text('This feedback is now read-only.'), findsOneWidget);
    expect(find.textContaining('Editing closed:'), findsOneWidget);
    expect(find.byKey(const Key('feedback-submit')), findsNothing);

    final comment = tester.widget<TextField>(
      find.byKey(const Key('feedback-comment')),
    );
    expect(comment.enabled, isFalse);
  });
}

Widget _app(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}
