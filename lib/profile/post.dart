class Post {
  String id;
  String title;
  String content;
  String? media;

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.media,
  });
}