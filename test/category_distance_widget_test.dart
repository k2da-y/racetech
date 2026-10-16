import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/pages/places_page.dart';
import 'package:racetechph/profile/my_activity_page.dart';
import 'package:racetechph/utils/event_normalizer.dart';
import 'package:racetechph/widgets/event_details_sheet.dart';

Map<String, dynamic> category(bool miles) => {
  'id': 1,
  'name': 'Open Category',
  'status': 'open',
  'can_register': true,
  'distance_km': miles ? 16.0934 : 5,
  if (miles) ...{'distance_value': 10, 'distance_unit': 'mi'},
  'is_free': true,
};

Map<String, dynamic> event(bool miles) => normalizeEventFromApi({
  'id': 7,
  'title': 'Distance Event',
  'interest_type': 'Marathon',
  'event_date': '2026-11-01',
  'start_time': '06:00',
  'categories': [category(miles)],
});

void main() {
  for (final miles in [true, false]) {
    final label = miles ? '10 miles' : '5 km';
    testWidgets('Event Details displays $label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventDetailsSheet(
              event: event(miles),
              canJoin: true,
              statusLabel: 'Open',
              actionLabel: 'Register',
              availabilityMessage: '',
              onJoin: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(label), findsOneWidget);
      expect(find.textContaining('16.0934km'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('registration dropdown displays $label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: RegisterDialog(event: event(miles))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(label), findsWidgets);
      final dropdown = find.byType(DropdownButtonFormField<int>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      expect(find.textContaining(label).hitTestable(), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'My Activity registrations, results and detail sheets display $label',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MyActivityPage(
              registrationsLoader: () async => [
                {
                  'id': 11,
                  'status': 'approved',
                  'event': {'title': 'Distance Event'},
                  'category': category(miles),
                },
              ],
              resultsLoader: () async => [
                {
                  'event': {'title': 'Distance Result'},
                  'category': category(miles),
                  'finish_time': '01:00:00',
                },
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.text('Distance Event'));
        await tester.pumpAndSettle();
        expect(find.text('Distance'), findsOneWidget);
        expect(find.text(label), findsNWidgets(2));
        // Dismiss the details route and check the Results tab too.
        Navigator.of(tester.element(find.text('Distance'))).pop();
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(TabBar),
            matching: find.text('Results'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(label), findsOneWidget);
        await tester.tap(find.text('Distance Result'));
        await tester.pumpAndSettle();
        expect(find.text('Distance'), findsOneWidget);
        expect(find.text(label), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
