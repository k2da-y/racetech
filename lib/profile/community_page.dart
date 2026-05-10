import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'post.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

//THEME CONSTANTS
const _bg = Color(0xFFFFFFFF); // White background
const _surface = Color(0xFFFFFFFF); // White cards/dialogs
const _surfaceHigh = Color(0xFFF5F5F5); // Light gray elevated surface
const _border = Color(0xFFE0E0E0); // Soft gray border

const _textPrimary = Color(0xFF000000); // Black main text
const _textSecondary = Color(0xFF666666); // Gray secondary text

const _likeRed = Color(0xFFFF3B5C); // Red like/heart

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with TickerProviderStateMixin {
  List<Post> posts = [];
  bool _isLoading = true;
  bool _isPosting = false;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  File? _selectedMedia;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  //HELPERS

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Comment _commentFromApi(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.from(data["user"] ?? {});
    final author = (user["name"] ?? "Runner").toString();
    final rawCreatedAt = (data["created_at"] ?? "").toString();
    final createdAt = DateTime.tryParse(rawCreatedAt)?.toLocal();

    return Comment(
      id: data["id"].toString(),
      author: author,
      avatarInitial: author.isNotEmpty ? author[0].toUpperCase() : "R",
      text: (data["content"] ?? "").toString(),
      timestamp: createdAt ?? DateTime.now(),
    );
  }

  Post _postFromApi(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.from(data["user"] ?? {});
    final rawCreatedAt = (data["created_at"] ?? "").toString();
    final createdAt = DateTime.tryParse(rawCreatedAt)?.toLocal();
    final comments = ((data["comments"] as List?) ?? [])
        .whereType<Map>()
        .map((comment) => _commentFromApi(Map<String, dynamic>.from(comment)))
        .toList();

    return Post(
      id: data["id"].toString(),
      title: (data["title"] ?? "Community post").toString(),
      content: (data["content"] ?? "").toString(),
      media: (data["image_url"] ?? data["video_url"])?.toString(),
      mediaIsRemote: true,
      authorName: (user["name"] ?? "Runner").toString(),
      authorAvatarUrl: user["avatar_url"]?.toString(),
      userId: int.tryParse((user["id"] ?? "").toString()),
      likes: int.tryParse((data["likes_count"] ?? 0).toString()) ?? 0,
      likedByMe: data["liked_by_me"] == true,
      comments: comments,
      createdAt: createdAt,
    );
  }

  Future<void> _loadPosts() async {
    final data = await ApiService().getCommunityPosts();

    if (!mounted) return;

    setState(() {
      posts = data.map(_postFromApi).toList();
      _isLoading = false;
    });
  }

  //MEDIA PICKERS

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedMedia = File(picked.path));
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) setState(() => _selectedMedia = File(picked.path));
  }

  //CRUD

  Future<void> _addPost() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty ||
        _isPosting) {
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isPosting = true);

    final result = await ApiService().createCommunityPost(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      mediaPath: _selectedMedia?.path,
    );

    if (!mounted) return;

    setState(() => _isPosting = false);

    if (!result.success || result.data == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    setState(() {
      posts.insert(0, _postFromApi(result.data!));
    });

    _titleController.clear();
    _contentController.clear();
    _selectedMedia = null;
    Navigator.pop(context);
  }

  Future<void> _deletePost(Post post) async {
    HapticFeedback.mediumImpact();
    final deleted = await ApiService().deleteCommunityPost(post.id);

    if (!mounted) return;

    if (deleted) {
      setState(() => posts.remove(post));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You can only delete your own posts.")),
    );
  }

  Future<void> _toggleLike(Post post) async {
    HapticFeedback.lightImpact();
    final result = await ApiService().toggleCommunityLike(post.id);

    if (!mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to update like.")));
      return;
    }

    setState(() {
      post.likedByMe = result["liked"] == true;
      post.likes = int.tryParse((result["likes_count"] ?? 0).toString()) ?? 0;
    });
  }

  void _toggleCommentLike(Comment comment, StateSetter setSheet) {
    HapticFeedback.lightImpact();
    setState(() {
      comment.likedByMe ? comment.likes-- : comment.likes++;
      comment.likedByMe = !comment.likedByMe;
    });
    setSheet(() {});
  }

  //DIALOGS / SHEETS

  void _showCreateSheet() {
    _selectedMedia = null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header row
              Row(
                children: [
                  _Avatar(letter: 'Y', size: 38),
                  const SizedBox(width: 12),
                  const Text(
                    'New thread',
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(
                      Icons.close,
                      color: _textSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title field
              _ThreadTextField(
                controller: _titleController,
                hint: 'Title…',
                maxLines: 1,
              ),
              const SizedBox(height: 10),

              // Content field
              _ThreadTextField(
                controller: _contentController,
                hint: "What's on your mind?",
                maxLines: 5,
              ),
              const SizedBox(height: 12),

              // Media preview
              if (_selectedMedia != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedMedia!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Media + post row
              Row(
                children: [
                  _MediaIconBtn(
                    icon: Icons.image_outlined,
                    onTap: () async {
                      await _pickImage();
                      setModal(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  _MediaIconBtn(
                    icon: Icons.videocam_outlined,
                    onTap: () async {
                      await _pickVideo();
                      setModal(() {});
                    },
                  ),
                  const Spacer(),
                  _PostButton(
                    label: _isPosting ? "Posting..." : "Post",
                    onTap: _addPost,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCommentsSheet(Post post) {
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Replies',
                      style: TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: const Icon(
                        Icons.close,
                        color: _textSecondary,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              const Divider(color: _border, height: 1),

              // Comment list
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 340),
                child: post.comments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No replies yet.\nBe the first to reply.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: _textSecondary, height: 1.6),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: post.comments.length,
                        separatorBuilder: (context, index) =>
                            const Divider(color: _border, height: 1),
                        itemBuilder: (_, i) {
                          final c = post.comments[i];
                          return _CommentTile(
                            comment: c,
                            timeAgo: _timeAgo(c.timestamp),
                            onLike: () => _toggleCommentLike(c, setSheet),
                          );
                        },
                      ),
              ),

              const Divider(color: _border, height: 1),

              // Input bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    _Avatar(letter: 'Y', size: 34),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Add a reply…',
                          hintStyle: TextStyle(color: _textSecondary),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _submitComment(post, setSheet),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _submitComment(post, setSheet),
                      child: const Text(
                        'Post',
                        style: TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitComment(Post post, StateSetter setSheet) async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    final createdComment = await ApiService().addCommunityComment(
      postId: post.id,
      content: text,
    );

    if (!mounted) return;

    if (createdComment == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Unable to add comment.")));
      return;
    }

    setState(() {
      post.comments.add(_commentFromApi(createdComment));
    });
    setSheet(() {});
    _commentController.clear();
  }

  // ignore: unused_element
  void _showEditSheet(Post post) {
    _titleController.text = post.title;
    _contentController.text = post.content;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit thread',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _ThreadTextField(
              controller: _titleController,
              hint: 'Title…',
              maxLines: 1,
            ),
            const SizedBox(height: 10),
            _ThreadTextField(
              controller: _contentController,
              hint: 'Content…',
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _PostButton(
                label: 'Update',
                onTap: () {
                  setState(() {
                    post.title = _titleController.text.trim();
                    post.content = _contentController.text.trim();
                  });
                  _titleController.clear();
                  _contentController.clear();
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  //BUILD

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Community',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: _border, height: 1),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: GestureDetector(
                onTap: () => _showAboutSheet(),
                child: const Icon(
                  Icons.info_outline,
                  color: _textSecondary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _CreateFAB(onTap: _showCreateSheet),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : posts.isEmpty
            ? _EmptyState()
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: 100),
                itemCount: posts.length,
                separatorBuilder: (context, index) =>
                    Container(height: 1, color: _border),
                itemBuilder: (_, i) {
                  final post = posts[i];
                  return _PostTile(
                    post: post,
                    timeAgo: _timeAgo(post.createdAt),
                    onLike: () => _toggleLike(post),
                    onComment: () => _showCommentsSheet(post),
                    onDelete: () => _deletePost(post),
                  );
                },
              ),
      ),
    );
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'RaceTechPH',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A community for riders and event enthusiasts. Join events, connect, and grow together!',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _SocialChip(label: 'Facebook'),
                const SizedBox(width: 8),
                _SocialChip(label: 'Instagram'),
                const SizedBox(width: 8),
                _SocialChip(label: 'TikTok'),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

//SUB-WIDGETS

class _PostTile extends StatelessWidget {
  final Post post;
  final String timeAgo;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onDelete;

  const _PostTile({
    required this.post,
    required this.timeAgo,
    required this.onLike,
    required this.onComment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left column: avatar + thread line
          Column(
            children: [
              _Avatar(
                letter: post.authorName.isEmpty ? "R" : post.authorName[0],
                size: 40,
              ),
              if (post.comments.isNotEmpty) ...[
                const SizedBox(height: 4),
                Container(
                  width: 2,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(width: 12),

          // Right column: content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + time + menu
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    const Spacer(),
                    _PostMenu(onDelete: onDelete),
                  ],
                ),
                const SizedBox(height: 4),

                if (post.title.isNotEmpty) ...[
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Content
                Text(
                  post.content,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),

                // Media
                if (post.media != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: post.mediaIsRemote
                        ? Image.network(
                            post.media!,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  height: 120,
                                  color: _surfaceHigh,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_outlined,
                                    color: _textSecondary,
                                  ),
                                ),
                          )
                        : Image.file(
                            File(post.media!),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                  ),
                ],

                const SizedBox(height: 10),

                // Action row
                Row(
                  children: [
                    _ActionBtn(
                      icon: post.likedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: post.likedByMe ? _likeRed : _textSecondary,
                      count: post.likes,
                      onTap: onLike,
                    ),
                    const SizedBox(width: 16),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      color: _textSecondary,
                      count: post.comments.length,
                      onTap: onComment,
                    ),
                    const SizedBox(width: 16),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String timeAgo;
  final VoidCallback onLike;

  const _CommentTile({
    required this.comment,
    required this.timeAgo,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(letter: comment.avatarInitial, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onLike,
                  child: Row(
                    children: [
                      Icon(
                        comment.likedByMe
                            ? Icons.favorite
                            : Icons.favorite_border,
                        size: 16,
                        color: comment.likedByMe ? _likeRed : _textSecondary,
                      ),
                      if (comment.likes > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${comment.likes}',
                          style: const TextStyle(
                            color: _textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;
  final double size;

  const _Avatar({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    // Deterministic color from letter
    final colors = [
      const Color(0xFF5B4FCF),
      const Color(0xFFCF4F8A),
      const Color(0xFF4F9BCF),
      const Color(0xFFCF8A4F),
      const Color(0xFF4FCF7A),
    ];
    final color = colors[letter.codeUnitAt(0) % colors.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Center(
        child: Text(
          letter.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          if (count != null && count! > 0) ...[
            const SizedBox(width: 4),
            Text(
              '$count',
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostMenu extends StatelessWidget {
  final VoidCallback onDelete;

  const _PostMenu({required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: _surfaceHigh,
      icon: const Icon(Icons.more_horiz, color: _textSecondary, size: 20),
      onSelected: (v) {
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'delete',
          child: Text('Delete', style: TextStyle(color: _likeRed)),
        ),
      ],
    );
  }
}

class _ThreadTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _ThreadTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: _textPrimary, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _textSecondary),
        filled: true,
        fillColor: _surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }
}

class _MediaIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MediaIconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _textSecondary, size: 20),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PostButton({required this.onTap, this.label = 'Post'});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _textPrimary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _bg,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _CreateFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _CreateFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: _textPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.edit_outlined, color: _bg, size: 22),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.dynamic_feed_outlined,
              color: _textSecondary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No threads yet',
            style: TextStyle(
              color: _textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Be the first to post something.',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  final String label;
  const _SocialChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
