import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/utils/qualification_notes.dart';

void main() {
  test('reads and trims category qualification notes', () {
    expect(
      categoryQualificationNotes({
        'qualification_notes': '  Must be 18 or older.  ',
      }),
      'Must be 18 or older.',
    );
  });

  test('preserves internal line breaks', () {
    expect(
      categoryQualificationNotes({
        'qualification_notes':
            'Previous 21K finish required.\nBring a valid race certificate.',
      }),
      'Previous 21K finish required.\nBring a valid race certificate.',
    );
  });

  test('returns empty text when notes are absent or blank', () {
    expect(categoryQualificationNotes(<String, dynamic>{}), isEmpty);
    expect(categoryQualificationNotes({'qualification_notes': '   '}), isEmpty);
  });
}
