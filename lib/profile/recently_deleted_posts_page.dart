import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _background = Color(0xFFEFF3F9);
const _surface = Color(0xFFFFFFFF);
const _border = Color(0xFFE2E8F0);
const _primary = Color(0xFF2563EB);
const _primarySoft = Color(0xFFEAF2FF);
const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF64748B);
const _danger = Color(0xFFDC2626);

class RecentlyDeletedPostsPage extends StatefulWidget {
  const RecentlyDeletedPostsPage({super.key});

  @override
  State<RecentlyDeletedPostsPage> createState() =>
      _RecentlyDeletedPostsPageState();
}

class _RecentlyDeletedPostsPageState extends State<RecentlyDeletedPostsPage> {
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  String? _errorMessage;
  final Set<String> _restoringIds = {};

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final result = await ApiService().getArchivedCommunityPosts();
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.success) {
        _posts = result.data ?? [];
      } else {
        _errorMessage = result.message;
      }
    });
  }

  Future<void> _restorePost(Map<String, dynamic> post) async {
    final postId = (post["id"] ?? "").toString();
    if (postId.isEmpty || _restoringIds.contains(postId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Restore post?"),
        content: const Text(
          "This post will return to your community posts and become visible again.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Restore"),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _restoringIds.add(postId));
    final result = await ApiService().restoreArchivedCommunityPost(postId);
    if (!mounted) return;

    setState(() {
      _restoringIds.remove(postId);
      if (result.success) _posts.remove(post);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _PageHeader(onBack: () => Navigator.pop(context)),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return _MessageState(
        icon: Icons.cloud_off_outlined,
        title: "Unable to load posts",
        message: _errorMessage!,
        actionLabel: "Try again",
        onAction: _loadPosts,
      );
    }

    if (_posts.isEmpty) {
      return const _MessageState(
        icon: Icons.delete_sweep_outlined,
        title: "No recently deleted posts",
        message: "Posts you delete will remain here for up to 30 days.",
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPosts,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _posts.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = _posts[index];
          final id = (post["id"] ?? "").toString();
          return _ArchivedPostCard(
            post: post,
            isRestoring: _restoringIds.contains(id),
            onRestore: () => _restorePost(post),
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _PageHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 14),
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
              foregroundColor: _primary,
            ),
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Recently Deleted",
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "Restore posts within 30 days",
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.history_rounded, color: _danger),
          ),
        ],
      ),
    );
  }
}

class _ArchivedPostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final bool isRestoring;
  final VoidCallback onRestore;

  const _ArchivedPostCard({
    required this.post,
    required this.isRestoring,
    required this.onRestore,
  });

  bool get _canRestore {
    if (post["can_restore"] is bool) return post["can_restore"] as bool;
    if (post["restorable"] is bool) return post["restorable"] as bool;
    return post["deleted_by_moderator"] != true &&
        post["moderator_deleted"] != true;
  }

  String? get _mediaUrl {
    final image = (post["image_url"] ?? "").toString().trim();
    if (image.isNotEmpty) return image;
    final video = (post["video_url"] ?? "").toString().trim();
    return video.isEmpty ? null : video;
  }

  String get _statusText {
    if (!_canRestore) return "Removed by a moderator • Cannot be restored";

    final explicitDays = int.tryParse(
      (post["days_remaining"] ?? post["remaining_days"] ?? "").toString(),
    );
    if (explicitDays != null) return _daysText(explicitDays);

    DateTime? expiresAt;
    for (final key in ["expires_at", "purge_at", "permanently_deleted_at"]) {
      expiresAt = DateTime.tryParse((post[key] ?? "").toString())?.toLocal();
      if (expiresAt != null) break;
    }
    final deletedAt = DateTime.tryParse(
      (post["deleted_at"] ?? "").toString(),
    )?.toLocal();
    expiresAt ??= deletedAt?.add(const Duration(days: 30));
    if (expiresAt == null) return "Scheduled for permanent deletion";

    final remaining = expiresAt.difference(DateTime.now());
    final days = remaining.isNegative ? 0 : (remaining.inHours / 24).ceil();
    return _daysText(days);
  }

  String _daysText(int days) {
    final safeDays = days.clamp(0, 30);
    if (safeDays == 0) return "Deletes permanently today";
    if (safeDays == 1) return "1 day remaining";
    return "$safeDays days remaining";
  }

  @override
  Widget build(BuildContext context) {
    final title = (post["title"] ?? "Community post").toString();
    final content = (post["content"] ?? "").toString();
    final mediaUrl = _mediaUrl;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: _canRestore ? _danger : _textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (_canRestore)
                FilledButton.icon(
                  onPressed: isRestoring ? null : onRestore,
                  icon: isRestoring
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.restore_rounded, size: 18),
                  label: Text(isRestoring ? "Restoring" : "Restore"),
                ),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ],
          if (mediaUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const ColoredBox(
                    color: Color(0xFFF8FAFC),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

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
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _primary, size: 50),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
