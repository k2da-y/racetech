import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:racetechph/main.dart';

void main() {
  testWidgets('shows landing screen when no mobile session exists', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RacetechApp());
    await tester.pumpAndSettle();

    expect(find.text('Train. Compete.\nConquer.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
  });
}
