import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_distance_formatter.dart';

void main() {
  group('category display distance', () {
    test(
      'prefers the display pair without converting the canonical distance',
      () {
        final category = <String, dynamic>{
          'distance_value': '10.00',
          'distance_unit': 'mi',
          'distance_km': 16.0934,
        };
        expect(categoryDistanceLabel(category), '10 miles');
        expect(category['distance_km'], 16.0934);
        expect(
          categoryDistanceLabel({
            'distance_value': 5.0,
            'distance_unit': 'km',
            'distance_km': 8,
          }),
          '5 km',
        );
        expect(
          categoryDistanceLabel({'distance_value': 1, 'distance_unit': 'mi'}),
          '1 mile',
        );
        expect(
          categoryDistanceLabel({
            'distance_value': 2.5,
            'distance_unit': ' miles ',
          }),
          '2.5 miles',
        );
      },
    );
    test(
      'uses canonical km for legacy, incomplete and invalid display pairs',
      () {
        for (final fields in <Map<String, dynamic>>[
          {},
          {'distance_value': null, 'distance_unit': null},
          {'distance_value': 10},
          {'distance_unit': 'mi'},
          {'distance_value': '', 'distance_unit': 'mi'},
          {'distance_value': 'NaN', 'distance_unit': 'mi'},
          {'distance_value': double.infinity, 'distance_unit': 'mi'},
          {'distance_value': -1, 'distance_unit': 'km'},
          {'distance_value': 10, 'distance_unit': 'yards'},
        ]) {
          expect(
            categoryDistanceLabel({...fields, 'distance_km': '16.09'}),
            '16.09 km',
          );
        }
        for (final invalid in [null, '', 'invalid', -1, 0, 'Infinity']) {
          expect(categoryDistanceLabel({'distance_km': invalid}), isEmpty);
        }
      },
    );
    test('does not change Triathlon or Duathlon segment units', () {
      final tri = {
        'distance_value': 32,
        'distance_unit': 'mi',
        'type_details': {
          'swim_distance_km': 1.5,
          'bike_distance_km': 40,
          'run_distance_km': 10,
        },
      };
      expect(categoryDistanceLabel(tri), '32 miles');
      expect(
        categorySegmentDistanceLabel(tri, eventType: 'Triathlon'),
        'Swim 1.5 km \u2022 Bike 40 km \u2022 Run 10 km',
      );
      final duo = {
        'distance_value': 28,
        'distance_unit': 'mi',
        'type_detail_items': [
          {'label': 'First Run Distance', 'formatted_value': '5 km'},
          {'label': 'Bike Distance', 'formatted_value': '20 km'},
          {'label': 'Second Run Distance', 'formatted_value': '2.5 km'},
        ],
      };
      expect(
        categorySegmentDistanceLabel(duo, eventType: 'Duathlon'),
        'First run 5 km \u2022 Bike 20 km \u2022 Second run 2.5 km',
      );
    });
  });
  test('formats category-specific Triathlon segments', () {
    final category = <String, dynamic>{
      'distance_km': 51.5,
      'type_details': {
        'swim_distance_km': 1.5,
        'bike_distance_km': 40,
        'run_distance_km': 10,
      },
    };

    expect(
      categorySegmentDistanceLabel(category, eventType: 'Triathlon'),
      'Swim 1.5 km • Bike 40 km • Run 10 km',
    );
    expect(category['distance_km'], 51.5);
  });

  test('formats category-specific Duathlon segments in order', () {
    final category = <String, dynamic>{
      'type_detail_items': [
        {'label': 'Second Run Distance', 'formatted_value': '5 km'},
        {'label': 'Bike Distance', 'formatted_value': '30 km'},
        {'label': 'First Run Distance', 'formatted_value': '10 km'},
      ],
    };

    expect(
      categorySegmentDistanceLabel(category, eventType: 'Duathlon'),
      'First run 10 km • Bike 30 km • Second run 5 km',
    );
  });

  test('falls back to legacy event-level segment details', () {
    expect(
      categorySegmentDistanceLabel(
        <String, dynamic>{},
        eventType: 'Triathlon',
        eventTypeDetails: {
          'swim_distance_km': 0.75,
          'bike_distance_km': 20,
          'run_distance_km': 5,
        },
      ),
      'Swim 0.75 km • Bike 20 km • Run 5 km',
    );
  });

  test('does not invent segment distances for other event types', () {
    for (final type in ['Cycling', 'Hiking', 'Marathon', 'Trail Run']) {
      expect(
        categorySegmentDistanceLabel(<String, dynamic>{
          'type_details': {'distance_km': 21},
        }, eventType: type),
        isEmpty,
      );
    }
  });
}
