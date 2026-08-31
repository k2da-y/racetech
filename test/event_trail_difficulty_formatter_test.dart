import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/event_trail_difficulty_formatter.dart';

void main() {
  test('reads category difficulty from type details', () {
    expect(
      categoryTrailDifficultyLabel(<String, dynamic>{
        'type_details': {'trail_difficulty': 'Technical'},
      }, eventType: 'Trail Run'),
      'Trail Difficulty: Technical',
    );
  });

  test('reads category difficulty from formatted detail items', () {
    expect(
      categoryTrailDifficultyLabel(<String, dynamic>{
        'type_detail_items': [
          {'label': 'Trail Difficulty', 'formatted_value': 'Moderate'},
        ],
      }, eventType: 'Trail Run'),
      'Trail Difficulty: Moderate',
    );
  });

  test('prefers category difficulty over legacy event difficulty', () {
    expect(
      categoryTrailDifficultyLabel(
        <String, dynamic>{
          'type_details': {'trail_difficulty': 'Advanced'},
        },
        eventType: 'Trail Run',
        eventTypeDetails: {'trail_difficulty': 'Beginner'},
      ),
      'Trail Difficulty: Advanced',
    );
  });

  test('falls back to legacy event difficulty', () {
    expect(
      categoryTrailDifficultyLabel(
        <String, dynamic>{},
        eventType: 'Trail Run',
        eventTypeDetails: {'trail_difficulty': 'Beginner'},
      ),
      'Trail Difficulty: Beginner',
    );
  });

  test('hides missing difficulty and non-Trail Run values', () {
    expect(
      categoryTrailDifficultyLabel(<String, dynamic>{}, eventType: 'Trail Run'),
      isEmpty,
    );
    expect(
      categoryTrailDifficultyLabel(<String, dynamic>{
        'type_details': {'trail_difficulty': 'Technical'},
      }, eventType: 'Hiking'),
      isEmpty,
    );
  });

  test('identifies event-wide trail difficulty fields for filtering', () {
    expect(isTrailDifficultyDetailLabel('trail_difficulty'), isTrue);
    expect(isTrailDifficultyDetailLabel('Trail Difficulty Level'), isTrue);
    expect(isTrailDifficultyDetailLabel('Elevation Gain'), isFalse);
  });
}
