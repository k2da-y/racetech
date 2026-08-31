import 'package:flutter/material.dart';

String announcementImageUrl(Map<String, dynamic> announcement) {
  return (announcement['image_url'] ?? '').toString().trim();
}

Widget announcementImageLoadingBuilder(
  BuildContext context,
  Widget child,
  ImageChunkEvent? progress,
) {
  if (progress == null) return child;
  return const Center(
    key: Key('announcement-image-loading'),
    child: CircularProgressIndicator(strokeWidth: 2.5),
  );
}

class AnnouncementImage extends StatelessWidget {
  final String imageUrl;
  final double height;
  final BorderRadius borderRadius;

  const AnnouncementImage({
    super.key,
    required this.imageUrl,
    this.height = 210,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.trim();
    if (url.isEmpty) return const SizedBox.shrink();

    return Material(
      key: const Key('announcement-image'),
      color: const Color(0xFFF1F5F9),
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openPreview(context, url),
        child: SizedBox(
          width: double.infinity,
          height: height,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: announcementImageLoadingBuilder,
            errorBuilder: (context, error, stackTrace) {
              return const _AnnouncementImageError();
            },
          ),
        ),
      ),
    );
  }

  void _openPreview(BuildContext context, String url) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnnouncementImagePreview(imageUrl: url),
      ),
    );
  }
}

class _AnnouncementImageError extends StatelessWidget {
  const _AnnouncementImageError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      key: Key('announcement-image-error'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Color(0xFF64748B)),
          SizedBox(height: 5),
          Text(
            'Image unavailable',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AnnouncementImagePreview extends StatelessWidget {
  final String imageUrl;

  const AnnouncementImagePreview({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('announcement-image-preview'),
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF020617),
        foregroundColor: Colors.white,
        title: const Text('Announcement Image'),
      ),
      body: SafeArea(
        child: InteractiveViewer(
          key: const Key('announcement-image-preview-interactive'),
          minScale: 0.8,
          maxScale: 5,
          child: Center(
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const CircularProgressIndicator(color: Colors.white);
              },
              errorBuilder: (context, error, stackTrace) {
                return const _AnnouncementImageError();
              },
            ),
          ),
        ),
      ),
    );
  }
}
