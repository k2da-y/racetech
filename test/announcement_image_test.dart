import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:racetechph/widgets/announcement_image.dart';

void main() {
  group('announcementImageUrl', () {
    test('reads and trims the optional image URL', () {
      expect(
        announcementImageUrl({
          'image_url': ' https://example.com/announcement.jpg ',
        }),
        'https://example.com/announcement.jpg',
      );
    });

    test('returns empty for null, blank, and legacy responses', () {
      expect(announcementImageUrl(<String, dynamic>{}), isEmpty);
      expect(announcementImageUrl({'image_url': null}), isEmpty);
      expect(announcementImageUrl({'image_url': '   '}), isEmpty);
    });
  });

  group('AnnouncementImage', () {
    testWidgets('hides the image area for a blank URL', (tester) async {
      await tester.pumpWidget(_app(const AnnouncementImage(imageUrl: '  ')));

      expect(find.byKey(const Key('announcement-image')), findsNothing);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('shows a loading state while image bytes arrive', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) => announcementImageLoadingBuilder(
              context,
              const SizedBox(),
              const ImageChunkEvent(
                cumulativeBytesLoaded: 1,
                expectedTotalBytes: 2,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(const Key('announcement-image-loading')),
        findsOneWidget,
      );
    });

    testWidgets('shows a broken-image state when loading fails', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 240,
            child: AnnouncementImage(
              imageUrl: 'https://example.invalid/missing.jpg',
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('announcement-image')), findsOneWidget);

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('announcement-image-error')), findsOneWidget);
      expect(find.text('Image unavailable'), findsOneWidget);
    });

    testWidgets('opens a pinch-to-zoom full-screen preview when tapped', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const SizedBox(
            width: 240,
            child: AnnouncementImage(
              imageUrl: 'https://example.invalid/preview.jpg',
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('announcement-image')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('announcement-image-preview')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('announcement-image-preview-interactive')),
        findsOneWidget,
      );

      final viewer = tester.widget<InteractiveViewer>(
        find.byKey(const Key('announcement-image-preview-interactive')),
      );
      expect(viewer.maxScale, 5);
    });
  });
}

Widget _app(Widget child) {
  return MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );
}
