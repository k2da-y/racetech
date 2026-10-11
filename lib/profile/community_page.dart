import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../data/rank_data.dart';
import '../services/api_service.dart';
import '../utils/certificate_count.dart';
import 'post.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME (soft indigo – same tokens as the rest of the app)
// ─────────────────────────────────────────────────────────────────────────────

const _primary = Color(0xFF6366F1);
const _primaryDeep = Color(0xFF4F46E5);
const _accent = Color(0xFF0EA5E9);
const _primarySoft = Color(0xFFEEF2FF);

const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);

const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);

const _likeRed = Color(0xFFF43F5E);
const _danger = Color(0xFFEF4444);
const _dangerSoft = Color(0xFFFEF2F2);

const _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_primaryDeep, _primary, _accent],
);

ThemeData _brandTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      primary: _primary,
      secondary: _accent,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
      error: _danger,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: _primary,
      selectionColor: Color(0x336366F1),
      selectionHandleColor: _primary,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: _primary),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

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
  bool _loadFailed = false;
  bool _isPosting = false;
  bool _isCommenting = false;
  final Set<String> _likingIds = {};
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

  String get _currentUserFirstName {
    final name = _currentUserName.trim();
    if (name.isEmpty) return "Runner";
    return name.split(RegExp(r"\s+")).first;
  }

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

  Widget _themed(Widget child) => Theme(data: _brandTheme(context), child: child);

  void _snack(String message, {SnackBarAction? action}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        action: action == null
            ? null
            : SnackBarAction(
          label: action.label,
          textColor: const Color(0xFFA5B4FC),
          onPressed: action.onPressed,
        ),
      ),
    );
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
      badgeCount: certificateCountOrZero(user),
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
      authorBadgeCount: certificateCountOrZero(user),
      userId: int.tryParse((user["id"] ?? "").toString()),
      likes: int.tryParse((data["likes_count"] ?? 0).toString()) ?? 0,
      likedByMe: data["liked_by_me"] == true,
      comments: comments,
      createdAt: createdAt,
    );
  }

  Future<void> _loadCommunity() async {
    try {
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
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadFailed = true;
      });
    }
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
      _snack("Please add a title.");
      return;
    }

    if (content.isEmpty && _selectedMedia == null) {
      _snack("Add some content, an image, or a video.");
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
      _snack(result.message);
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
      barrierColor: const Color(0x8C0F172A),
      builder: (dialogContext) => _themed(
        _ConfirmDialog(
          icon: Icons.archive_outlined,
          title: "Move post to archive?",
          message:
          "This post will be moved to your archive and permanently deleted after 30 days.",
          confirmLabel: "Move to archive",
          onCancel: () => Navigator.pop(dialogContext, false),
          onConfirm: () => Navigator.pop(dialogContext, true),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    final deleted = await ApiService().deleteCommunityPost(post.id);

    if (!mounted) return;

    if (deleted) {
      setState(() => posts.remove(post));
      _snack(
        "Post moved to archive. It will be deleted permanently after 30 days.",
      );
      return;
    }

    _snack("You can only delete your own posts.");
  }

  Future<void> _hidePost(Post post) async {
    final result = await ApiService().hideCommunityPost(post.id);

    if (!mounted) return;

    if (!result.success) {
      _snack(result.message);
      return;
    }

    _snack(
      result.message,
      action: SnackBarAction(
        label: "Undo",
        onPressed: () async {
          final undoResult = await ApiService().unhideCommunityPost(post.id);
          if (!mounted || !undoResult.success) return;
          setState(() => posts.insert(0, post));
        },
      ),
    );

    setState(() => posts.remove(post));
  }

  Future<void> _showReportSheet(Post post) async {
    const otherReason = "__other_reason__";

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _themed(
        _SheetContainer(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: 18),
                const _SheetHeader(
                  icon: Icons.flag_outlined,
                  iconColor: _danger,
                  iconBackground: _dangerSoft,
                  title: "Report post",
                  subtitle:
                  "Choose the closest reason. The post will be sent to moderators.",
                ),
                const SizedBox(height: 18),
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
                  icon: Icons.edit_note_outlined,
                  label: "Other concern",
                  onTap: () => Navigator.pop(ctx, otherReason),
                ),
              ],
            ),
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
      _snack(result.message);
      return;
    }

    setState(() => posts.remove(post));
    _snack(result.message);
  }

  Future<String?> _showOtherReportReasonSheet() async {
    final controller = TextEditingController();
    String? errorText;

    final reason = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _themed(
        StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: _SheetContainer(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: _SheetHandle()),
                    const SizedBox(height: 18),
                    const _SheetHeader(
                      icon: Icons.edit_note_outlined,
                      iconColor: _danger,
                      iconBackground: _dangerSoft,
                      title: "Other concern",
                      subtitle: "Tell moderators what is wrong with this post.",
                    ),
                    const SizedBox(height: 16),
                    _ThreadTextField(
                      controller: controller,
                      hint: "Write the specific reason...",
                      maxLines: 4,
                      maxLength: 500,
                      autofocus: true,
                      errorText: errorText,
                      onChanged: (_) {
                        if (errorText != null) {
                          setSheet(() => errorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _SecondaryButton(
                            label: "Cancel",
                            onTap: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _PostButton(
                            label: "Submit",
                            icon: Icons.send_rounded,
                            expand: true,
                            onTap: () {
                              final customReason = controller.text.trim();
                              if (customReason.isEmpty) {
                                HapticFeedback.heavyImpact();
                                setSheet(() {
                                  errorText = "Please enter a reason.";
                                });
                                return;
                              }

                              Navigator.pop(ctx, customReason);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    controller.dispose();
    return reason;
  }

  Future<void> _toggleLike(Post post) async {
    if (_likingIds.contains(post.id)) return;
    _likingIds.add(post.id);

    HapticFeedback.lightImpact();

    try {
      final result = await ApiService().toggleCommunityLike(post.id);

      if (!mounted) return;

      if (result == null) {
        _snack("Unable to update like.");
        return;
      }

      setState(() {
        post.likedByMe = result["liked"] == true;
        post.likes =
            int.tryParse((result["likes_count"] ?? 0).toString()) ?? 0;
      });
    } finally {
      _likingIds.remove(post.id);
    }
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
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (dialogContext) => Dialog.fullscreen(
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
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                        ),
                      );
                    },
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
                child: _GlassButton(
                  icon: Icons.close_rounded,
                  tooltip: "Close",
                  onTap: () => Navigator.pop(dialogContext),
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
    String? titleError;
    String? bodyError;

    showDialog(
      context: context,
      barrierColor: const Color(0x8C0F172A),
      builder: (ctx) => _themed(
        StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> submit() async {
              final title = _titleController.text.trim();
              final content = _contentController.text.trim();
              final missingTitle = title.isEmpty;
              final missingBody = content.isEmpty && _selectedMedia == null;

              if (missingTitle || missingBody) {
                HapticFeedback.heavyImpact();
                setModal(() {
                  titleError = missingTitle ? "Please add a title." : null;
                  bodyError = missingBody
                      ? "Add some content, an image, or a video."
                      : null;
                });
                return;
              }

              final future = _addPost();
              setModal(() {});
              await future;
              if (ctx.mounted) setModal(() {});
            }

            return PopScope(
              canPop: !_isPosting,
              child: _FormDialog(
                children: [
                  _DialogHeader(
                    leading: _Avatar(
                      letter: _currentUserInitial,
                      size: 44,
                      imageUrl: _currentUserAvatarUrl,
                      ring: true,
                    ),
                    title: "Create Post",
                    subtitle: "Share something with the community",
                    onClose: _isPosting ? null : () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel("Title"),
                  _ThreadTextField(
                    controller: _titleController,
                    hint: 'Title…',
                    maxLines: 1,
                    enabled: !_isPosting,
                    errorText: titleError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (titleError != null) {
                        setModal(() => titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel("Message"),
                  _ThreadTextField(
                    controller: _contentController,
                    hint: "What's on your mind? (optional with media)",
                    maxLines: 5,
                    enabled: !_isPosting,
                    errorText: bodyError,
                    onChanged: (_) {
                      if (bodyError != null) {
                        setModal(() => bodyError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_selectedMedia != null) ...[
                    _SelectedMediaPreview(
                      file: _selectedMedia!,
                      isVideo: _selectedMediaIsVideo,
                      onRemove: _isPosting
                          ? null
                          : () => setModal(() {
                        _selectedMedia = null;
                        _selectedMediaIsVideo = false;
                      }),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      _MediaChip(
                        icon: Icons.image_outlined,
                        label: "Photo",
                        onTap: _isPosting
                            ? null
                            : () async {
                          await _pickImage();
                          if (ctx.mounted) {
                            setModal(() {
                              if (_selectedMedia != null) {
                                bodyError = null;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _MediaChip(
                        icon: Icons.videocam_outlined,
                        label: "Video",
                        onTap: _isPosting
                            ? null
                            : () async {
                          await _pickVideo();
                          if (ctx.mounted) {
                            setModal(() {
                              if (_selectedMedia != null) {
                                bodyError = null;
                              }
                            });
                          }
                        },
                      ),
                      const Spacer(),
                      _PostButton(
                        label: _isPosting ? "Posting..." : "Post",
                        icon: Icons.send_rounded,
                        loading: _isPosting,
                        onTap: _isPosting ? null : submit,
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCommentsSheet(Post post) {
    _commentController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _themed(
        StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: _SheetContainer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  const _SheetHandle(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const _IconTile(icon: Icons.forum_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Replies',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _CountBadge(count: post.comments.length),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                post.title.isNotEmpty
                                    ? post.title
                                    : 'Join the conversation',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _muted,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _CloseButton(onTap: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: _border, height: 1),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(ctx).height * 0.45,
                    ),
                    child: post.comments.isEmpty
                        ? const _RepliesEmpty()
                        : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: post.comments.length,
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
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: _border)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _Avatar(
                            letter: _currentUserInitial,
                            size: 36,
                            imageUrl: _currentUserAvatarUrl,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            minLines: 1,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            style: const TextStyle(
                              color: _ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a reply…',
                              hintStyle: const TextStyle(
                                color: _faint,
                                fontWeight: FontWeight.w500,
                              ),
                              filled: true,
                              fillColor: _fieldFill,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 13,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(color: _border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(
                                  color: _primary,
                                  width: 1.5,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) =>
                                _submitComment(post, setSheet, ctx),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _commentController,
                          builder: (context, value, _) {
                            final canSend =
                                value.text.trim().isNotEmpty && !_isCommenting;
                            return _SendButton(
                              loading: _isCommenting,
                              enabled: canSend,
                              onTap: () => _submitComment(post, setSheet, ctx),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitComment(
      Post post,
      StateSetter setSheet,
      BuildContext sheetContext,
      ) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isCommenting) return;

    HapticFeedback.lightImpact();
    _isCommenting = true;
    setSheet(() {});

    try {
      final createdComment = await ApiService().addCommunityComment(
        postId: post.id,
        content: text,
      );

      if (!mounted) return;

      if (createdComment == null) {
        _snack("Unable to add comment.");
        return;
      }

      setState(() {
        post.comments.add(_commentFromApi(createdComment));
      });
      _commentController.clear();
    } finally {
      _isCommenting = false;
      if (mounted && sheetContext.mounted) setSheet(() {});
    }
  }

  void _showEditSheet(Post post) {
    _titleController.text = post.title;
    _contentController.text = post.content;
    bool isUpdating = false;
    String? titleError;
    String? bodyError;

    showDialog(
      context: context,
      barrierColor: const Color(0x8C0F172A),
      builder: (ctx) => _themed(
        StatefulBuilder(
          builder: (ctx, setModal) {
            Future<void> submit() async {
              final title = _titleController.text.trim();
              final content = _contentController.text.trim();
              final missingTitle = title.isEmpty;
              final missingBody = content.isEmpty && post.media == null;

              if (missingTitle || missingBody) {
                HapticFeedback.heavyImpact();
                setModal(() {
                  titleError = missingTitle ? "Please add a title." : null;
                  bodyError = missingBody
                      ? "Add a title and either content or media."
                      : null;
                });
                return;
              }

              setModal(() => isUpdating = true);

              final result = await ApiService().updateCommunityPost(
                postId: post.id,
                title: title,
                content: content,
              );

              if (!mounted) return;

              if (!result.success || result.data == null) {
                if (ctx.mounted) setModal(() => isUpdating = false);
                _snack(result.message);
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
            }

            return PopScope(
              canPop: !isUpdating,
              child: _FormDialog(
                children: [
                  _DialogHeader(
                    leading: const _IconTile(icon: Icons.edit_outlined),
                    title: 'Edit post',
                    subtitle: 'Update your title or message',
                    onClose: isUpdating ? null : () => Navigator.pop(ctx),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel("Title"),
                  _ThreadTextField(
                    controller: _titleController,
                    hint: 'Title…',
                    maxLines: 1,
                    enabled: !isUpdating,
                    errorText: titleError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (titleError != null) {
                        setModal(() => titleError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel("Message"),
                  _ThreadTextField(
                    controller: _contentController,
                    hint: 'Content…',
                    maxLines: 5,
                    enabled: !isUpdating,
                    errorText: bodyError,
                    onChanged: (_) {
                      if (bodyError != null) {
                        setModal(() => bodyError = null);
                      }
                    },
                  ),
                  if (post.media != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          post.mediaIsVideo
                              ? Icons.videocam_outlined
                              : Icons.image_outlined,
                          size: 16,
                          color: _faint,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            post.mediaIsVideo
                                ? "The attached video stays the same."
                                : "The attached photo stays the same.",
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SecondaryButton(
                          label: "Cancel",
                          onTap: isUpdating ? null : () => Navigator.pop(ctx),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PostButton(
                          label: isUpdating ? 'Updating...' : 'Update',
                          icon: Icons.check_rounded,
                          loading: isUpdating,
                          expand: true,
                          onTap: isUpdating ? null : submit,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    ).then((_) {
      _titleController.clear();
      _contentController.clear();
    });
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final visiblePosts = _visiblePosts;
    final canPop = Navigator.canPop(context);

    final header = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 36),
          child: _CommunityHero(
            title: widget.showOnlyMyPosts ? "My Community" : "Community",
            subtitle: widget.showOnlyMyPosts
                ? "Your posts and community activity"
                : "Share updates with other participants",
            isLoading: _isLoading,
            postCount: visiblePosts.length,
            showOnlyMyPosts: widget.showOnlyMyPosts,
            onBack: canPop ? () => Navigator.pop(context) : null,
            onInfo: _showAboutSheet,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 0,
          child: _ComposerCard(
            initial: _currentUserInitial,
            avatarUrl: _currentUserAvatarUrl,
            prompt: _currentUser == null
                ? "What's on your mind?"
                : "What's on your mind, $_currentUserFirstName?",
            onTap: _showCreateSheet,
          ),
        ),
      ],
    );

    return Theme(
      data: _brandTheme(context),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _background,
          floatingActionButton: _CreateFAB(onTap: _showCreateSheet),
          body: RefreshIndicator(
            color: _primary,
            backgroundColor: Colors.white,
            edgeOffset: MediaQuery.paddingOf(context).top,
            onRefresh: _loadCommunity,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverToBoxAdapter(child: header),
                if (_isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 22, 16, 110),
                    sliver: SliverList.builder(
                      itemCount: 3,
                      itemBuilder: (context, index) =>
                      const _CommunitySkeletonPost(),
                    ),
                  )
                else if (visiblePosts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _loadFailed
                        ? _ErrorState(onRetry: _retryLoad)
                        : _EmptyState(
                      title: widget.showOnlyMyPosts
                          ? "No posts yet"
                          : "No community posts yet",
                      message: widget.showOnlyMyPosts
                          ? "Your community posts will appear here."
                          : "Be the first one to share something.",
                      onCreate: _showCreateSheet,
                    ),
                  )
                else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_loadFailed) ...[
                              _RefreshErrorBanner(onRetry: _retryLoad),
                              const SizedBox(height: 14),
                            ],
                            Row(
                              children: [
                                Text(
                                  widget.showOnlyMyPosts
                                      ? "Your posts"
                                      : "Latest posts",
                                  style: const TextStyle(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CountBadge(count: visiblePosts.length),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                      sliver: SliverList.builder(
                        itemCount: visiblePosts.length,
                        itemBuilder: (_, i) {
                          final post = visiblePosts[i];

                          return _PostTile(
                            key: ValueKey("post-${post.id}"),
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
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _retryLoad() {
    setState(() {
      _isLoading = posts.isEmpty;
      _loadFailed = false;
    });
    _loadCommunity();
  }

  void _showAboutSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _themed(
        _SheetContainer(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: _SheetHandle()),
                const SizedBox(height: 22),
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: _heroGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x406366F1),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Racetech',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A community for riders and event enthusiasts. Join events, connect, and grow together!',
                  style: TextStyle(
                    color: _body,
                    fontSize: 14,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SocialChip(label: 'Facebook', icon: Icons.facebook),
                    _SocialChip(
                      label: 'Instagram',
                      icon: Icons.camera_alt_outlined,
                    ),
                    _SocialChip(
                      label: 'TikTok',
                      icon: Icons.music_note_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO + COMPOSER
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isLoading;
  final int postCount;
  final bool showOnlyMyPosts;
  final VoidCallback? onBack;
  final VoidCallback onInfo;

  const _CommunityHero({
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.postCount,
    required this.showOnlyMyPosts,
    required this.onBack,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final countLabel = isLoading
        ? "Loading posts…"
        : "$postCount ${postCount == 1 ? 'post' : 'posts'}";

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, topInset + 10, 20, 62),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                _GlassButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: "Back",
                  onTap: onBack!,
                ),
              const Spacer(),
              _GlassButton(
                icon: Icons.info_outline_rounded,
                tooltip: "About",
                onTap: onInfo,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  showOnlyMyPosts
                      ? Icons.person_pin_outlined
                      : Icons.forum_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroPill(icon: Icons.dynamic_feed_outlined, label: countLabel),
              _HeroPill(
                icon: showOnlyMyPosts
                    ? Icons.person_outline_rounded
                    : Icons.public_rounded,
                label: showOnlyMyPosts ? "Only your posts" : "Community feed",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HeroPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: CircleBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            width: 42,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _ComposerCard extends StatelessWidget {
  final String initial;
  final String? avatarUrl;
  final String prompt;
  final VoidCallback onTap;

  const _ComposerCard({
    required this.initial,
    required this.avatarUrl,
    required this.prompt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2E6366F1),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _Avatar(letter: initial, size: 42, imageUrl: avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 44,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: _border),
                    ),
                    child: Text(
                      prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _faint,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.photo_library_outlined,
                    color: _primary,
                    size: 21,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// POST CARD
// ─────────────────────────────────────────────────────────────────────────────

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
    super.key,
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
    final commentCount = post.comments.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                  letter: post.authorName.isEmpty ? "R" : post.authorName[0],
                  size: 44,
                  imageUrl: post.authorAvatarUrl,
                  ring: true,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          if (canDelete) ...[
                            const SizedBox(width: 6),
                            const _YouTag(),
                          ],
                          const SizedBox(width: 6),
                          Text(
                            "· $timeAgo",
                            style: const TextStyle(
                              color: _faint,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      _CommunityRankPill(
                        title: rankTitleForBadges(post.authorBadgeCount),
                      ),
                    ],
                  ),
                ),
                canDelete
                    ? _PostOwnerMenu(onEdit: onEdit, onDelete: onDelete)
                    : _PostModerationMenu(onHide: onHide, onReport: onReport),
              ],
            ),
          ),

          // Text
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.title.isNotEmpty)
                  Text(
                    post.title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      letterSpacing: -0.2,
                      height: 1.3,
                    ),
                  ),
                if (post.title.isNotEmpty && post.content.isNotEmpty)
                  const SizedBox(height: 6),
                if (post.content.isNotEmpty)
                  Text(
                    post.content,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),

          // Media
          if (post.media != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: _PostMedia(post: post, onOpen: onMediaTap),
            ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _TimestampRow(time: exactTime, compact: true),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Container(
              padding: const EdgeInsets.only(top: 8),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  _ReactionButton(
                    icon: post.likedByMe
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    label: post.likes > 0 ? '${post.likes}' : 'Like',
                    color: post.likedByMe ? _likeRed : _muted,
                    active: post.likedByMe,
                    tooltip: post.likedByMe ? "Unlike" : "Like",
                    onTap: onLike,
                  ),
                  const SizedBox(width: 6),
                  _ReactionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: commentCount > 0
                        ? '$commentCount ${commentCount == 1 ? 'reply' : 'replies'}'
                        : 'Reply',
                    color: _muted,
                    active: false,
                    tooltip: "View replies",
                    onTap: onComment,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostMedia extends StatelessWidget {
  final Post post;
  final VoidCallback onOpen;

  const _PostMedia({required this.post, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final Widget media;

    if (post.mediaIsVideo) {
      media = _PostVideoPlayer(
        source: post.media!,
        isRemote: post.mediaIsRemote,
        fit: BoxFit.cover,
        height: 230,
      );
    } else if (post.mediaIsRemote) {
      media = GestureDetector(
        onTap: onOpen,
        child: Image.network(
          post.media!,
          height: 230,
          width: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const _Pulse(
              child: _SkeletonBlock(
                height: 230,
                width: double.infinity,
                radius: 0,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            height: 150,
            width: double.infinity,
            color: _fieldFill,
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: _faint, size: 30),
                SizedBox(height: 6),
                Text(
                  "Image unavailable",
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      media = GestureDetector(
        onTap: onOpen,
        child: Image.file(
          File(post.media!),
          height: 230,
          width: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          media,
          Positioned(
            right: 10,
            top: 10,
            child: Tooltip(
              message: "View full screen",
              child: Material(
                color: Colors.black.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpen,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool active;
  final String tooltip;
  final VoidCallback onTap;

  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.active,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: Icon(
                    icon,
                    key: ValueKey(icon),
                    size: 19,
                    color: color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: active ? color : _muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YouTag extends StatelessWidget {
  const _YouTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        "You",
        style: TextStyle(
          color: _primary,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
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
        color: _fieldFill,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam_off_outlined, color: _faint, size: 30),
            SizedBox(height: 6),
            Text(
              "Video unavailable",
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
            color: const Color(0xFF0F172A),
            alignment: Alignment.center,
            child: const SizedBox(
              height: 28,
              width: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                color: Colors.white,
              ),
            ),
          );
        }

        final size = _controller.value.size;
        final video = widget.height == null
            ? AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        )
            : Container(
          height: widget.height,
          width: double.infinity,
          color: Colors.black,
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
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
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
                    playedColor: _primary,
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
          color: _faint,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            time,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _faint,
              fontSize: compact ? 11.5 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMMENTS
// ─────────────────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
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
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 12),
                  decoration: const BoxDecoration(
                    color: _fieldFill,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(6),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(18),
                    ),
                    border: Border.fromBorderSide(BorderSide(color: _border)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              comment.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "· $timeAgo",
                            style: const TextStyle(
                              color: _faint,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _CommunityRankPill(
                        title: rankTitleForBadges(comment.badgeCount),
                        compact: true,
                      ),
                      const SizedBox(height: 7),
                      Text(
                        comment.text,
                        style: const TextStyle(
                          color: _body,
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 0, 2),
                  child: Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(99),
                        onTap: onLike,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.likedByMe
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 16,
                                color: comment.likedByMe ? _likeRed : _faint,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                comment.likes > 0
                                    ? '${comment.likes}'
                                    : 'Like',
                                style: TextStyle(
                                  color: comment.likedByMe ? _likeRed : _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: _TimestampRow(time: exactTime, compact: true),
                      ),
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

class _RepliesEmpty extends StatelessWidget {
  const _RepliesEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: const BoxDecoration(
              color: _primarySoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: _primary,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'No replies yet.\nBe the first to reply.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              height: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _SendButton({
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: "Send reply",
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          gradient: enabled || loading ? _heroGradient : null,
          color: enabled || loading ? null : _border,
          shape: BoxShape.circle,
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(
              child: loading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
                  : Icon(
                Icons.send_rounded,
                size: 20,
                color: enabled ? Colors.white : _faint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AVATAR + RANK
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String letter;
  final double size;
  final String? imageUrl;
  final bool ring;

  const _Avatar({
    required this.letter,
    required this.size,
    this.imageUrl,
    this.ring = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFFEC4899),
      const Color(0xFF0EA5E9),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
    ];
    final safeLetter = letter.isEmpty ? "R" : letter;
    final color = colors[safeLetter.codeUnitAt(0) % colors.length];

    final url = imageUrl?.trim() ?? "";

    final avatar = Container(
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
          return _AvatarInitial(letter: safeLetter, size: size);
        },
      )
          : _AvatarInitial(letter: safeLetter, size: size),
    );

    if (!ring) return avatar;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        gradient: _heroGradient,
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: avatar,
      ),
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
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE0E7FF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech_rounded,
            color: _primary,
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
                color: _primaryDeep,
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

// ─────────────────────────────────────────────────────────────────────────────
// MENUS
// ─────────────────────────────────────────────────────────────────────────────

class _MenuIcon extends StatelessWidget {
  const _MenuIcon();

  @override
  Widget build(BuildContext context) {
    return const Icon(Icons.more_horiz_rounded, color: _faint, size: 22);
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800),
        ),
      ],
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
      tooltip: "Post options",
      icon: const _MenuIcon(),
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'edit',
          child: _MenuRow(
            icon: Icons.edit_outlined,
            label: 'Edit',
            color: _primary,
            textColor: _ink,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: _danger,
            textColor: _danger,
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
      tooltip: "Post options",
      icon: const _MenuIcon(),
      position: PopupMenuPosition.under,
      onSelected: (v) {
        if (v == 'hide') onHide();
        if (v == 'report') onReport();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'hide',
          child: _MenuRow(
            icon: Icons.visibility_off_outlined,
            label: 'Hide',
            color: _muted,
            textColor: _ink,
          ),
        ),
        PopupMenuItem(
          value: 'report',
          child: _MenuRow(
            icon: Icons.flag_outlined,
            label: 'Report',
            color: _danger,
            textColor: _danger,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEETS + DIALOG PIECES
// ─────────────────────────────────────────────────────────────────────────────

class _SheetContainer extends StatelessWidget {
  final Widget child;

  const _SheetContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(top: false, child: child),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: _border,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;

  const _SheetHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 46,
          width: 46,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: iconColor, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;

  const _IconTile({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: _primary, size: 22),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Close",
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: _fieldFill,
        foregroundColor: _muted,
        side: const BorderSide(color: _border),
      ),
      icon: const Icon(Icons.close_rounded, size: 20),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: _primary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _FormDialog extends StatelessWidget {
  final List<Widget> children;

  const _FormDialog({required this.children});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  const _DialogHeader({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        _CloseButton(onTap: onClose),
      ],
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String confirmLabel;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.icon,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 60,
                width: 60,
                decoration: const BoxDecoration(
                  color: _dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _danger, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _body,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryButton(label: "Cancel", onTap: onCancel),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onConfirm,
                      style: FilledButton.styleFrom(
                        backgroundColor: _danger,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _fieldFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Icon(icon, color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _faint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: _body,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ThreadTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;

  const _ThreadTextField({
    required this.controller,
    required this.hint,
    required this.maxLines,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.textInputAction,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder outline(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      enabled: enabled,
      autofocus: autofocus,
      onChanged: onChanged,
      textInputAction: textInputAction,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(
        color: _ink,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _faint, fontWeight: FontWeight.w500),
        errorText: errorText,
        errorStyle: const TextStyle(
          color: _danger,
          fontWeight: FontWeight.w700,
        ),
        errorMaxLines: 2,
        filled: true,
        fillColor: errorText != null ? _dangerSoft : _fieldFill,
        enabledBorder: outline(_border),
        disabledBorder: outline(_border),
        focusedBorder: outline(_primary, 1.5),
        errorBorder: outline(_danger),
        focusedErrorBorder: outline(_danger, 1.5),
        border: outline(_border),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}

class _SelectedMediaPreview extends StatelessWidget {
  final File file;
  final bool isVideo;
  final VoidCallback? onRemove;

  const _SelectedMediaPreview({
    required this.file,
    required this.isVideo,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fileName = file.path.split(Platform.pathSeparator).last;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          isVideo
              ? Container(
            height: 160,
            width: double.infinity,
            decoration: const BoxDecoration(gradient: _heroGradient),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 8),
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
              : Image.file(
            file,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 140,
              color: _fieldFill,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: _faint,
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo ? Icons.videocam_rounded : Icons.image_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVideo ? "Video" : "Photo",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              right: 8,
              top: 8,
              child: Tooltip(
                message: "Remove",
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.all(7),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MediaChip({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _primarySoft,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: onTap == null ? _faint : _primary, size: 19),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: onTap == null ? _faint : _primaryDeep,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final IconData? icon;
  final bool loading;
  final bool expand;

  const _PostButton({
    required this.onTap,
    this.label = 'Post',
    this.icon,
    this.loading = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null || loading;

    return Opacity(
      opacity: active ? 1 : 0.6,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: _heroGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x406366F1),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else if (icon != null)
                    Icon(icon, color: Colors.white, size: 18),
                  if (loading || icon != null) const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _body,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _CreateFAB extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: _primary,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      onPressed: onTap,
      icon: const Icon(Icons.edit_outlined),
      label: const Text(
        "New post",
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING / EMPTY / ERROR
// ─────────────────────────────────────────────────────────────────────────────

class _Pulse extends StatefulWidget {
  final Widget child;

  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(opacity: _opacity, child: widget.child);
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: const _Pulse(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SkeletonBlock(height: 44, width: 44, radius: 999),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBlock(height: 14, width: 140, radius: 8),
                      SizedBox(height: 8),
                      _SkeletonBlock(height: 18, width: 100, radius: 99),
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
            _SkeletonBlock(height: 140, width: double.infinity, radius: 18),
            SizedBox(height: 14),
            Row(
              children: [
                _SkeletonBlock(height: 30, width: 70, radius: 99),
                SizedBox(width: 8),
                _SkeletonBlock(height: 30, width: 80, radius: 99),
              ],
            ),
          ],
        ),
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
        color: const Color(0xFFE9EDF5),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onCreate;

  const _EmptyState({
    required this.title,
    required this.message,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: _softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: const BoxDecoration(
                  color: _primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.dynamic_feed_outlined,
                  color: _primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _PostButton(
                label: "Create a post",
                icon: Icons.edit_outlined,
                onTap: onCreate,
              ),
              const SizedBox(height: 10),
              const Text(
                "Pull down to refresh",
                style: TextStyle(
                  color: _faint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: _softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 72,
                width: 72,
                decoration: const BoxDecoration(
                  color: _dangerSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: _danger,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Couldn't load posts",
                style: TextStyle(
                  color: _ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Check your connection and try again.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 20),
              _PostButton(
                label: "Try again",
                icon: Icons.refresh_rounded,
                onTap: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RefreshErrorBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _RefreshErrorBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: _danger, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "Couldn't refresh. Showing the last loaded posts.",
              style: TextStyle(
                color: Color(0xFF991B1B),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(foregroundColor: _danger),
            child: const Text(
              "Retry",
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SocialChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primary, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: _primaryDeep,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}