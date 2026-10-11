import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:racetechph/pages/landing_page.dart';

import 'package:racetechph/main.dart';

void main() {
  for (final scenario in [
    (size: const Size(320, 568), scale: 1.0),
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(844, 390), scale: 1.0),
    (size: const Size(320, 568), scale: 2.0),
  ]) {
    testWidgets('landing fits ${scenario.size} at ${scenario.scale}x text', (
      tester,
    ) async {
      tester.view.physicalSize = scenario.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scenario.scale)),
            child: child!,
          ),
          home: const LandingPage(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final login = find.text('I already have an account');
      await tester.ensureVisible(login);
      await tester.pumpAndSettle();
      expect(login.hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
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
