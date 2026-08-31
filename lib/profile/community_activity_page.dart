import 'package:flutter/material.dart';

import '../services/api_service.dart';

const _bg = Color(0xFFEFF3F9);
const _surface = Color(0xFFFFFFFF);
const _surfaceHigh = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _primaryBlue = Color(0xFF2563EB);
const _primarySoft = Color(0xFFEAF2FF);
const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF64748B);
const _danger = Color(0xFFFF3B5C);

class CommunityActivityPage extends StatefulWidget {
  const CommunityActivityPage({super.key});

  @override
  State<CommunityActivityPage> createState() => _CommunityActivityPageState();
}

class _CommunityActivityPageState extends State<CommunityActivityPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Map<String, dynamic>> _hiddenPosts = [];
  List<Map<String, dynamic>> _reportedPosts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    final results = await Future.wait([
      ApiService().getHiddenCommunityPosts(),
      ApiService().getReportedCommunityPosts(),
    ]);

    if (!mounted) return;

    setState(() {
      _hiddenPosts = results[0];
      _reportedPosts = results[1];
      _isLoading = false;
    });
  }

  Future<void> _restorePost(Map<String, dynamic> post) async {
    final postId = (post["id"] ?? "").toString();
    if (postId.isEmpty) return;

    final result = await ApiService().unhideCommunityPost(postId);

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(result.message)));

    if (result.success) {
      setState(() => _hiddenPosts.remove(post));
    }
  }

  String _reportedReason(Map<String, dynamic> post) {
    final reason = (post["report_reason"] ?? "").toString().trim();
    return reason.isEmpty ? "Sent to moderators for review" : reason;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: _primaryBlue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: _textSecondary,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: "Hidden"),
                    Tab(text: "Reported"),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _PostList(
                          posts: _hiddenPosts,
                          emptyIcon: Icons.visibility_off_outlined,
                          emptyTitle: "No hidden posts",
                          emptySubtitle:
                              "Posts you hide from Community will appear here.",
                          actionLabel: "Restore",
                          actionIcon: Icons.undo_rounded,
                          onAction: _restorePost,
                          subtitleBuilder: (_) => "Hidden from your feed",
                          statusColor: _primaryBlue,
                        ),
                        _PostList(
                          posts: _reportedPosts,
                          emptyIcon: Icons.flag_outlined,
                          emptyTitle: "No reported posts",
                          emptySubtitle:
                              "Posts you report for review will appear here.",
                          subtitleBuilder: _reportedReason,
                          statusColor: _danger,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

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
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Community Activity",
                    style: TextStyle(
                      color: _textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    "Hidden and reported posts",
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
                color: _primarySoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.shield_outlined, color: _primaryBlue),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final Color statusColor;
  final String Function(Map<String, dynamic> post) subtitleBuilder;
  final Future<void> Function(Map<String, dynamic> post)? onAction;

  const _PostList({
    required this.posts,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.statusColor,
    required this.subtitleBuilder,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        final state = context
            .findAncestorStateOfType<_CommunityActivityPageState>();
        await state?._loadPosts();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final post = posts[index];

          return _PostCard(
            post: post,
            status: subtitleBuilder(post),
            statusColor: statusColor,
            actionLabel: actionLabel,
            actionIcon: actionIcon,
            onAction: onAction == null ? null : () => onAction!(post),
          );
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String status;
  final Color statusColor;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const _PostCard({
    required this.post,
    required this.status,
    required this.statusColor,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  String get _authorName {
    final user = Map<String, dynamic>.from(post["user"] ?? {});
    return (user["name"] ?? "Runner").toString();
  }

  String? get _avatarUrl {
    final user = Map<String, dynamic>.from(post["user"] ?? {});
    final url = (user["avatar_url"] ?? "").toString();
    return url.isEmpty ? null : url;
  }

  String? get _mediaUrl {
    final image = (post["image_url"] ?? "").toString();
    if (image.isNotEmpty) return image;

    final video = (post["video_url"] ?? "").toString();
    return video.isEmpty ? null : video;
  }

  @override
  Widget build(BuildContext context) {
    final title = (post["title"] ?? "Community post").toString();
    final content = (post["content"] ?? "").toString();
    final mediaUrl = _mediaUrl;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(name: _authorName, imageUrl: _avatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _authorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (onAction != null && actionLabel != null)
                TextButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 17),
                  label: Text(actionLabel!),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: const TextStyle(
                color: _textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
          ],
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
          if (mediaUrl != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 130,
                width: double.infinity,
                color: _surfaceHigh,
                child: Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image_outlined,
                    color: _textSecondary,
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

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _Avatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? "R" : name.trim()[0].toUpperCase();
    final url = imageUrl?.trim() ?? "";

    return Container(
      height: 42,
      width: 42,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: _primaryBlue,
        shape: BoxShape.circle,
      ),
      child: url.isNotEmpty
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _AvatarInitial(initial: initial),
            )
          : _AvatarInitial(initial: initial),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _primaryBlue, size: 48),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
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
