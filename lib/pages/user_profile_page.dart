import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:racetechph/profile/certificates_page.dart';

import '../data/rank_data.dart';
import '../utils/certificate_count.dart';
import '../utils/official_certificate.dart';
import '../services/api_service.dart';
import 'login_page.dart';
import '../profile/help_support_page.dart';
import '../profile/privacy_policy_page.dart';
import '../profile/community_activity_page.dart';
import '../profile/community_page.dart';
import '../profile/recently_deleted_posts_page.dart';
import '../profile/edit_password.dart';
import '../profile/my_activity_page.dart';
import 'edit_interests_page.dart';
import 'profile_settings_page.dart';
import '../widgets/bottom_nav_bar.dart';

// ============================================================
// RACETECH DESIGN SYSTEM — soft indigo (same as Profile Settings)
// ============================================================

const _primary = Color(0xFF6366F1); // indigo-500
const _primaryDeep = Color(0xFF4F46E5); // indigo-600
const _accent = Color(0xFF0EA5E9); // sky-500
const _primarySoft = Color(0xFFEEF2FF); // indigo-50
const _ink = Color(0xFF1E293B);
const _muted = Color(0xFF64748B);
const _faint = Color(0xFF94A3B8);
const _border = Color(0xFFE2E8F0);
const _background = Color(0xFFF5F7FB);
const _fieldFill = Color(0xFFF8FAFC);
const _danger = Color(0xFFE11D48);
const _dangerSoft = Color(0xFFFFE4E6);

const List<BoxShadow> _softShadow = [
  BoxShadow(color: Color(0x1F94A3B8), blurRadius: 24, offset: Offset(0, 8)),
];

