class Post {
  String id;
  String title;
  String content;
  String? media; // 🔥 NEW

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.media,
  });
}