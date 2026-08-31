import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/rank_data.dart';
import '../services/api_service.dart';
import 'post.dart';

// THEME CONSTANTS
const _bg = Color(0xFFEFF3F9);
const _surface = Color(0xFFFFFFFF);
const _surfaceHigh = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);

const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF64748B);

const _primaryBlue = Color(0xFF2563EB);
const _primarySoft = Color(0xFFEAF2FF);
const _likeRed = Color(0xFFFF3B5C);

int _badgeCountFromUser(Map<String, dynamic> user) {
  for (final key in [
    "badges_count",
    "badge_count",
    "unlocked_badges_count",
    "achievements_count",
  ]) {
    final value = user[key];
    if (value != null) {
      return int.tryParse(value.toString()) ?? 0;
    }
  }

  return 0;
}

class CommunityPage extends StatefulWidget {
  final bool showOnlyMyPosts;

  const CommunityPage({super.key, this.showOnlyMyPosts = false});

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with TickerProviderStateMixin {
  List<Post> posts = [];
  bool _isLoading = true;
  bool _isPosting = false;
  Map<String, dynamic>? _currentUser;

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _commentController = TextEditingController();

  File? _selectedMedia;
  bool _selectedMediaIsVideo = false;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadCommunity();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  // HELPERS

  String get _currentUserName => (_currentUser?["name"] ?? "Runner").toString();

  String get _currentUserInitial {
    final name = _currentUserName.trim();
    return name.isEmpty ? "R" : name[0].toUpperCase();
  }

  String? get _currentUserAvatarUrl {
    final avatar = (_currentUser?["avatar_url"] ?? "").toString();
    return avatar.isEmpty ? null : avatar;
  }

  int? get _currentUserId {
    return int.tryParse((_currentUser?["id"] ?? "").toString());
  }

  List<Post> get _visiblePosts {
    if (!widget.showOnlyMyPosts) {
      return posts;
    }

    final userId = _currentUserId;
    if (userId == null) {
      return [];
    }

    return posts.where((post) => post.userId == userId).toList();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  String _exactTimestamp(DateTime dt) {
    final local = dt.toLocal();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';

    return '${months[local.month - 1]} ${local.day}, ${local.year} • $hour:$minute $period';
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
      avatarUrl: user["avatar_url"]?.toString(),
      badgeCount: _badgeCountFromUser(user),
      text: (data["content"] ?? "").toString(),
      timestamp: createdAt ?? DateTime.now(),
    );
  }

  Post _postFromApi(Map<String, dynamic> data) {
    final user = Map<String, dynamic>.from(data["user"] ?? {});
    final rawCreatedAt = (data["created_at"] ?? "").toString();
    final createdAt = DateTime.tryParse(rawCreatedAt)?.toLocal();
    final videoUrl = (data["video_url"] ?? "").toString();
    final imageUrl = (data["image_url"] ?? "").toString();
    final String? media;
    if (videoUrl.isNotEmpty) {
      media = videoUrl;
    } else if (imageUrl.isNotEmpty) {
      media = imageUrl;
    } else {
      media = null;
    }
    final comments = ((data["comments"] as List?) ?? [])
        .whereType<Map>()
        .map((comment) => _commentFromApi(Map<String, dynamic>.from(comment)))
        .toList();

    return Post(
      id: data["id"].toString(),
      title: (data["title"] ?? "Community post").toString(),
      content: (data["content"] ?? "").toString(),
      media: media,
      mediaIsRemote: true,
      mediaIsVideo: videoUrl.isNotEmpty,
      authorName: (user["name"] ?? "Runner").toString(),
      authorAvatarUrl: user["avatar_url"]?.toString(),
      authorBadgeCount: _badgeCountFromUser(user),
      userId: int.tryParse((user["id"] ?? "").toString()),
      likes: int.tryParse((data["likes_count"] ?? 0).toString()) ?? 0,
      likedByMe: data["liked_by_me"] == true,
      comments: comments,
      createdAt: createdAt,
    );
  }

  Future<void> _loadCommunity() async {
    final results = await Future.wait([
      ApiService().getUser(),
      ApiService().getCommunityPosts(),
    ]);

    if (!mounted) return;

    setState(() {
      _currentUser = results[0] as Map<String, dynamic>?;
      final data = results[1] as List<Map<String, dynamic>>;
      posts = data.map(_postFromApi).toList();
      _isLoading = false;
    });
  }

  // MEDIA PICKERS

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedMedia = File(picked.path);
        _selectedMediaIsVideo = false;
      });
    }
  }

  Future<void> _pickVideo() async {
    final picked = await _picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _selectedMedia = File(picked.path);
        _selectedMediaIsVideo = true;
      });
    }
  }

  // CRUD

  Future<void> _addPost() async {
    if (_isPosting) return;

    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please add a title.")));
      return;
    }

    if (content.isEmpty && _selectedMedia == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Add some content, an image, or a video."),
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isPosting = true);

    final result = await ApiService().createCommunityPost(
      title: title,
      content: content,
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
    _selectedMediaIsVideo = false;
    Navigator.pop(context);
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Move post to archive?"),
        content: const Text(
          "This post will be moved to your archive and permanently deleted after 30 days.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Move to archive"),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    final deleted = await ApiService().deleteCommunityPost(post.id);

    if (!mounted) return;

    if (deleted) {
      setState(() => posts.remove(post));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Post moved to archive. It will be deleted permanently after 30 days.",
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You can only delete your own posts.")),
    );
  }

  Future<void> _hidePost(Post post) async {
    final result = await ApiService().hideCommunityPost(post.id);

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        action: SnackBarAction(
          label: "Undo",
          onPressed: () async {
            final undoResult = await ApiService().unhideCommunityPost(post.id);
            if (!mounted || !undoResult.success) return;
            setState(() => posts.insert(0, post));
          },
        ),
      ),
    );

    setState(() => posts.remove(post));
  }

  Future<void> _showReportSheet(Post post) async {
    const otherReason = "__other_reason__";

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Report post",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Choose the closest reason. The post will be sent to moderators.",
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 12),
              _ReportReasonTile(
                icon: Icons.block_outlined,
                label: "Spam or misleading",
                onTap: () => Navigator.pop(ctx, "Spam or misleading"),
              ),
              _ReportReasonTile(
                icon: Icons.warning_amber_outlined,
                label: "Harassment or abuse",
                onTap: () => Navigator.pop(ctx, "Harassment or abuse"),
              ),
              _ReportReasonTile(
                icon: Icons.visibility_off_outlined,
                label: "Inappropriate content",
                onTap: () => Navigator.pop(ctx, "Inappropriate content"),
              ),
              _ReportReasonTile(
                icon: Icons.flag_outlined,
                label: "Other concern",
                onTap: () => Navigator.pop(ctx, otherReason),
              ),
            ],
          ),
        ),
      ),
    );

    if (reason == null) return;

    final finalReason = reason == otherReason
        ? await _showOtherReportReasonSheet()
        : reason;

    if (finalReason == null) return;

    final result = await ApiService().reportCommunityPost(
      postId: post.id,
      reason: finalReason,
    );

    if (!mounted) return;

    if (!result.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
      return;
    }

    setState(() => posts.remove(post));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  Future<String?> _showOtherReportReasonSheet() async {
    final controller = TextEditingController();
    String? errorText;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Other concern",
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Tell moderators what is wrong with this post.",
                style: TextStyle(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                autofocus: true,
                style: const TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: "Write the specific reason...",
                  errorText: errorText,
                  filled: true,
                  fillColor: _surfaceHigh,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _primaryBlue,
                      width: 1.5,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _likeRed),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(color: _likeRed, width: 1.5),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        final customReason = controller.text.trim();
                        if (customReason.isEmpty) {
                          setSheet(() {
                            errorText = "Please enter a reason.";
                          });
                          return;
                        }

                        Navigator.pop(ctx, customReason);
                      },
                      child: const Text("Submit"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    controller.dispose();
    return reason;
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

  void _openMediaViewer(Post post) {
    if (post.media == null) return;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: post.mediaIsVideo
                    ? _PostVideoPlayer(
                        source: post.media!,
                        isRemote: post.mediaIsRemote,
                        fit: BoxFit.contain,
                      )
                    : InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: post.mediaIsRemote
                            ? Image.network(
                                post.media!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(
                                      Icons.broken_image_outlined,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                              )
                            : Image.file(
                                File(post.media!),
                                fit: BoxFit.contain,
                              ),
                      ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // DIALOGS / SHEETS

  void _showCreateSheet() {
    _selectedMedia = null;
    _selectedMediaIsVideo = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 14,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  _Avatar(
                    letter: _currentUserInitial,
                    size: 42,
                    imageUrl: _currentUserAvatarUrl,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create Post',
                          style: TextStyle(
                            color: _textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Share something with the community',
                          style: TextStyle(
                            color: _textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: _textSecondary),
                  ),
                ],
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
                hint: "What's on your mind? (optional with media)",
                maxLines: 5,
              ),

              const SizedBox(height: 12),

              if (_selectedMedia != null) ...[
                _selectedMediaIsVideo
                    ? Container(
                        height: 150,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: _surfaceHigh,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _border),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_fill_rounded,
                            color: _primaryBlue,
                            size: 52,
                          ),
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          _selectedMedia!,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                const SizedBox(height: 10),
              ],

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Replies',
                            style: TextStyle(
                              color: _textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Join the conversation',
                            style: TextStyle(
                              color: _textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, color: _textSecondary),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              const Divider(color: _border, height: 1),

              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(ctx).height * 0.42,
                ),
                child: post.comments.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No replies yet.\nBe the first to reply.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _textSecondary,
                            height: 1.6,
                            fontWeight: FontWeight.w600,
                          ),
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
                            exactTime: _exactTimestamp(c.timestamp),
                            onLike: () => _toggleCommentLike(c, setSheet),
                          );
                        },
                      ),
              ),

              const Divider(color: _border, height: 1),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Row(
                  children: [
                    _Avatar(
                      letter: _currentUserInitial,
                      size: 34,
                      imageUrl: _currentUserAvatarUrl,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Add a reply…',
                          hintStyle: const TextStyle(
                            color: _textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          filled: true,
                          fillColor: _surfaceHigh,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _submitComment(post, setSheet),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: _primaryBlue,
                        foregroundColor: Colors.white,
                        fixedSize: const Size(44, 44),
                      ),
                      onPressed: () => _submitComment(post, setSheet),
                      icon: const Icon(Icons.send_rounded, size: 20),
                      tooltip: "Send reply",
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

  void _showEditSheet(Post post) {
    _titleController.text = post.title;
    _contentController.text = post.content;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Edit post',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
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
                onTap: () async {
                  final title = _titleController.text.trim();
                  final content = _contentController.text.trim();

                  if (title.isEmpty ||
                      (content.isEmpty && post.media == null)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Add a title and either content or media.",
                        ),
                      ),
                    );
                    return;
                  }

                  final result = await ApiService().updateCommunityPost(
                    postId: post.id,
                    title: title,
                    content: content,
                  );

                  if (!mounted) return;

                  if (!result.success || result.data == null) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(result.message)));
                    return;
                  }

                  final updated = _postFromApi(result.data!);
                  setState(() {
                    post.title = updated.title;
                    post.content = updated.content;
                  });
                  _titleController.clear();
                  _contentController.clear();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _visiblePosts;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        floatingActionButton: _CreateFAB(onTap: _showCreateSheet),
        body: SafeArea(
          child: Column(
            children: [
              _CommunityHeader(
                onBack: () => Navigator.pop(context),
                onInfo: _showAboutSheet,
                title: widget.showOnlyMyPosts ? "My Community" : "Community",
                subtitle: widget.showOnlyMyPosts
                    ? "Your posts and community activity"
                    : "Share updates with other runners",
              ),

              Expanded(
                child: _isLoading
                    ? const _CommunityLoadingState()
                    : visiblePosts.isEmpty
                    ? _EmptyState(
                        title: widget.showOnlyMyPosts
                            ? "No posts yet"
                            : "No community posts yet",
                        message: widget.showOnlyMyPosts
                            ? "Your community posts will appear here."
                            : "Be the first one to share something.",
                      )
                    : RefreshIndicator(
                        onRefresh: _loadCommunity,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: visiblePosts.length,
                          itemBuilder: (_, i) {
                            final post = visiblePosts[i];

                            return _PostTile(
                              post: post,
                              timeAgo: _timeAgo(post.createdAt),
                              exactTime: _exactTimestamp(post.createdAt),
                              canDelete:
                                  _currentUserId != null &&
                                  post.userId == _currentUserId,
                              onLike: () => _toggleLike(post),
                              onComment: () => _showCommentsSheet(post),
                              onEdit: () => _showEditSheet(post),
                              onDelete: () => _deletePost(post),
                              onHide: () => _hidePost(post),
                              onReport: () => _showReportSheet(post),
                              onMediaTap: () => _openMediaViewer(post),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Racetech',
              style: TextStyle(
                color: _textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A community for riders and event enthusiasts. Join events, connect, and grow together!',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
                height: 1.6,
                fontWeight: FontWeight.w500,
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

// SUB-WIDGETS

class _CommunityHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final String title;
  final String subtitle;

  const _CommunityHeader({
    required this.onBack,
    required this.onInfo,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: _primarySoft,
                foregroundColor: _primaryBlue,
              ),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            IconButton.filledTonal(
              style: IconButton.styleFrom(
                backgroundColor: _primarySoft,
                foregroundColor: _primaryBlue,
              ),
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final Post post;
  final String timeAgo;
  final String exactTime;
  final bool canDelete;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onHide;
  final VoidCallback onReport;
  final VoidCallback onMediaTap;

  const _PostTile({
    required this.post,
    required this.timeAgo,
    required this.exactTime,
    required this.canDelete,
    required this.onLike,
    required this.onComment,
    required this.onEdit,
    required this.onDelete,
    required this.onHide,
    required this.onReport,
    required this.onMediaTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            letter: post.authorName.isEmpty ? "R" : post.authorName[0],
            size: 44,
            imageUrl: post.authorAvatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        post.authorName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
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
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    canDelete
                        ? _PostOwnerMenu(onEdit: onEdit, onDelete: onDelete)
                        : _PostModerationMenu(
                            onHide: onHide,
                            onReport: onReport,
                          ),
                  ],
                ),
                const SizedBox(height: 5),
                _CommunityRankPill(
                  title: rankTitleForBadges(post.authorBadgeCount),
                ),
                const SizedBox(height: 6),
                _TimestampRow(time: exactTime),
                const SizedBox(height: 8),
                if (post.title.isNotEmpty) ...[
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                Text(
                  post.content,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (post.media != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onMediaTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        children: [
                          post.mediaIsVideo
                              ? _PostVideoPlayer(
                                  source: post.media!,
                                  isRemote: post.mediaIsRemote,
                                  fit: BoxFit.cover,
                                  height: 220,
                                )
                              : post.mediaIsRemote
                              ? Image.network(
                                  post.media!,
                                  height: 220,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        height: 150,
                                        width: double.infinity,
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
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: const Icon(
                                Icons.open_in_full,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
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
                    const SizedBox(width: 18),
                    _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      color: _textSecondary,
                      count: post.comments.length,
                      onTap: onComment,
                    ),
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

class _PostVideoPlayer extends StatefulWidget {
  final String source;
  final bool isRemote;
  final BoxFit fit;
  final double? height;

  const _PostVideoPlayer({
    required this.source,
    required this.isRemote,
    this.fit = BoxFit.contain,
    this.height,
  });

  @override
  State<_PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<_PostVideoPlayer> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialize;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.isRemote
        ? VideoPlayerController.networkUrl(Uri.parse(widget.source))
        : VideoPlayerController.file(File(widget.source));
    _initialize = _controller
        .initialize()
        .then((_) {
          _controller.setLooping(true);
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _hasError = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (!_controller.value.isInitialized) return;

    setState(() {
      _controller.value.isPlaying ? _controller.pause() : _controller.play();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: widget.height ?? 220,
        width: double.infinity,
        color: _surfaceHigh,
        alignment: Alignment.center,
        child: const Icon(Icons.videocam_off_outlined, color: _textSecondary),
      );
    }

    return FutureBuilder<void>(
      future: _initialize,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !_controller.value.isInitialized) {
          return Container(
            height: widget.height ?? 220,
            width: double.infinity,
            color: _surfaceHigh,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          );
        }

        final size = _controller.value.size;
        final video = widget.height == null
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : SizedBox(
                height: widget.height,
                width: double.infinity,
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              );

        return GestureDetector(
          onTap: _togglePlayback,
          child: Stack(
            alignment: Alignment.center,
            children: [
              video,
              AnimatedOpacity(
                opacity: _controller.value.isPlaying ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _controller,
                  allowScrubbing: true,
                  padding: EdgeInsets.zero,
                  colors: const VideoProgressColors(
                    playedColor: _primaryBlue,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.black26,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimestampRow extends StatelessWidget {
  final String time;
  final bool compact;

  const _TimestampRow({required this.time, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.schedule_outlined,
          size: compact ? 13 : 14,
          color: _textSecondary,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _textSecondary,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String timeAgo;
  final String exactTime;
  final VoidCallback onLike;

  const _CommentTile({
    required this.comment,
    required this.timeAgo,
    required this.exactTime,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            letter: comment.avatarInitial,
            size: 34,
            imageUrl: comment.avatarUrl,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        comment.author,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        color: _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _CommunityRankPill(
                  title: rankTitleForBadges(comment.badgeCount),
                  compact: true,
                ),
                const SizedBox(height: 4),
                _TimestampRow(time: exactTime, compact: true),
                const SizedBox(height: 5),
                Text(
                  comment.text,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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
                            fontWeight: FontWeight.w600,
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
  final String? imageUrl;

  const _Avatar({required this.letter, required this.size, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF5B4FCF),
      const Color(0xFFCF4F8A),
      const Color(0xFF4F9BCF),
      const Color(0xFFCF8A4F),
      const Color(0xFF4FCF7A),
    ];
    final color = colors[letter.codeUnitAt(0) % colors.length];

    final url = imageUrl?.trim() ?? "";

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: url.isNotEmpty
          ? Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _AvatarInitial(letter: letter, size: size);
              },
            )
          : _AvatarInitial(letter: letter, size: size),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String letter;
  final double size;

  const _AvatarInitial({required this.letter, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}

class _CommunityRankPill extends StatelessWidget {
  final String title;
  final bool compact;

  const _CommunityRankPill({required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech_outlined,
            color: _primaryBlue,
            size: compact ? 12 : 13,
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 130 : 170),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _primaryBlue,
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
              style: const TextStyle(
                color: _textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PostOwnerMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PostOwnerMenu({required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: _surface,
      icon: const Icon(Icons.more_horiz, color: _textSecondary, size: 20),
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, color: _primaryBlue, size: 18),
              SizedBox(width: 8),
              Text(
                'Edit',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: _likeRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Delete',
                style: TextStyle(color: _likeRed, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PostModerationMenu extends StatelessWidget {
  final VoidCallback onHide;
  final VoidCallback onReport;

  const _PostModerationMenu({required this.onHide, required this.onReport});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: _surface,
      icon: const Icon(Icons.more_horiz, color: _textSecondary, size: 20),
      onSelected: (v) {
        if (v == 'hide') onHide();
        if (v == 'report') onReport();
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'hide',
          child: Row(
            children: [
              Icon(
                Icons.visibility_off_outlined,
                color: _textSecondary,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'Hide',
                style: TextStyle(
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: _likeRed, size: 18),
              SizedBox(width: 8),
              Text(
                'Report',
                style: TextStyle(color: _likeRed, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportReasonTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ReportReasonTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _primaryBlue),
      title: Text(
        label,
        style: const TextStyle(
          color: _textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: _textSecondary),
      onTap: onTap,
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
      style: const TextStyle(
        color: _textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: _textSecondary,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: _surfaceHigh,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
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
    return IconButton.filledTonal(
      style: IconButton.styleFrom(
        backgroundColor: _primarySoft,
        foregroundColor: _primaryBlue,
      ),
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _PostButton({required this.onTap, this.label = 'Post'});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

class _CreateFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: _primaryBlue,
      foregroundColor: Colors.white,
      elevation: 4,
      onPressed: onTap,
      child: const Icon(Icons.edit_outlined),
    );
  }
}

class _CommunityLoadingState extends StatelessWidget {
  const _CommunityLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: 3,
      itemBuilder: (context, index) {
        return const _CommunitySkeletonPost();
      },
    );
  }
}

class _CommunitySkeletonPost extends StatelessWidget {
  const _CommunitySkeletonPost();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              _SkeletonBlock(height: 44, width: 44, radius: 999),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBlock(
                      height: 14,
                      width: double.infinity,
                      radius: 8,
                    ),
                    SizedBox(height: 8),
                    _SkeletonBlock(height: 11, width: 110, radius: 8),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          _SkeletonBlock(height: 15, width: 190, radius: 8),
          SizedBox(height: 10),
          _SkeletonBlock(height: 12, width: double.infinity, radius: 8),
          SizedBox(height: 8),
          _SkeletonBlock(height: 12, width: 240, radius: 8),
          SizedBox(height: 14),
          _SkeletonBlock(height: 120, width: double.infinity, radius: 18),
        ],
      ),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const _SkeletonBlock({
    required this.height,
    required this.width,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: _border,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dynamic_feed_outlined,
                color: _primaryBlue,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _primaryBlue,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