// ============================================================
// USER PROFILE PAGE
// ============================================================

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  Map<String, dynamic>? user;

  bool isLoadingUser = true;
  bool isLoadingCommunity = true;
  bool isLoggingOut = false;

  int myCommunityPostCount = 0;
  int myCommunityLikeCount = 0;
  int myCommunityCommentCount = 0;

  int profileBadgeCount = 0;

  String latestCommunityPostTitle = "";

  @override
  void initState() {
    super.initState();
    loadUser();
  }

  // ============================================================
  // USER — logic unchanged
  // ============================================================

  Future<void> loadUser() async {
    final apiService = ApiService();

    final currentUser = await apiService.getUser();

    final userBadgeCount = certificateCountFromUser(currentUser);

    final certificateResult = userBadgeCount == null
        ? await apiService.getCertificates()
        : const ApiDataResult<List<Map<String, dynamic>>>.success([]);

    final resolvedBadgeCount =
        userBadgeCount ??
        validOfficialCertificateCount(certificateResult.data ?? const []);

    if (!mounted) return;

    setState(() {
      user = currentUser;
      profileBadgeCount = resolvedBadgeCount;
      isLoadingUser = false;
    });

    await loadCommunitySummary(currentUser);
  }

  // ============================================================
  // COMMUNITY SUMMARY — logic unchanged
  // ============================================================

  Future<void> loadCommunitySummary(Map<String, dynamic>? currentUser) async {
    final userId = (currentUser?["id"] ?? "").toString();

    if (userId.isEmpty) {
      if (!mounted) return;

      setState(() => isLoadingCommunity = false);

      return;
    }

    final posts = await ApiService().getCommunityPosts();

    if (!mounted) return;

    final myPosts = posts.where((post) {
      final postUser = Map<String, dynamic>.from(post["user"] ?? {});

      return (postUser["id"] ?? "").toString() == userId;
    }).toList();

    final likeCount = myPosts.fold<int>(
      0,
      (total, post) =>
          total + (int.tryParse((post["likes_count"] ?? 0).toString()) ?? 0),
    );

    final commentCount = myPosts.fold<int>(
      0,
      (total, post) => total + (((post["comments"] as List?) ?? []).length),
    );

    final latestTitle = myPosts.isEmpty
        ? ""
        : (myPosts.first["title"] ?? "Community post").toString();

    setState(() {
      myCommunityPostCount = myPosts.length;
      myCommunityLikeCount = likeCount;
      myCommunityCommentCount = commentCount;
      latestCommunityPostTitle = latestTitle;
      isLoadingCommunity = false;
    });
  }

  // ============================================================
  // REFRESH — logic unchanged
  // ============================================================

  Future<void> refreshProfile() async {
    setState(() {
      isLoadingUser = true;
      isLoadingCommunity = true;
    });

    await loadUser();
  }

  // ============================================================
  // LOGOUT — same API call, plus a loading state
  // ============================================================

  Future<void> handleLogout(BuildContext context) async {
    setState(() => isLoggingOut = true);

    final success = await ApiService().logout();

    if (!context.mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    } else {
      setState(() => isLoggingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text("Logout failed. Please try again."),
        ),
      );
    }
  }

  Future<void> confirmLogout(BuildContext context) async {
    if (isLoggingOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const _IconTile(
          icon: Icons.logout_rounded,
          size: 60,
          iconSize: 28,
          color: _danger,
          background: _dangerSoft,
        ),
        title: const Text(
          "Log out?",
          style: TextStyle(color: _ink, fontWeight: FontWeight.w900),
        ),
        content: const Text(
          "You will need to sign in again to access your account.",
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
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text("Log Out"),
          ),
        ],
      ),
    );

    if (shouldLogout == true && context.mounted) {
      await handleLogout(context);
    }
  }

  // ============================================================
  // NAVIGATION HELPERS — same destinations and reloads as before
  // ============================================================

  Future<void> openAndReloadUser(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await loadUser();
  }

  Future<void> openAndReloadCommunity(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await loadCommunitySummary(user);
  }

  void open(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final displayName = (user?["name"] ?? "Runner").toString();
    final displayEmail = (user?["email"] ?? "").toString();
    final avatarUrl = (user?["avatar_url"] ?? "").toString();
    final rankTitle = rankTitleForBadges(profileBadgeCount);
    final initial = displayName.trim().isEmpty
        ? "R"
        : displayName.trim()[0].toUpperCase();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        bottomNavigationBar: const AppBottomNavBar(
          currentPage: AppNavPage.profile,
        ),
        body: RefreshIndicator(
          color: _primary,
          onRefresh: refreshProfile,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _ProfileHero(
                  isLoading: isLoadingUser,
                  isLoadingStats: isLoadingCommunity,
                  displayName: displayName,
                  displayEmail: displayEmail,
                  avatarUrl: avatarUrl,
                  initial: initial,
                  rankTitle: rankTitle,
                  certificates: profileBadgeCount,
                  posts: myCommunityPostCount,
                  likes: myCommunityLikeCount,
                  comments: myCommunityCommentCount,
                  onAvatarTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => _ProfilePhotoPreviewDialog(
                      avatarUrl: avatarUrl,
                      initial: initial,
                      displayName: displayName,
                    ),
                  ),
                  onEditProfile: () =>
                      openAndReloadUser(const ProfileSettingsPage()),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ---------------- ACCOUNT ----------------
                          _SectionCard(
                            title: "Account",
                            icon: Icons.person_outline_rounded,
                            children: [
                              _MenuTile(
                                title: "Profile Settings",
                                subtitle:
                                    "Personal, contact & emergency details",
                                icon: Icons.manage_accounts_outlined,
                                onTap: () => openAndReloadUser(
                                  const ProfileSettingsPage(),
                                ),
                              ),
                              _MenuTile(
                                title: "Edit Interests",
                                subtitle: "Activities used for recommendations",
                                icon: Icons.interests_outlined,
                                onTap: () => openAndReloadUser(
                                  const EditInterestsPage(),
                                ),
                              ),
                              _MenuTile(
                                title: "Edit Password",
                                subtitle: "Change your sign-in password",
                                icon: Icons.lock_outline_rounded,
                                onTap: () => open(const EditPasswordPage()),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------- RACING ----------------
                          _SectionCard(
                            title: "Racing",
                            icon: Icons.flag_outlined,
                            children: [
                              _MenuTile(
                                title: "My Activity",
                                subtitle: "Registrations, payments & groups",
                                icon: Icons.receipt_long_outlined,
                                onTap: () =>
                                    openAndReloadUser(const MyActivityPage()),
                              ),
                              _MenuTile(
                                title: "E-Certificates",
                                subtitle: isLoadingUser
                                    ? "Your finisher certificates"
                                    : "$profileBadgeCount earned · $rankTitle",
                                icon: Icons.emoji_events_outlined,
                                onTap: () =>
                                    openAndReloadUser(const CertificatesPage()),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------- COMMUNITY ----------------
                          _SectionCard(
                            title: "My Community",
                            icon: Icons.groups_rounded,
                            trailing: TextButton.icon(
                              onPressed: () => openAndReloadCommunity(
                                const CommunityPage(showOnlyMyPosts: true),
                              ),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                              iconAlignment: IconAlignment.end,
                              label: const Text("My posts"),
                              style: TextButton.styleFrom(
                                foregroundColor: _primary,
                                textStyle: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            children: [
                              if (isLoadingCommunity)
                                const _SkeletonBlock(height: 44, radius: 14)
                              else
                                _LatestPostBanner(
                                  title: latestCommunityPostTitle,
                                ),
                              const SizedBox(height: 6),
                              _MenuTile(
                                title: "Hidden and Reported Posts",
                                subtitle:
                                    "Review posts you hid or sent to moderators",
                                icon: Icons.shield_outlined,
                                onTap: () => openAndReloadCommunity(
                                  const CommunityActivityPage(),
                                ),
                              ),
                              _MenuTile(
                                title: "Recently Deleted",
                                subtitle:
                                    "Restore your posts before they expire",
                                icon: Icons.delete_outline_rounded,
                                onTap: () => openAndReloadCommunity(
                                  const RecentlyDeletedPostsPage(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------- MORE ----------------
                          _SectionCard(
                            title: "More",
                            icon: Icons.more_horiz_rounded,
                            children: [
                              _MenuTile(
                                title: "Privacy Policy",
                                icon: Icons.privacy_tip_outlined,
                                onTap: () => open(const PrivacyPolicyPage()),
                              ),
                              _MenuTile(
                                title: "Help & Support",
                                icon: Icons.support_agent_outlined,
                                onTap: () => open(const HelpSupportPage()),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // ---------------- LOG OUT ----------------
                          _LogoutButton(
                            isLoading: isLoggingOut,
                            onTap: () => confirmLogout(context),
                          ),

                          const SizedBox(height: 20),

                          const Text(
                            "Train smarter. Perform better.",
                            textAlign: TextAlign.center,
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
// HERO HEADER
// ============================================================

class _ProfileHero extends StatelessWidget {
  final bool isLoading;
  final bool isLoadingStats;
  final String displayName;
  final String displayEmail;
  final String avatarUrl;
  final String initial;
  final String rankTitle;
  final int certificates;
  final int posts;
  final int likes;
  final int comments;
  final VoidCallback onAvatarTap;
  final VoidCallback onEditProfile;

  const _ProfileHero({
    required this.isLoading,
    required this.isLoadingStats,
    required this.displayName,
    required this.displayEmail,
    required this.avatarUrl,
    required this.initial,
    required this.rankTitle,
    required this.certificates,
    required this.posts,
    required this.likes,
    required this.comments,
    required this.onAvatarTap,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topInset + 10, 16, 24),
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
              // ---- Top bar ----
              Row(
                children: [
                  const SizedBox(width: 44),
                  const Expanded(
                    child: Text(
                      "My Profile",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _GlassButton(
                    icon: Icons.edit_outlined,
                    tooltip: "Edit profile",
                    onTap: isLoading ? null : onEditProfile,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ---- Avatar ----
              _HeroAvatar(
                avatarUrl: avatarUrl,
                initial: initial,
                isLoading: isLoading,
                onTap: onAvatarTap,
              ),

              const SizedBox(height: 14),

              Text(
                isLoading ? "Loading..." : displayName,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                displayEmail.isEmpty ? "No email available" : displayEmail,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.82),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              _RankPill(title: rankTitle),

              const SizedBox(height: 20),

              // ---- Stats card ----
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      _HeroStat(
                        label: "Certificates",
                        value: certificates,
                        isLoading: isLoading,
                      ),
                      const _StatDivider(),
                      _HeroStat(
                        label: "Posts",
                        value: posts,
                        isLoading: isLoadingStats,
                      ),
                      const _StatDivider(),
                      _HeroStat(
                        label: "Likes",
                        value: likes,
                        isLoading: isLoadingStats,
                      ),
                      const _StatDivider(),
                      _HeroStat(
                        label: "Comments",
                        value: comments,
                        isLoading: isLoadingStats,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String label;
  final int value;
  final bool isLoading;

  const _HeroStat({
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: isLoading
                ? Container(
                    key: const ValueKey("loading"),
                    height: 22,
                    width: 26,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  )
                : Text(
                    key: ValueKey(value),
                    value.toString(),
                    maxLines: 1,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return VerticalDivider(
      width: 1,
      thickness: 1,
      indent: 4,
      endIndent: 4,
      color: Colors.white.withValues(alpha: 0.2),
    );
  }
}

class _RankPill extends StatelessWidget {
  final String title;

  const _RankPill({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.military_tech_rounded, color: _primary, size: 16),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
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
  final VoidCallback? onTap;

  const _GlassButton({required this.icon, required this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  final String avatarUrl;
  final String initial;
  final bool isLoading;
  final VoidCallback onTap;

  const _HeroAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.isLoading,
    required this.onTap,
  });

  Widget initialFallback() {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: _primary,
          fontSize: 40,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget image() {
    if (isLoading) {
      return const Center(
        child: SizedBox(
          height: 26,
          width: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: _primary),
        ),
      );
    }

    if (avatarUrl.isNotEmpty) {
      return Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : initialFallback(),
        errorBuilder: (context, error, stackTrace) => initialFallback(),
      );
    }

    return initialFallback();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: "View profile photo",
      child: GestureDetector(
        onTap: isLoading ? null : onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 108,
              width: 108,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipOval(
                child: ColoredBox(
                  color: _primarySoft,
                  child: SizedBox.expand(child: image()),
                ),
              ),
            ),
            if (!isLoading)
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.zoom_in_rounded,
                    color: _primary,
                    size: 18,
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
// PHOTO PREVIEW
// ============================================================

class _ProfilePhotoPreviewDialog extends StatelessWidget {
  final String avatarUrl;
  final String initial;
  final String displayName;

  const _ProfilePhotoPreviewDialog({
    required this.avatarUrl,
    required this.initial,
    required this.displayName,
  });

  Widget largeInitial() {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          color: _primary,
          fontSize: 76,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: "Close",
                  icon: const Icon(Icons.close_rounded),
                  color: _muted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.52,
              ),
              decoration: BoxDecoration(
                color: _primarySoft,
                borderRadius: BorderRadius.circular(24),
              ),
              clipBehavior: Clip.antiAlias,
              child: AspectRatio(
                aspectRatio: 1,
                child: avatarUrl.isNotEmpty
                    ? InteractiveViewer(
                        maxScale: 4,
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              largeInitial(),
                        ),
                      )
                    : largeInitial(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SECTION CARD + MENU TILE
// ============================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconTile(icon: icon, size: 40, iconSize: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MenuTile({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: _fieldFill,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _border),
                ),
                child: Icon(icon, size: 20, color: _primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _faint),
            ],
          ),
        ),
      ),
    );
  }
}

class _LatestPostBanner extends StatelessWidget {
  final String title;

  const _LatestPostBanner({required this.title});

  @override
  Widget build(BuildContext context) {
    final hasPost = title.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            hasPost ? Icons.forum_outlined : Icons.edit_note_rounded,
            size: 17,
            color: _primaryDeep,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasPost
                  ? "Latest: $title"
                  : "You have not posted in the community yet.",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _primaryDeep,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const _LogoutButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: _danger,
                    ),
                  )
                else
                  const Icon(Icons.logout_rounded, color: _danger, size: 20),
                const SizedBox(width: 8),
                Text(
                  isLoading ? "Logging out..." : "Log Out",
                  style: const TextStyle(
                    color: _danger,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
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

// ============================================================
// SMALL PIECES
// ============================================================

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color color;
  final Color background;

  const _IconTile({
    required this.icon,
    required this.size,
    required this.iconSize,
    this.color = _primary,
    this.background = _primarySoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}

class _SkeletonBlock extends StatelessWidget {
  final double height;
  final double radius;

  const _SkeletonBlock({required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECF4),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
