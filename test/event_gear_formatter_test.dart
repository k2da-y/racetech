import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_gear_formatter.dart';

void main() {
  test('shows category-specific Required Gear for Hiking', () {
    final category = <String, dynamic>{
      'type_details': {
        'required_gear': ['Trekking poles', 'Rain jacket'],
      },
    };

    expect(
      categoryGearLabel(category, eventType: 'Hiking'),
      'Required Gear: Trekking poles, Rain jacket',
    );
  });

  test('shows category-specific Mandatory Gear for Trail Run', () {
    final category = <String, dynamic>{
      'type_detail_items': [
        {
          'label': 'Mandatory Gear',
          'formatted_value': 'Headlamp, hydration vest',
        },
      ],
    };

    expect(
      categoryGearLabel(category, eventType: 'Trail Run'),
      'Mandatory Gear: Headlamp, hydration vest',
    );
  });

  test('prefers category gear over legacy event gear', () {
    expect(
      categoryGearLabel(
        <String, dynamic>{
          'type_details': {'required_gear': 'Category kit'},
        },
        eventType: 'Hiking',
        eventTypeDetails: {'required_gear': 'Legacy kit'},
      ),
      'Required Gear: Category kit',
    );
  });

  test('falls back to old event-level gear', () {
    expect(
      categoryGearLabel(
        <String, dynamic>{},
        eventType: 'Trail Run',
        eventTypeDetails: {'mandatory_gear': 'Whistle, emergency blanket'},
      ),
      'Mandatory Gear: Whistle, emergency blanket',
    );
  });

  test('does not show gear for unrelated event types', () {
    for (final type in ['Cycling', 'Marathon', 'Triathlon', 'Duathlon']) {
      expect(
        categoryGearLabel(<String, dynamic>{
          'type_details': {'required_gear': 'Helmet'},
        }, eventType: type),
        isEmpty,
      );
    }
  });

  test('identifies gear fields for event-wide filtering', () {
    expect(isGearDetailLabel('Required Gear'), isTrue);
    expect(isGearDetailLabel('mandatory_equipment'), isTrue);
    expect(isGearDetailLabel('Elevation Gain'), isFalse);
  });
}
