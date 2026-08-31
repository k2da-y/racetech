import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/registration_readiness.dart';

void main() {
  test('returns null when readiness is absent', () {
    expect(registrationReadiness(<String, dynamic>{}), isNull);
  });

  test('normalizes status and next-step action', () {
    final readiness = <String, dynamic>{
      'current_status': 'approved',
      'next_step': {
        'title': 'Prepare for race day',
        'message': 'Review your required gear.',
        'action': 'view_results',
        'action_label': 'View Results',
      },
    };

    expect(readinessRegistrationStatus(readiness, 'pending'), 'approved');
    expect(readinessNextStep(readiness), {
      'title': 'Prepare for race day',
      'message': 'Review your required gear.',
      'action': 'view_results',
      'action_label': 'View Results',
    });
  });

  test('normalizes checklist lists', () {
    final checklist = readinessChecklist({
      'checklist': [
        {
          'key': 'payment',
          'label': 'Payment',
          'status': 'complete',
          'message': 'Payment verified',
        },
        {'key': 'bib', 'status': 'pending'},
      ],
    });

    expect(checklist.length, 2);
    expect(checklist.first['status'], 'complete');
    expect(checklist.last['label'], 'Bib');
  });

  test('supports direct readiness checklist keys', () {
    final checklist = readinessChecklist({
      'payment': true,
      'approval': {'status': 'complete', 'message': 'Approved'},
      'bib': false,
      'first_aid_kit': {'status': 'complete'},
      'e_badge': {'status': 'not_required'},
    });

    expect(checklist.map((item) => item['key']), [
      'payment',
      'approval',
      'bib',
      'first_aid_kit',
      'e_badge',
    ]);
    expect(checklist.first['status'], 'complete');
    expect(checklist.last['label'], 'E-Certificate');
  });

  test('prefers certificate and avoids duplicate legacy E-Badge steps', () {
    final checklist = readinessChecklist({
      'certificate': {'status': 'available'},
      'e_badge': {'status': 'complete'},
    });

    expect(checklist, [
      {
        'key': 'certificate',
        'label': 'E-Certificate',
        'status': 'available',
        'message': '',
      },
    ]);
  });

  test('labels the direct first aid kit step correctly', () {
    final checklist = readinessChecklist({
      'first_aid_kit': {'status': 'complete'},
    });

    expect(checklist.single['key'], 'first_aid_kit');
    expect(checklist.single['label'], 'First Aid Kit');
    expect(checklist.single['status'], 'complete');
  });

  test('normalizes the six participant registration states', () {
    final fixtures = <Map<String, dynamic>>[
      {
        'status': 'pending',
        'next_step': {
          'title': 'Complete payment',
          'action': 'complete_payment',
        },
      },
      {
        'status': 'pending',
        'next_step': {'title': 'Await organizer approval'},
      },
      {
        'status': 'approved',
        'next_step': {'title': 'Prepare for race day'},
      },
      {
        'status': 'checked_in',
        'next_step': {'title': 'Ready for your gun start'},
      },
      {
        'status': 'completed',
        'next_step': {
          'title': 'View official results',
          'action': 'view_results',
        },
      },
      {
        'status': 'rejected',
        'next_step': {'title': 'Review the rejection reason'},
      },
    ];

    expect(
      fixtures.map((item) => readinessRegistrationStatus(item, 'unknown')),
      ['pending', 'pending', 'approved', 'checked_in', 'completed', 'rejected'],
    );
    expect(fixtures.map((item) => readinessNextStep(item)['title']), [
      'Complete payment',
      'Await organizer approval',
      'Prepare for race day',
      'Ready for your gun start',
      'View official results',
      'Review the rejection reason',
    ]);
    expect(readinessNextStep(fixtures.first)['action'], 'complete_payment');
    expect(readinessNextStep(fixtures[4])['action'], 'view_results');
  });

  test('preserves multiline readiness text', () {
    expect(
      readinessText(
        {'qualification_notes': 'Finish a 21K race.\nBring your certificate.'},
        const ['qualification_notes'],
      ),
      'Finish a 21K race.\nBring your certificate.',
    );
  });
}
