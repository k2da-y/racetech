import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/widgets/category_checkpoint_map.dart';

void main() {
  test('reads and trims a category checkpoint map URL', () {
    expect(
      categoryCheckpointMapUrl({
        'checkpoint_map_image_url': ' https://example.com/map.jpg ',
      }),
      'https://example.com/map.jpg',
    );
  });

  test('returns empty for legacy categories without a map', () {
    expect(categoryCheckpointMapUrl(<String, dynamic>{}), isEmpty);
    expect(
      categoryCheckpointMapUrl({'checkpoint_map_image_url': null}),
      isEmpty,
    );
  });
}
