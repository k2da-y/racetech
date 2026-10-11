import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile pages)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _body = Color(0xFF475569);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _danger = Color(0xFFE11D48);
const _warning = Color(0xFFD97706);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

const int _retentionDays = 30;

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

  // ============================================================
  // DATA — same API calls
  // ============================================================

  /// [showLoading] is false for pull-to-refresh, so the list stays on screen
  /// instead of being swapped for a spinner mid-gesture.
  Future<void> _loadPosts({bool showLoading = true}) async {
    if (mounted && showLoading) {
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
        _errorMessage = null;
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: Container(
          height: 60,
          width: 60,
          decoration: BoxDecoration(
            color: _primarySoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.restore_rounded, color: _primary, size: 30),
        ),
        title: const Text(
          "Restore post?",
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "This post will return to your community posts and become visible again.",
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, height: 1.4),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: _muted),
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
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

    if (result.success) HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(result.message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: RefreshIndicator(
          color: _primary,
          onRefresh: () => _loadPosts(showLoading: false),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Hero(
                  isLoading: _isLoading,
                  count: _posts.length,
                  onBack: () => Navigator.pop(context),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: _buildBody(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const _LoadingList();

    if (_errorMessage != null && _posts.isEmpty) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorMessage != null) ...[
          _Banner(
            icon: Icons.warning_amber_rounded,
            color: _warning,
            background: const Color(0xFFFFFBEB),
            border: const Color(0xFFFDE68A),
            text: _errorMessage!,
            actionLabel: "Retry",
            onAction: _loadPosts,
          ),
          const SizedBox(height: 14),
        ],
        for (final post in _posts) ...[
          _ArchivedPostCard(
            post: post,
            isRestoring: _restoringIds.contains((post["id"] ?? "").toString()),
            onRestore: () => _restorePost(post),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _Hero extends StatelessWidget {
  final bool isLoading;
  final int count;
  final VoidCallback onBack;

  const _Hero({
    required this.isLoading,
    required this.count,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryDeep, _primary, _accent],
          stops: [0, 0.55, 1],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              Row(
                children: [
                  Material(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onBack,
                      borderRadius: BorderRadius.circular(14),
                      child: const Tooltip(
                        message: "Back",
                        child: SizedBox(
                          height: 44,
                          width: 44,
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      "Recently Deleted",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                height: 70,
                width: 70,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isLoading
                    ? "Loading..."
                    : count == 1
                    ? "1 deleted post"
                    : "$count deleted posts",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Restore them within $_retentionDays days before they're gone for good.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12.5,
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

// ============================================================
// POST CARD
// ============================================================

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

  /// Days left before permanent deletion, or null if unknown.
  /// Same rules as before: explicit days → expiry date → deleted_at + 30.
  int? get _daysLeft {
    final explicitDays = int.tryParse(
      (post["days_remaining"] ?? post["remaining_days"] ?? "").toString(),
    );
    if (explicitDays != null) return explicitDays.clamp(0, _retentionDays);

    DateTime? expiresAt;
    for (final key in ["expires_at", "purge_at", "permanently_deleted_at"]) {
      expiresAt = DateTime.tryParse((post[key] ?? "").toString())?.toLocal();
      if (expiresAt != null) break;
    }
    final deletedAt = DateTime.tryParse(
      (post["deleted_at"] ?? "").toString(),
    )?.toLocal();
    expiresAt ??= deletedAt?.add(const Duration(days: _retentionDays));
    if (expiresAt == null) return null;

    final remaining = expiresAt.difference(DateTime.now());
    final days = remaining.isNegative ? 0 : (remaining.inHours / 24).ceil();
    return days.clamp(0, _retentionDays);
  }

  String _statusText(int? days) {
    if (!_canRestore) return "Removed by a moderator • Cannot be restored";
    if (days == null) return "Scheduled for permanent deletion";
    if (days == 0) return "Deletes permanently today";
    if (days == 1) return "1 day remaining";
    return "$days days remaining";
  }

  String get _deletedLabel {
    final parsed = DateTime.tryParse(
      (post["deleted_at"] ?? "").toString(),
    )?.toLocal();
    if (parsed == null) return "";

    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ];
    return "Deleted ${months[parsed.month - 1]} ${parsed.day}";
  }

  @override
  Widget build(BuildContext context) {
    final title = (post["title"] ?? "Community post").toString();
    final content = (post["content"] ?? "").toString();
    final imageUrl = (post["image_url"] ?? "").toString().trim();
    final videoUrl = (post["video_url"] ?? "").toString().trim();
    final canRestore = _canRestore;
    final days = _daysLeft;
    // Red when almost gone, amber otherwise, grey if it can't be restored.
    final urgency = !canRestore
        ? _muted
        : days != null && days <= 3
        ? _danger
        : _warning;
    final deletedLabel = _deletedLabel;

    return Container(
      decoration: BoxDecoration(
        color: canRestore ? Colors.white : _fieldFill,
        borderRadius: BorderRadius.circular(24),
        border: canRestore ? null : Border.all(color: _border),
        boxShadow: canRestore ? _softShadow : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Countdown strip.
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            color: urgency.withValues(alpha: 0.08),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      canRestore
                          ? Icons.hourglass_bottom_rounded
                          : Icons.gpp_bad_outlined,
                      size: 15,
                      color: urgency,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        _statusText(days),
                        style: TextStyle(
                          color: urgency,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (deletedLabel.isNotEmpty)
                      Text(
                        deletedLabel,
                        style: const TextStyle(
                          color: _faint,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                if (canRestore && days != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: days / _retentionDays,
                      minHeight: 4,
                      backgroundColor: urgency.withValues(alpha: 0.15),
                      color: urgency,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: canRestore ? _ink : _muted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                if (content.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _body,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                ],
                if (imageUrl.isNotEmpty || videoUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      // Video URLs can't be shown with Image.network (that
                      // always showed a broken image before).
                      child: imageUrl.isNotEmpty
                          ? Opacity(
                        opacity: canRestore ? 1 : 0.6,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const ColoredBox(color: _fieldFill),
                          errorBuilder: (_, _, _) =>
                          const _MediaPlaceholder(
                            icon: Icons.broken_image_outlined,
                          ),
                        ),
                      )
                          : const _MediaPlaceholder(
                        icon: Icons.play_circle_fill_rounded,
                        label: "Video post",
                      ),
                    ),
                  ),
                ],
                if (canRestore) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: isRestoring ? null : onRestore,
                      style: FilledButton.styleFrom(
                        backgroundColor: _primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _primary.withValues(
                          alpha: 0.5,
                        ),
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isRestoring
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.restore_rounded, size: 19),
                      label: Text(
                        isRestoring ? "Restoring..." : "Restore Post",
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String? label;

  const _MediaPlaceholder({required this.icon, this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _primarySoft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _primary, size: 40),
          if (label != null) ...[
            const SizedBox(height: 6),
            Text(
              label!,
              style: const TextStyle(
                color: _primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// STATES
// ============================================================

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final Color border;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _Banner({
    required this.icon,
    required this.color,
    required this.background,
    required this.border,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF92400E),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: _primaryDeep,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: Text(actionLabel!),
            ),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _primarySoft,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Icon(icon, color: _primary, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoadingList extends StatefulWidget {
  const _LoadingList();

  @override
  State<_LoadingList> createState() => _LoadingListState();
}

class _LoadingListState extends State<_LoadingList>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> opacity = Tween<double>(
    begin: 0.55,
    end: 1,
  ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget block({double? width, required double height, double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(width: 150, height: 12),
                const SizedBox(height: 10),
                block(width: double.infinity, height: 4, radius: 99),
                const SizedBox(height: 16),
                block(width: double.infinity, height: 16),
                const SizedBox(height: 8),
                block(width: 220, height: 12),
                const SizedBox(height: 16),
                block(width: double.infinity, height: 48, radius: 14),
              ],
            ),
          ),
      ],
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}