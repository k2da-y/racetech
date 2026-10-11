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
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _danger = Color(0xFFE11D48);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

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

  /// Posts currently being restored — blocks double taps and shows a spinner.
  final Set<String> _restoringIds = {};

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

  // ============================================================
  // DATA — same API calls
  // ============================================================

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
    if (postId.isEmpty || _restoringIds.contains(postId)) return;

    setState(() => _restoringIds.add(postId));

    final result = await ApiService().unhideCommunityPost(postId);

    if (!mounted) return;

    setState(() {
      _restoringIds.remove(postId);
      if (result.success) _hiddenPosts.remove(post);
    });

    if (result.success) HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(result.message),
      ),
    );
  }

  String _reportedReason(Map<String, dynamic> post) {
    final reason = (post["report_reason"] ?? "").toString().trim();
    return reason.isEmpty ? "Sent to moderators for review" : reason;
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
        body: Column(
          children: [
            _Hero(
              isLoading: _isLoading,
              hiddenCount: _hiddenPosts.length,
              reportedCount: _reportedPosts.length,
              onBack: () => Navigator.pop(context),
            ),

            // Tab bar overlaps the bottom edge of the hero.
            Transform.translate(
              offset: const Offset(0, -24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Container(
                      height: 54,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: _softShadow,
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: _primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        dividerColor: Colors.transparent,
                        splashBorderRadius: BorderRadius.circular(14),
                        labelColor: Colors.white,
                        unselectedLabelColor: _body,
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13.5,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                        tabs: [
                          Tab(
                            child: _TabLabel(
                              icon: Icons.visibility_off_outlined,
                              label: "Hidden",
                              count: _isLoading ? null : _hiddenPosts.length,
                            ),
                          ),
                          Tab(
                            child: _TabLabel(
                              icon: Icons.flag_outlined,
                              label: "Reported",
                              count: _isLoading ? null : _reportedPosts.length,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Expanded(
              child: Transform.translate(
                offset: const Offset(0, -10),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 632),
                    child: _isLoading
                        ? const _LoadingList()
                        : TabBarView(
                      controller: _tabController,
                      children: [
                        _PostList(
                          posts: _hiddenPosts,
                          onRefresh: _loadPosts,
                          emptyIcon: Icons.visibility_off_outlined,
                          emptyTitle: "No hidden posts",
                          emptySubtitle:
                          "Posts you hide from Community will appear here.",
                          actionLabel: "Restore",
                          actionIcon: Icons.undo_rounded,
                          onAction: _restorePost,
                          busyIds: _restoringIds,
                          statusIcon: Icons.visibility_off_outlined,
                          subtitleBuilder: (_) => "Hidden from your feed",
                          statusColor: _primary,
                        ),
                        _PostList(
                          posts: _reportedPosts,
                          onRefresh: _loadPosts,
                          emptyIcon: Icons.flag_outlined,
                          emptyTitle: "No reported posts",
                          emptySubtitle:
                          "Posts you report for review will appear here.",
                          statusIcon: Icons.flag_rounded,
                          subtitleBuilder: _reportedReason,
                          statusColor: _danger,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HERO
// ============================================================

class _Hero extends StatelessWidget {
  final bool isLoading;
  final int hiddenCount;
  final int reportedCount;
  final VoidCallback onBack;

  const _Hero({
    required this.isLoading,
    required this.hiddenCount,
    required this.reportedCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 48),
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
                      "Community Activity",
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
              const SizedBox(height: 18),
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Hidden & Reported Posts",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Restore posts you hid, or check on the ones you reported.",
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

class _TabLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? count;

  const _TabLabel({required this.icon, required this.label, this.count});

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color ?? _body;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              "$count",
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// LIST
// ============================================================

class _PostList extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final Future<void> Function() onRefresh;
  final IconData emptyIcon;
  final String emptyTitle;
  final String emptySubtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final IconData statusIcon;
  final Color statusColor;
  final Set<String> busyIds;
  final String Function(Map<String, dynamic> post) subtitleBuilder;
  final Future<void> Function(Map<String, dynamic> post)? onAction;

  const _PostList({
    required this.posts,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.statusIcon,
    required this.statusColor,
    required this.subtitleBuilder,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.busyIds = const {},
  });

  @override
  Widget build(BuildContext context) {
    // Pull-to-refresh now also works on the empty state.
    return RefreshIndicator(
      color: _primary,
      onRefresh: onRefresh,
      child: posts.isEmpty
          ? ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _EmptyState(
            icon: emptyIcon,
            title: emptyTitle,
            subtitle: emptySubtitle,
          ),
        ],
      )
          : ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: posts.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final post = posts[index];
          final postId = (post["id"] ?? "").toString();

          return _PostCard(
            post: post,
            status: subtitleBuilder(post),
            statusIcon: statusIcon,
            statusColor: statusColor,
            actionLabel: actionLabel,
            actionIcon: actionIcon,
            isBusy: busyIds.contains(postId),
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
  final IconData statusIcon;
  final Color statusColor;
  final String? actionLabel;
  final IconData? actionIcon;
  final bool isBusy;
  final VoidCallback? onAction;

  const _PostCard({
    required this.post,
    required this.status,
    required this.statusIcon,
    required this.statusColor,
    this.actionLabel,
    this.actionIcon,
    this.isBusy = false,
    this.onAction,
  });

  Map<String, dynamic> get _user =>
      post["user"] is Map ? Map<String, dynamic>.from(post["user"]) : {};

  String get _authorName => (_user["name"] ?? "Runner").toString();

  String? get _avatarUrl {
    final url = (_user["avatar_url"] ?? "").toString();
    return url.isEmpty ? null : url;
  }

  @override
  Widget build(BuildContext context) {
    final title = (post["title"] ?? "Community post").toString();
    final content = (post["content"] ?? "").toString();
    final imageUrl = (post["image_url"] ?? "").toString();
    final videoUrl = (post["video_url"] ?? "").toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status strip at the top of each card.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            color: statusColor.withValues(alpha: 0.07),
            child: Row(
              children: [
                Icon(statusIcon, size: 15, color: statusColor),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Avatar(name: _authorName, imageUrl: _avatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                if (content.isNotEmpty)
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
                if (imageUrl.isNotEmpty || videoUrl.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 140,
                      width: double.infinity,
                      // A video URL can't be shown with Image.network (it
                      // always failed before) — show a video placeholder.
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) =>
                        progress == null
                            ? child
                            : const ColoredBox(color: _fieldFill),
                        errorBuilder: (context, error, stackTrace) =>
                        const _MediaPlaceholder(
                          icon: Icons.broken_image_outlined,
                        ),
                      )
                          : const _MediaPlaceholder(
                        icon: Icons.play_circle_fill_rounded,
                        label: "Video post",
                      ),
                    ),
                  ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isBusy ? null : onAction,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _primary,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: isBusy
                          ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _primary,
                        ),
                      )
                          : Icon(actionIcon, size: 18),
                      label: Text(
                        isBusy ? "Restoring..." : actionLabel!,
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

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;

  const _Avatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? "R" : name.trim()[0].toUpperCase();
    final url = imageUrl?.trim() ?? "";

    return Container(
      height: 40,
      width: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(14),
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
          color: _primary,
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      ),
    );
  }
}

// ============================================================
// EMPTY + LOADING
// ============================================================

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
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
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
    final content = ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                block(width: 160, height: 12),
                const SizedBox(height: 14),
                Row(
                  children: [
                    block(width: 40, height: 40, radius: 14),
                    const SizedBox(width: 10),
                    block(width: 120, height: 14),
                  ],
                ),
                const SizedBox(height: 14),
                block(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                block(width: 220, height: 12),
              ],
            ),
          ),
      ],
    );

    if (MediaQuery.disableAnimationsOf(context)) return content;

    return FadeTransition(opacity: opacity, child: content);
  }
}