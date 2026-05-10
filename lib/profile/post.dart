class Comment {
  String id;
  String author;
  String avatarInitial;
  String text;
  DateTime timestamp;
  int likes;
  bool likedByMe;

  Comment({
    required this.id,
    required this.author,
    required this.avatarInitial,
    required this.text,
    required this.timestamp,
    this.likes = 0,
    this.likedByMe = false,
  });
}

class Post {
  String id;
  String title;
  String content;
  String? media;
  bool mediaIsRemote;
  String authorName;
  String? authorAvatarUrl;
  int? userId;
  int likes;
  bool likedByMe;
  List<Comment> comments;
  DateTime createdAt;

  Post({
    required this.id,
    required this.title,
    required this.content,
    this.media,
    this.mediaIsRemote = false,
    this.authorName = "You",
    this.authorAvatarUrl,
    this.userId,
    this.likes = 0,
    this.likedByMe = false,
    List<Comment>? comments,
    DateTime? createdAt,
  }) : comments = comments ?? [],
       createdAt = createdAt ?? DateTime.now();
}
