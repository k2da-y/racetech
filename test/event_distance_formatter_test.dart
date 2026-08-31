import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_distance_formatter.dart';

void main() {
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
